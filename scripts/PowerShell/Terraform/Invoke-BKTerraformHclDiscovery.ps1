[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Path = ".\terraform",

    [Parameter()]
    [switch]$SkipInit,

    [Parameter()]
    [switch]$IncludeSource,

    [Parameter()]
    [switch]$ExportJson,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath =
        ".\reports\terraform\terraform-hcl-discovery.json",

    [Parameter()]
    [switch]$PassThru
)

$ErrorActionPreference = "Stop"

function Invoke-BKTerraformProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Executable,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$ArgumentList,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$WorkingDirectory
    )

    $startInfo =
        [System.Diagnostics.ProcessStartInfo]::new()

    $startInfo.FileName = $Executable
    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true

    foreach ($argument in $ArgumentList) {
        $null = $startInfo.ArgumentList.Add(
            [string]$argument
        )
    }

    $process =
        [System.Diagnostics.Process]::new()

    $process.StartInfo = $startInfo

    try {
        if (-not $process.Start()) {
            throw "Terraform process could not be started."
        }

        $standardOutput =
            $process.StandardOutput.ReadToEnd()

        $standardError =
            $process.StandardError.ReadToEnd()

        $process.WaitForExit()

        return [PSCustomObject]@{
            Executable       = $Executable
            Arguments        = @($ArgumentList)
            WorkingDirectory = $WorkingDirectory
            ExitCode         = $process.ExitCode
            StandardOutput   = $standardOutput.Trim()
            StandardError    = $standardError.Trim()
            Succeeded        = $process.ExitCode -eq 0
        }
    }
    finally {
        $process.Dispose()
    }
}

function Get-BKBalancedBlock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Lines,

        [Parameter(Mandatory)]
        [ValidateRange(0, [int]::MaxValue)]
        [int]$StartIndex
    )

    if (
        $null -eq $Lines -or
        $Lines.Count -eq 0
    ) {
        return [PSCustomObject]@{
            StartIndex = $StartIndex
            EndIndex   = $StartIndex
            StartLine  = $StartIndex + 1
            EndLine    = $StartIndex + 1
            Lines      = @()
            Source     = ""
            IsComplete = $false
        }
    }

    if ($StartIndex -ge $Lines.Count) {
        throw (
            "Start index $StartIndex exceeds the available line count " +
            "$($Lines.Count)."
        )
    }

    $depth = 0
    $started = $false
    $inString = $false
    $escaped = $false
    $inSingleLineComment = $false
    $inBlockComment = $false
    $endIndex = $StartIndex

    for (
        $lineIndex = $StartIndex;
        $lineIndex -lt $Lines.Count;
        $lineIndex++
    ) {
        $line = [string]$Lines[$lineIndex]
        $inSingleLineComment = $false

        for (
            $characterIndex = 0;
            $characterIndex -lt $line.Length;
            $characterIndex++
        ) {
            $character = $line[$characterIndex]

            $nextCharacter = if (
                $characterIndex + 1 -lt $line.Length
            ) {
                $line[$characterIndex + 1]
            }
            else {
                [char]0
            }

            if ($inSingleLineComment) {
                break
            }

            if ($inBlockComment) {
                if (
                    $character -eq "*" -and
                    $nextCharacter -eq "/"
                ) {
                    $inBlockComment = $false
                    $characterIndex++
                }

                continue
            }

            if (-not $inString) {
                if (
                    $character -eq "/" -and
                    $nextCharacter -eq "/"
                ) {
                    $inSingleLineComment = $true
                    break
                }

                if ($character -eq "#") {
                    $inSingleLineComment = $true
                    break
                }

                if (
                    $character -eq "/" -and
                    $nextCharacter -eq "*"
                ) {
                    $inBlockComment = $true
                    $characterIndex++
                    continue
                }
            }

            if ($escaped) {
                $escaped = $false
                continue
            }

            if (
                $character -eq "\" -and
                $inString
            ) {
                $escaped = $true
                continue
            }

            if ($character -eq '"') {
                $inString = -not $inString
                continue
            }

            if ($inString) {
                continue
            }

            if ($character -eq "{") {
                $depth++
                $started = $true
            }
            elseif ($character -eq "}") {
                $depth--
            }
        }

        $endIndex = $lineIndex

        if (
            $started -and
            $depth -le 0
        ) {
            break
        }
    }

    $sourceLines = if ($endIndex -ge $StartIndex) {
        @(
            $Lines[$StartIndex..$endIndex]
        )
    }
    else {
        @()
    }

    return [PSCustomObject]@{
        StartIndex = $StartIndex
        EndIndex   = $endIndex
        StartLine  = $StartIndex + 1
        EndLine    = $endIndex + 1
        Lines      = $sourceLines
        Source     = $sourceLines -join [Environment]::NewLine
        IsComplete = (
            $started -and
            $depth -eq 0
        )
    }
}

function Get-BKHclAttribute {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    $pattern = '(?m)^\s*' +
        [regex]::Escape($Name) +
        '\s*=\s*(.+?)\s*$'

    $match = [regex]::Match(
        $Source,
        $pattern
    )

    if (-not $match.Success) {
        return $null
    }

    return $match.Groups[1].Value.Trim()
}

function Get-BKHclNestedBlockSource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$BlockName
    )

    $lines = $Source -split '\r?\n'

    for (
        $index = 0;
        $index -lt $lines.Count;
        $index++
    ) {
        if (
            $lines[$index] -match (
                '^\s*' +
                [regex]::Escape($BlockName) +
                '\s*\{'
            )
        ) {
            return (
                Get-BKBalancedBlock `
                    -Lines $lines `
                    -StartIndex $index
            ).Source
        }
    }

    return $null
}

function ConvertFrom-BKHclStringLiteral {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    $trimmedValue = $Value.Trim()

    if (
        $trimmedValue.StartsWith('"') -and
        $trimmedValue.EndsWith('"')
    ) {
        return $trimmedValue.Substring(
            1,
            $trimmedValue.Length - 2
        )
    }

    return $trimmedValue
}

function Get-BKHclReferences {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Source
    )

    $references =
        [System.Collections.Generic.HashSet[string]]::new(
            [System.StringComparer]::OrdinalIgnoreCase
        )

    $patterns = @(
        '(?<![\w-])data\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'
        '(?<![\w-])module\.[A-Za-z0-9_-]+'
        '(?<![\w-])var\.[A-Za-z0-9_-]+'
        '(?<![\w-])local\.[A-Za-z0-9_-]+'
        '(?<![\w-])[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'
    )

    foreach ($pattern in $patterns) {
        foreach (
            $match in [regex]::Matches(
                $Source,
                $pattern
            )
        ) {
            $value = [string]$match.Value

            if (
                $value -match
                '^(true|false|null)\.'
            ) {
                continue
            }

            $null = $references.Add($value)
        }
    }

    return @(
        $references |
            Sort-Object
    )
}

function Get-BKHclExplicitDependencies {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Source
    )

    $dependsOnMatch = [regex]::Match(
        $Source,
        '(?ms)^\s*depends_on\s*=\s*\[(.*?)\]'
    )

    if (-not $dependsOnMatch.Success) {
        return @()
    }

    $dependencySource =
        $dependsOnMatch.Groups[1].Value

    return @(
        Get-BKHclReferences `
            -Source $dependencySource
    )
}

function Get-BKTerraformBlockRecords {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo]$File,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ProjectRoot,

        [Parameter()]
        [switch]$IncludeSource
    )

    $fileContent = Get-Content `
    -LiteralPath $File.FullName `
    -Raw `
    -ErrorAction Stop

$relativePath = [System.IO.Path]::GetRelativePath(
    $ProjectRoot,
    $File.FullName
)

if (
    [string]::IsNullOrWhiteSpace(
        $fileContent
    )
) {
    Write-Verbose (
        "Skipping empty Terraform file: $relativePath"
    )

    return @()
}

$lines = @(
    $fileContent -split "\r?\n"
)

    $records =
        [System.Collections.Generic.List[object]]::new()

    $blockPattern =
        '^\s*(terraform|provider|resource|data|module|variable|output|locals|import|moved)\b(.*?)\{'

    for (
        $index = 0;
        $index -lt $lines.Count;
        $index++
    ) {
        $line = $lines[$index]
        $match = [regex]::Match(
            $line,
            $blockPattern
        )

        if (-not $match.Success) {
            continue
        }

        $block = Get-BKBalancedBlock `
            -Lines $lines `
            -StartIndex $index

        $blockType =
            $match.Groups[1].Value.ToLowerInvariant()

        $headerRemainder =
            $match.Groups[2].Value.Trim()

        $labels = @(
            [regex]::Matches(
                $headerRemainder,
                '"([^"]+)"'
            ) |
                ForEach-Object {
                    $_.Groups[1].Value
                }
        )

        $name = $null
        $resourceType = $null
        $address = $null

        switch ($blockType) {
            "resource" {
                if ($labels.Count -ge 2) {
                    $resourceType = $labels[0]
                    $name = $labels[1]
                    $address = "$resourceType.$name"
                }
            }

            "data" {
                if ($labels.Count -ge 2) {
                    $resourceType = $labels[0]
                    $name = $labels[1]
                    $address = "data.$resourceType.$name"
                }
            }

            "provider" {
                if ($labels.Count -ge 1) {
                    $name = $labels[0]
                    $address = "provider.$name"
                }
            }

            "module" {
                if ($labels.Count -ge 1) {
                    $name = $labels[0]
                    $address = "module.$name"
                }
            }

            "variable" {
                if ($labels.Count -ge 1) {
                    $name = $labels[0]
                    $address = "var.$name"
                }
            }

            "output" {
                if ($labels.Count -ge 1) {
                    $name = $labels[0]
                    $address = "output.$name"
                }
            }

            "terraform" {
                $name = "terraform"
                $address = "terraform"
            }

            "locals" {
                $name = "locals"
                $address = "locals"
            }

            "import" {
                $name = "import"
                $address = "import"
            }

            "moved" {
                $name = "moved"
                $address = "moved"
            }
        }

        $references = @(
            Get-BKHclReferences `
                -Source $block.Source
        )

        $explicitDependencies = @(
            Get-BKHclExplicitDependencies `
                -Source $block.Source
        )

        $record = [PSCustomObject]@{
            BlockType            = $blockType
            ResourceType         = $resourceType
            Name                 = $name
            Address              = $address
            Labels               = $labels
            File                 = $relativePath
            FullPath             = $File.FullName
            StartLine            = $block.StartLine
            EndLine              = $block.EndLine
            References           = $references
            ExplicitDependencies = $explicitDependencies
            Source               = if ($IncludeSource.IsPresent) {
                $block.Source
            }
            else {
                $null
            }
            RawSource            = $block.Source
        }

        $null = $records.Add($record)

        $index = $block.EndIndex
    }

    return @($records)
}

function Get-BKTerraformVersionConstraints {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$TerraformBlocks
    )

    $constraints =
        [System.Collections.Generic.List[object]]::new()

    foreach ($block in $TerraformBlocks) {
        $requiredVersion =
            Get-BKHclAttribute `
                -Source $block.RawSource `
                -Name "required_version"

        if (
            -not [string]::IsNullOrWhiteSpace(
                $requiredVersion
            )
        ) {
            $null = $constraints.Add(
                [PSCustomObject]@{
                    Type       = "Terraform"
                    Name       = "terraform"
                    Source     = $null
                    Version    = ConvertFrom-BKHclStringLiteral `
                        -Value $requiredVersion
                    File       = $block.File
                    StartLine  = $block.StartLine
                }
            )
        }

        $requiredProvidersSource =
            Get-BKHclNestedBlockSource `
                -Source $block.RawSource `
                -BlockName "required_providers"

        if (
            [string]::IsNullOrWhiteSpace(
                $requiredProvidersSource
            )
        ) {
            continue
        }

        $providerPattern =
            '(?ms)^\s*([A-Za-z0-9_-]+)\s*=\s*\{(.*?)^\s*\}'

        foreach (
            $providerMatch in [regex]::Matches(
                $requiredProvidersSource,
                $providerPattern
            )
        ) {
            $providerName =
                $providerMatch.Groups[1].Value

            $providerBody =
                $providerMatch.Groups[2].Value

            $source =
                ConvertFrom-BKHclStringLiteral `
                    -Value (
                        Get-BKHclAttribute `
                            -Source $providerBody `
                            -Name "source"
                    )

            $version =
                ConvertFrom-BKHclStringLiteral `
                    -Value (
                        Get-BKHclAttribute `
                            -Source $providerBody `
                            -Name "version"
                    )

            $null = $constraints.Add(
                [PSCustomObject]@{
                    Type      = "Provider"
                    Name      = $providerName
                    Source    = $source
                    Version   = $version
                    File      = $block.File
                    StartLine = $block.StartLine
                }
            )
        }
    }

    return @($constraints)
}

function Get-BKTerraformBackendRecords {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$TerraformBlocks
    )

    $backends =
        [System.Collections.Generic.List[object]]::new()

    foreach ($block in $TerraformBlocks) {
        $backendMatch = [regex]::Match(
            $block.RawSource,
            '(?ms)\bbackend\s+"([^"]+)"\s*\{(.*?)\}'
        )

        if (-not $backendMatch.Success) {
            continue
        }

        $backendType =
            $backendMatch.Groups[1].Value

        $backendSource =
            $backendMatch.Groups[2].Value

        $attributes =
            [System.Collections.Generic.List[object]]::new()

        foreach (
            $attributeMatch in [regex]::Matches(
                $backendSource,
                '(?m)^\s*([A-Za-z0-9_-]+)\s*=\s*(.+?)\s*$'
            )
        ) {
            $attributeName =
                $attributeMatch.Groups[1].Value

            $attributeValue =
                $attributeMatch.Groups[2].Value.Trim()

            $isSensitiveName =
                $attributeName -match
                '(?i)(secret|password|token|key|credential)'

            $null = $attributes.Add(
                [PSCustomObject]@{
                    Name        = $attributeName
                    Value       = if ($isSensitiveName) {
                        "[REDACTED]"
                    }
                    else {
                        $attributeValue
                    }
                    IsSensitive = $isSensitiveName
                }
            )
        }

        $null = $backends.Add(
            [PSCustomObject]@{
                Type       = $backendType
                File       = $block.File
                StartLine  = $block.StartLine
                Attributes = @($attributes)
            }
        )
    }

    return @($backends)
}

function Get-BKTerraformLocalRecords {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$LocalBlocks
    )

    $locals =
        [System.Collections.Generic.List[object]]::new()

    foreach ($block in $LocalBlocks) {
        foreach (
            $match in [regex]::Matches(
                $block.RawSource,
                '(?m)^\s*([A-Za-z_][A-Za-z0-9_-]*)\s*=\s*(.+?)\s*$'
            )
        ) {
            $name = $match.Groups[1].Value

            if ($name -eq "locals") {
                continue
            }

            $expression =
                $match.Groups[2].Value.Trim()

            $null = $locals.Add(
                [PSCustomObject]@{
                    Name       = $name
                    Address    = "local.$name"
                    Expression = $expression
                    References = @(
                        Get-BKHclReferences `
                            -Source $expression
                    )
                    File       = $block.File
                    StartLine  = $block.StartLine
                }
            )
        }
    }

    return @($locals)
}

function Get-BKTerraformDependencyRecords {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Blocks
    )

    $dependencies =
        [System.Collections.Generic.List[object]]::new()

    $knownAddresses =
        [System.Collections.Generic.HashSet[string]]::new(
            [System.StringComparer]::OrdinalIgnoreCase
        )

    foreach ($block in $Blocks) {
        if (
            -not [string]::IsNullOrWhiteSpace(
                [string]$block.Address
            )
        ) {
            $null = $knownAddresses.Add(
                [string]$block.Address
            )
        }
    }

    foreach ($block in $Blocks) {
        if (
            [string]::IsNullOrWhiteSpace(
                [string]$block.Address
            )
        ) {
            continue
        }

        foreach ($reference in @($block.References)) {
            if (
                $reference -eq $block.Address
            ) {
                continue
            }

            $targetAddress = $reference

            if (
                $reference -match
                '^([A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)'
            ) {
                $candidate =
                    $matches[1]

                if ($knownAddresses.Contains($candidate)) {
                    $targetAddress = $candidate
                }
            }

            if (
                $reference -match
                '^(data\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)'
            ) {
                $targetAddress = $matches[1]
            }
            elseif (
                $reference -match
                '^(module\.[A-Za-z0-9_-]+)'
            ) {
                $targetAddress = $matches[1]
            }
            elseif (
                $reference -match
                '^(var\.[A-Za-z0-9_-]+)'
            ) {
                $targetAddress = $matches[1]
            }
            elseif (
                $reference -match
                '^(local\.[A-Za-z0-9_-]+)'
            ) {
                $targetAddress = $matches[1]
            }

            $dependencyType = if (
                $block.ExplicitDependencies -contains
                $reference
            ) {
                "Explicit"
            }
            else {
                "Expression"
            }

            $null = $dependencies.Add(
                [PSCustomObject]@{
                    SourceAddress = $block.Address
                    TargetAddress = $targetAddress
                    Reference     = $reference
                    DependencyType = $dependencyType
                    File          = $block.File
                    StartLine     = $block.StartLine
                }
            )
        }
    }

    return @(
        $dependencies |
            Sort-Object `
                SourceAddress,
                TargetAddress,
                DependencyType `
            -Unique
    )
}

function Get-BKTerraformGraphRecords {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DotSource
    )

    $nodes =
        [System.Collections.Generic.HashSet[string]]::new(
            [System.StringComparer]::OrdinalIgnoreCase
        )

    $edges =
        [System.Collections.Generic.List[object]]::new()

    foreach (
        $match in [regex]::Matches(
            $DotSource,
            '"([^"]+)"\s*->\s*"([^"]+)"'
        )
    ) {
        $source = $match.Groups[1].Value
        $target = $match.Groups[2].Value

        $null = $nodes.Add($source)
        $null = $nodes.Add($target)

        $null = $edges.Add(
            [PSCustomObject]@{
                Source = $source
                Target = $target
            }
        )
    }

    foreach (
        $match in [regex]::Matches(
            $DotSource,
            '^\s*"([^"]+)"\s*(?:\[|;)',
            [System.Text.RegularExpressions.RegexOptions]::Multiline
        )
    ) {
        $null = $nodes.Add(
            $match.Groups[1].Value
        )
    }

    return [PSCustomObject]@{
        Nodes = @(
            $nodes |
                Sort-Object
        )
        Edges = @(
            $edges |
                Sort-Object Source, Target -Unique
        )
    }
}

function Get-BKTerraformArchitectureHealth {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [double]$Score,

        [Parameter(Mandatory)]
        [int]$CriticalFindings,

        [Parameter(Mandatory)]
        [int]$HighFindings
    )

    if ($CriticalFindings -gt 0) {
        return "Needs Attention"
    }

    if ($HighFindings -gt 0) {
        return "Warning"
    }

    if ($Score -ge 95) {
        return "Excellent"
    }

    if ($Score -ge 85) {
        return "Healthy"
    }

    if ($Score -ge 70) {
        return "Warning"
    }

    return "Needs Attention"
}

Write-Host ""
Write-Host "============================================================" `
    -ForegroundColor Cyan
Write-Host "       BLACKKNIGHT TERRAFORM HCL DISCOVERY ENGINE V2" `
    -ForegroundColor Cyan
Write-Host "============================================================" `
    -ForegroundColor Cyan

try {
    if (
        -not (
            Test-Path `
                -LiteralPath $Path `
                -PathType Container
        )
    ) {
        throw "Terraform project directory was not found: $Path"
    }

    $resolvedPath = (
        Resolve-Path `
            -LiteralPath $Path `
            -ErrorAction Stop
    ).Path

    $terraformCommand =
        Get-Command `
            -Name "terraform" `
            -ErrorAction SilentlyContinue

    $terraformFiles = @(
        Get-ChildItem `
            -LiteralPath $resolvedPath `
            -Filter "*.tf" `
            -File `
            -Recurse `
            -ErrorAction Stop |
            Where-Object {
                $_.FullName -notmatch
                '[\\/]\.terraform[\\/]'
            }
    )

    if ($terraformFiles.Count -eq 0) {
        throw "No Terraform configuration files were found in: $resolvedPath"
    }

    Write-Host ""
    Write-Host "Parsing Terraform configuration files..." `
        -ForegroundColor Yellow

    $allBlocks =
        [System.Collections.Generic.List[object]]::new()

    foreach ($file in $terraformFiles) {
        $fileBlocks =
            Get-BKTerraformBlockRecords `
                -File $file `
                -ProjectRoot $resolvedPath `
                -IncludeSource:$IncludeSource

        foreach ($block in $fileBlocks) {
            $null = $allBlocks.Add($block)
        }
    }

    $terraformBlocks = @(
        $allBlocks |
            Where-Object BlockType -eq "terraform"
    )

    $providerBlocks = @(
        $allBlocks |
            Where-Object BlockType -eq "provider"
    )

    $resourceBlocks = @(
        $allBlocks |
            Where-Object BlockType -eq "resource"
    )

    $dataBlocks = @(
        $allBlocks |
            Where-Object BlockType -eq "data"
    )

    $moduleBlocks = @(
        $allBlocks |
            Where-Object BlockType -eq "module"
    )

    $variableBlocks = @(
        $allBlocks |
            Where-Object BlockType -eq "variable"
    )

    $outputBlocks = @(
        $allBlocks |
            Where-Object BlockType -eq "output"
    )

    $localBlocks = @(
        $allBlocks |
            Where-Object BlockType -eq "locals"
    )

    $importBlocks = @(
        $allBlocks |
            Where-Object BlockType -eq "import"
    )

    $movedBlocks = @(
        $allBlocks |
            Where-Object BlockType -eq "moved"
    )

    $versionConstraints =
        Get-BKTerraformVersionConstraints `
            -TerraformBlocks $terraformBlocks

    $backends =
        Get-BKTerraformBackendRecords `
            -TerraformBlocks $terraformBlocks

    $locals =
        Get-BKTerraformLocalRecords `
            -LocalBlocks $localBlocks

    $providers = @(
        foreach ($block in $providerBlocks) {
            [PSCustomObject]@{
                Name       = $block.Name
                Alias      = ConvertFrom-BKHclStringLiteral `
                    -Value (
                        Get-BKHclAttribute `
                            -Source $block.RawSource `
                            -Name "alias"
                    )
                File       = $block.File
                StartLine  = $block.StartLine
                References = $block.References
                Source     = $block.Source
            }
        }
    )

    $resources = @(
        foreach ($block in $resourceBlocks) {
            [PSCustomObject]@{
                Address              = $block.Address
                Type                 = $block.ResourceType
                Name                 = $block.Name
                Provider             = Get-BKHclAttribute `
                    -Source $block.RawSource `
                    -Name "provider"
                CountExpression      = Get-BKHclAttribute `
                    -Source $block.RawSource `
                    -Name "count"
                ForEachExpression    = Get-BKHclAttribute `
                    -Source $block.RawSource `
                    -Name "for_each"
                PreventDestroy       = (
                    $block.RawSource -match
                    '(?ms)lifecycle\s*\{.*?prevent_destroy\s*=\s*true'
                )
                CreateBeforeDestroy  = (
                    $block.RawSource -match
                    '(?ms)lifecycle\s*\{.*?create_before_destroy\s*=\s*true'
                )
                IgnoreChanges        = (
                    $block.RawSource -match
                    '(?ms)lifecycle\s*\{.*?ignore_changes\s*='
                )
                References           = $block.References
                ExplicitDependencies = $block.ExplicitDependencies
                File                 = $block.File
                StartLine            = $block.StartLine
                EndLine              = $block.EndLine
                Source               = $block.Source
            }
        }
    )

    $dataSources = @(
        foreach ($block in $dataBlocks) {
            [PSCustomObject]@{
                Address              = $block.Address
                Type                 = $block.ResourceType
                Name                 = $block.Name
                Provider             = Get-BKHclAttribute `
                    -Source $block.RawSource `
                    -Name "provider"
                CountExpression      = Get-BKHclAttribute `
                    -Source $block.RawSource `
                    -Name "count"
                ForEachExpression    = Get-BKHclAttribute `
                    -Source $block.RawSource `
                    -Name "for_each"
                References           = $block.References
                ExplicitDependencies = $block.ExplicitDependencies
                File                 = $block.File
                StartLine            = $block.StartLine
                EndLine              = $block.EndLine
                Source               = $block.Source
            }
        }
    )

    $modules = @(
        foreach ($block in $moduleBlocks) {
            [PSCustomObject]@{
                Address              = $block.Address
                Name                 = $block.Name
                SourcePath           = ConvertFrom-BKHclStringLiteral `
                    -Value (
                        Get-BKHclAttribute `
                            -Source $block.RawSource `
                            -Name "source"
                    )
                Version              = ConvertFrom-BKHclStringLiteral `
                    -Value (
                        Get-BKHclAttribute `
                            -Source $block.RawSource `
                            -Name "version"
                    )
                CountExpression      = Get-BKHclAttribute `
                    -Source $block.RawSource `
                    -Name "count"
                ForEachExpression    = Get-BKHclAttribute `
                    -Source $block.RawSource `
                    -Name "for_each"
                References           = $block.References
                ExplicitDependencies = $block.ExplicitDependencies
                File                 = $block.File
                StartLine            = $block.StartLine
                EndLine              = $block.EndLine
                Source               = $block.Source
            }
        }
    )

    $variables = @(
        foreach ($block in $variableBlocks) {
            $defaultValue =
                Get-BKHclAttribute `
                    -Source $block.RawSource `
                    -Name "default"

            $sensitiveValue =
                Get-BKHclAttribute `
                    -Source $block.RawSource `
                    -Name "sensitive"

            $nullableValue =
                Get-BKHclAttribute `
                    -Source $block.RawSource `
                    -Name "nullable"

            [PSCustomObject]@{
                Address       = $block.Address
                Name          = $block.Name
                Type          = Get-BKHclAttribute `
                    -Source $block.RawSource `
                    -Name "type"
                Description   = ConvertFrom-BKHclStringLiteral `
                    -Value (
                        Get-BKHclAttribute `
                            -Source $block.RawSource `
                            -Name "description"
                    )
                HasDefault    = -not [string]::IsNullOrWhiteSpace(
                    $defaultValue
                )
                Default       = if (
                    $IncludeSource.IsPresent
                ) {
                    $defaultValue
                }
                else {
                    $null
                }
                Sensitive     = $sensitiveValue -match '^true$'
                Nullable      = if (
                    [string]::IsNullOrWhiteSpace(
                        $nullableValue
                    )
                ) {
                    $true
                }
                else {
                    $nullableValue -match '^true$'
                }
                HasValidation = (
                    $block.RawSource -match
                    '(?m)^\s*validation\s*\{'
                )
                File          = $block.File
                StartLine     = $block.StartLine
                Source        = $block.Source
            }
        }
    )

    $outputs = @(
        foreach ($block in $outputBlocks) {
            $sensitiveValue =
                Get-BKHclAttribute `
                    -Source $block.RawSource `
                    -Name "sensitive"

            [PSCustomObject]@{
                Address     = $block.Address
                Name        = $block.Name
                Description = ConvertFrom-BKHclStringLiteral `
                    -Value (
                        Get-BKHclAttribute `
                            -Source $block.RawSource `
                            -Name "description"
                    )
                Value       = Get-BKHclAttribute `
                    -Source $block.RawSource `
                    -Name "value"
                Sensitive   = $sensitiveValue -match '^true$'
                References  = $block.References
                File        = $block.File
                StartLine   = $block.StartLine
                Source      = $block.Source
            }
        }
    )

    $imports = @(
        foreach ($block in $importBlocks) {
            [PSCustomObject]@{
                To         = Get-BKHclAttribute `
                    -Source $block.RawSource `
                    -Name "to"
                Id         = Get-BKHclAttribute `
                    -Source $block.RawSource `
                    -Name "id"
                ForEach    = Get-BKHclAttribute `
                    -Source $block.RawSource `
                    -Name "for_each"
                References = $block.References
                File       = $block.File
                StartLine  = $block.StartLine
                Source     = $block.Source
            }
        }
    )

    $moved = @(
        foreach ($block in $movedBlocks) {
            [PSCustomObject]@{
                From      = Get-BKHclAttribute `
                    -Source $block.RawSource `
                    -Name "from"
                To        = Get-BKHclAttribute `
                    -Source $block.RawSource `
                    -Name "to"
                File      = $block.File
                StartLine = $block.StartLine
                Source    = $block.Source
            }
        }
    )

    $dependencyBlocks = @(
        $resourceBlocks
        $dataBlocks
        $moduleBlocks
        $outputBlocks
    )

    $dependencies =
        Get-BKTerraformDependencyRecords `
            -Blocks $dependencyBlocks

    $terraformVersion = $null
    $terraformGraph = $null
    $graphAvailable = $false
    $initializationSucceeded = $false

    if ($terraformCommand) {
        $versionResult =
            Invoke-BKTerraformProcess `
                -Executable $terraformCommand.Source `
                -ArgumentList @(
                    "version"
                    "-json"
                ) `
                -WorkingDirectory $resolvedPath

        if (
            $versionResult.Succeeded -and
            -not [string]::IsNullOrWhiteSpace(
                $versionResult.StandardOutput
            )
        ) {
            try {
                $versionObject =
                    $versionResult.StandardOutput |
                    ConvertFrom-Json `
                        -ErrorAction Stop

                $terraformVersion =
                    [string]$versionObject.terraform_version
            }
            catch {
                $terraformVersion = $null
            }
        }

        if (-not $SkipInit.IsPresent) {
            Write-Host "Initializing Terraform for dependency graph..." `
                -ForegroundColor Yellow

            $initResult =
                Invoke-BKTerraformProcess `
                    -Executable $terraformCommand.Source `
                    -ArgumentList @(
                        "init"
                        "-backend=false"
                        "-input=false"
                        "-no-color"
                    ) `
                    -WorkingDirectory $resolvedPath

            $initializationSucceeded =
                $initResult.Succeeded
        }
        else {
            $initializationSucceeded = $true
        }

        if ($initializationSucceeded) {
            Write-Host "Generating Terraform dependency graph..." `
                -ForegroundColor Yellow

            $graphResult =
                Invoke-BKTerraformProcess `
                    -Executable $terraformCommand.Source `
                    -ArgumentList @(
                        "graph"
                    ) `
                    -WorkingDirectory $resolvedPath

            if (
                $graphResult.Succeeded -and
                -not [string]::IsNullOrWhiteSpace(
                    $graphResult.StandardOutput
                )
            ) {
                $terraformGraph =
                    Get-BKTerraformGraphRecords `
                        -DotSource $graphResult.StandardOutput

                $graphAvailable = $true
            }
        }
    }

    $findings =
        [System.Collections.Generic.List[object]]::new()

    if ($backends.Count -eq 0) {
        $null = $findings.Add(
            [PSCustomObject]@{
                Severity       = "Medium"
                Category       = "Backend"
                Title          = "No explicit Terraform backend detected"
                Details        = "Terraform will use local state unless a backend is supplied externally."
                Recommendation = "Use a secured remote backend for shared or production workloads."
            }
        )
    }

    if (
        @(
            $versionConstraints |
            Where-Object Type -eq "Terraform"
        ).Count -eq 0
    ) {
        $null = $findings.Add(
            [PSCustomObject]@{
                Severity       = "Medium"
                Category       = "Versioning"
                Title          = "Terraform version constraint not detected"
                Details        = "The configuration does not declare required_version."
                Recommendation = "Declare a tested Terraform version range."
            }
        )
    }

    foreach (
        $providerConstraint in @(
            $versionConstraints |
                Where-Object Type -eq "Provider"
        )
    ) {
        if (
            [string]::IsNullOrWhiteSpace(
                $providerConstraint.Version
            )
        ) {
            $null = $findings.Add(
                [PSCustomObject]@{
                    Severity       = "Medium"
                    Category       = "Versioning"
                    Title          = "Provider version constraint not detected"
                    Details        = "Provider $($providerConstraint.Name) does not declare a version constraint."
                    Recommendation = "Pin providers to an approved version range."
                }
            )
        }
    }

    foreach (
        $variable in @(
            $variables |
                Where-Object {
                    $_.Sensitive -and
                    $_.HasDefault
                }
        )
    ) {
        $null = $findings.Add(
            [PSCustomObject]@{
                Severity       = "High"
                Category       = "Secrets"
                Title          = "Sensitive variable declares a default"
                Details        = "Sensitive variable $($variable.Name) has a default value."
                Recommendation = "Supply sensitive values through an approved secret-management mechanism."
            }
        )
    }

    foreach (
        $output in @(
            $outputs |
                Where-Object {
                    -not $_.Sensitive -and
                    $_.Value -match
                    '(?i)(secret|password|token|credential|private_key)'
                }
        )
    ) {
        $null = $findings.Add(
            [PSCustomObject]@{
                Severity       = "High"
                Category       = "Secrets"
                Title          = "Potentially sensitive output is not marked sensitive"
                Details        = "Output $($output.Name) appears to reference sensitive material."
                Recommendation = "Mark the output sensitive or remove the output."
            }
        )
    }

    $criticalFindings = @(
        $findings |
            Where-Object Severity -eq "Critical"
    ).Count

    $highFindings = @(
        $findings |
            Where-Object Severity -eq "High"
    ).Count

    $mediumFindings = @(
        $findings |
            Where-Object Severity -eq "Medium"
    ).Count

    $lowFindings = @(
        $findings |
            Where-Object Severity -eq "Low"
    ).Count

    $architectureScore = 100

    $architectureScore -=
        ($criticalFindings * 25)

    $architectureScore -=
        ($highFindings * 12)

    $architectureScore -=
        ($mediumFindings * 4)

    $architectureScore -=
        ($lowFindings * 1)

    if ($architectureScore -lt 0) {
        $architectureScore = 0
    }

    $architectureHealth =
        Get-BKTerraformArchitectureHealth `
            -Score $architectureScore `
            -CriticalFindings $criticalFindings `
            -HighFindings $highFindings

    $result = [PSCustomObject]@{
        Platform    = "Blackknight One"
        Engine      = "Terraform"
        Operation   = "HclDiscoveryV2"
        GeneratedAt = (
            Get-Date
        ).ToUniversalTime().ToString("o")

        Project = [PSCustomObject]@{
            Path                    = $resolvedPath
            TerraformInstalled      = $null -ne $terraformCommand
            TerraformVersion        = $terraformVersion
            InitializationSucceeded = $initializationSucceeded
            GraphAvailable          = $graphAvailable
        }

        Summary = [PSCustomObject]@{
            Health               = $architectureHealth
            ArchitectureScore    = $architectureScore
            TerraformFiles       = $terraformFiles.Count
            TerraformBlocks      = $terraformBlocks.Count
            Providers            = $providers.Count
            RequiredProviders    = @(
                $versionConstraints |
                    Where-Object Type -eq "Provider"
            ).Count
            Resources            = $resources.Count
            DataSources          = $dataSources.Count
            Modules              = $modules.Count
            Variables            = $variables.Count
            Outputs              = $outputs.Count
            Locals               = $locals.Count
            Backends             = $backends.Count
            Imports              = $imports.Count
            MovedBlocks          = $moved.Count
            Dependencies         = $dependencies.Count
            ExplicitDependencies = @(
                $dependencies |
                    Where-Object DependencyType -eq "Explicit"
            ).Count
            GraphNodes           = if ($terraformGraph) {
                $terraformGraph.Nodes.Count
            }
            else {
                0
            }
            GraphEdges           = if ($terraformGraph) {
                $terraformGraph.Edges.Count
            }
            else {
                0
            }
            CriticalFindings     = $criticalFindings
            HighFindings         = $highFindings
            MediumFindings       = $mediumFindings
            LowFindings          = $lowFindings
        }

        Files = @(
            foreach ($file in $terraformFiles) {
                [PSCustomObject]@{
                    Path         = [System.IO.Path]::GetRelativePath(
                        $resolvedPath,
                        $file.FullName
                    )
                    FullPath     = $file.FullName
                    Length       = $file.Length
                    LastModified = $file.LastWriteTimeUtc.ToString("o")
                }
            }
        )

        VersionConstraints = @($versionConstraints)
        Providers          = @($providers)
        Resources          = @($resources)
        DataSources        = @($dataSources)
        Modules            = @($modules)
        Variables          = @($variables)
        Outputs            = @($outputs)
        Locals             = @($locals)
        Backends           = @($backends)
        Imports            = @($imports)
        MovedBlocks        = @($moved)
        Dependencies       = @($dependencies)
        TerraformGraph     = $terraformGraph
        Findings           = @($findings)
    }

    Write-Host ""
    Write-Host "HCL Discovery Summary" `
        -ForegroundColor Yellow
    Write-Host "------------------------------------------------------------"
    Write-Host "Terraform Files       : $($result.Summary.TerraformFiles)"
    Write-Host "Providers             : $($result.Summary.Providers)"
    Write-Host "Required Providers    : $($result.Summary.RequiredProviders)"
    Write-Host "Resources             : $($result.Summary.Resources)"
    Write-Host "Data Sources          : $($result.Summary.DataSources)"
    Write-Host "Modules               : $($result.Summary.Modules)"
    Write-Host "Variables             : $($result.Summary.Variables)"
    Write-Host "Outputs               : $($result.Summary.Outputs)"
    Write-Host "Locals                : $($result.Summary.Locals)"
    Write-Host "Backends              : $($result.Summary.Backends)"
    Write-Host "Imports               : $($result.Summary.Imports)"
    Write-Host "Moved Blocks          : $($result.Summary.MovedBlocks)"
    Write-Host "Dependencies          : $($result.Summary.Dependencies)"
    Write-Host "Terraform Graph Nodes : $($result.Summary.GraphNodes)"
    Write-Host "Terraform Graph Edges : $($result.Summary.GraphEdges)"
    Write-Host "Architecture Score    : $architectureScore%"
    Write-Host "Architecture Health   : $architectureHealth"

    if ($findings.Count -gt 0) {
        Write-Host ""
        Write-Host "HCL Findings" `
            -ForegroundColor Yellow
        Write-Host "------------------------------------------------------------"

        $findings |
            Select-Object `
                Severity,
                Category,
                Title,
                Details |
            Format-Table `
                -Wrap `
                -AutoSize |
            Out-Host
    }

    if ($ExportJson.IsPresent) {
        $outputDirectory = Split-Path `
            -Path $OutputPath `
            -Parent

        if (
            -not [string]::IsNullOrWhiteSpace(
                $outputDirectory
            ) -and
            -not (
                Test-Path `
                    -LiteralPath $outputDirectory
            )
        ) {
            New-Item `
                -Path $outputDirectory `
                -ItemType Directory `
                -Force |
                Out-Null
        }

        $result |
            ConvertTo-Json `
                -Depth 50 |
            Set-Content `
                -LiteralPath $OutputPath `
                -Encoding utf8

        Write-Host ""
        Write-Host (
            "[Success] Exported HCL discovery to $OutputPath"
        ) -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "============================================================" `
        -ForegroundColor Cyan

    if ($PassThru.IsPresent) {
        return $result
    }
}
catch {
    if (
        Get-Command `
            -Name "Write-BKLog" `
            -ErrorAction SilentlyContinue
    ) {
        Write-BKLog `
            -Message $_.Exception.Message `
            -Level Error
    }
    else {
        Write-Error $_.Exception.Message
    }

    throw
}