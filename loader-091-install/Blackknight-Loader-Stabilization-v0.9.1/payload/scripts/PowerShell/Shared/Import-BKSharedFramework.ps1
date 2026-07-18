[CmdletBinding()]
param(
    [Parameter()]
    [switch]$PassThru
)

$ErrorActionPreference = "Stop"

$sharedRoot = $PSScriptRoot
$manifestPath = Join-Path -Path $sharedRoot -ChildPath "shared.json"

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Blackknight Shared Framework manifest was not found: $manifestPath"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw -ErrorAction Stop |
    ConvertFrom-Json -ErrorAction Stop

$loadedFiles = [System.Collections.Generic.List[string]]::new()
$loadedFunctions = [System.Collections.Generic.List[string]]::new()
$componentStatus = [System.Collections.Generic.List[object]]::new()

$declaredCategories = @($manifest.LoadOrder | ForEach-Object { [string]$_ })
$discoveredCategories = @(
    Get-ChildItem -LiteralPath $sharedRoot -Directory -ErrorAction Stop |
        Select-Object -ExpandProperty Name
)

$categoryNames = @(
    $declaredCategories
    $discoveredCategories | Where-Object { $_ -notin $declaredCategories } | Sort-Object
)

foreach ($category in $categoryNames) {
    $categoryPath = Join-Path -Path $sharedRoot -ChildPath $category

    if (-not (Test-Path -LiteralPath $categoryPath -PathType Container)) {
        if ($category -in $declaredCategories) {
            throw "Required Shared Framework category was not found: $categoryPath"
        }

        continue
    }

    $helperFiles = @(
        Get-ChildItem -LiteralPath $categoryPath -Filter "*.ps1" -File -ErrorAction Stop |
            Sort-Object Name, FullName
    )

    $categoryFunctions = [System.Collections.Generic.List[string]]::new()

    foreach ($helperFile in $helperFiles) {
        $tokens = $null
        $parseErrors = $null

        [void][System.Management.Automation.Language.Parser]::ParseFile(
            $helperFile.FullName,
            [ref]$tokens,
            [ref]$parseErrors
        )

        if ($parseErrors.Count -gt 0) {
            $messages = @($parseErrors | ForEach-Object { $_.Message }) -join "; "
            throw "Shared Framework helper failed syntax validation: $($helperFile.FullName). $messages"
        }

        Write-Verbose "Loading shared helper: $($helperFile.FullName)"
        . $helperFile.FullName

        $loadedFiles.Add($helperFile.FullName)
        $loadedFunctions.Add($helperFile.BaseName)
        $categoryFunctions.Add($helperFile.BaseName)
    }

    $componentStatus.Add(
        [PSCustomObject]@{
            Component = $category
            Path      = $categoryPath
            Files     = $helperFiles.Count
            Functions = @($categoryFunctions)
            Loaded    = $true
            Status    = "Healthy"
        }
    )
}

$missingFunctions = @(
    @($manifest.RequiredHelpers) |
        Where-Object {
            $null -eq (Get-Command -Name ([string]$_) -CommandType Function -ErrorAction SilentlyContinue)
        }
)

if ($missingFunctions.Count -gt 0) {
    throw "Shared Framework failed to load required helpers: $($missingFunctions -join ', ')"
}

$script:BKSharedFramework = [PSCustomObject]@{
    Name            = [string]$manifest.Name
    Version         = [string]$manifest.Version
    SchemaVersion   = [string]$manifest.SchemaVersion
    Root            = $sharedRoot
    ManifestPath    = $manifestPath
    LoadedAt        = [DateTimeOffset]::UtcNow
    LoadedFiles     = @($loadedFiles)
    LoadedFunctions = @($loadedFunctions | Sort-Object -Unique)
    Components      = @($componentStatus)
    Status          = "Healthy"
}

if ($PassThru.IsPresent) {
    return $script:BKSharedFramework
}
