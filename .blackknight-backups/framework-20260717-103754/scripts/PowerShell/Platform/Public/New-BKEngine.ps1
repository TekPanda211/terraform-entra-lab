function New-BKEngine {
    <#
    .SYNOPSIS
    Scaffolds a new Blackknight One assessment engine.

    .DESCRIPTION
    Creates a manifest-driven engine folder, assessment/discovery/analyzer
    entry points, private and test folders, documentation, and an optional
    public platform wrapper.

    The command never overwrites an existing engine unless Force is supplied.

    .EXAMPLE
    New-BKEngine `
        -Name Exchange `
        -Category Messaging `
        -Description "Assesses Exchange Online configuration and security." `
        -SupportsGraph `
        -RequiredScopes "Exchange.ManageAsApp"
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z][A-Za-z0-9]+$')]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Category,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Description,

        [Parameter()]
        [ValidatePattern('^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$')]
        [string]$Version = "0.1.0",

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]$Operations = @(
            "Assessment"
            "Discovery"
            "Analysis"
        ),

        [Parameter()]
        [string[]]$RequiredScopes = @(),

        [Parameter()]
        [string[]]$Dependencies = @(),

        [Parameter()]
        [switch]$SupportsGraph,

        [Parameter()]
        [switch]$NoPublicWrapper,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$PassThru
    )

    $platformRoot = $PSScriptRoot
    $powerShellRoot = [System.IO.Path]::GetFullPath(
        (
            Join-Path `
                -Path $platformRoot `
                -ChildPath "..\.."
        )
    )

    $engineRoot = Join-Path `
        -Path $powerShellRoot `
        -ChildPath $Name

    $publicRoot = Join-Path `
        -Path $powerShellRoot `
        -ChildPath "Platform\Public"

    $assessmentCommand = "Invoke-BK${Name}Assessment"
    $discoveryCommand = "Invoke-BK${Name}Discovery"
    $analyzerCommand = "Invoke-BK${Name}Analyzer"

    $assessmentFile = "$assessmentCommand.ps1"
    $discoveryFile = "$discoveryCommand.ps1"
    $analyzerFile = "$analyzerCommand.ps1"
    $wrapperPath = Join-Path `
        -Path $publicRoot `
        -ChildPath $assessmentFile

    if (
        Test-Path `
            -LiteralPath $engineRoot
    ) {
        if (-not $Force.IsPresent) {
            throw (
                "Engine folder already exists: $engineRoot. " +
                "Use -Force to replace generated scaffold files."
            )
        }
    }

    if (
        -not $NoPublicWrapper.IsPresent -and
        (Test-Path -LiteralPath $wrapperPath) -and
        -not $Force.IsPresent
    ) {
        throw (
            "Public wrapper already exists: $wrapperPath. " +
            "Use -Force to replace it."
        )
    }

    if (
        -not $PSCmdlet.ShouldProcess(
            $engineRoot,
            "Create Blackknight One engine scaffold"
        )
    ) {
        return
    }

    foreach ($directory in @(
        $engineRoot
        (Join-Path -Path $engineRoot -ChildPath "Private")
        (Join-Path -Path $engineRoot -ChildPath "Tests")
    )) {
        New-Item `
            -Path $directory `
            -ItemType Directory `
            -Force |
            Out-Null
    }

    $publicCommands = if ($NoPublicWrapper.IsPresent) {
        @()
    }
    else {
        @($assessmentCommand)
    }

    $manifest = [ordered]@{
        Name              = $Name
        DisplayName       = $Name
        Version           = $Version
        SchemaVersion     = "2.0"
        Category          = $Category
        Description       = $Description
        SupportsDashboard = $true
        SupportsJson      = $true
        SupportsPassThru  = $true
        SupportsGraph     = $SupportsGraph.IsPresent
        EntryPoint        = $assessmentFile
        EntryPoints       = [ordered]@{
            Assessment = $assessmentFile
            Discovery  = $discoveryFile
            Analyzer   = $analyzerFile
        }
        PublicCommands    = $publicCommands
        Dependencies      = @($Dependencies)
        RequiredScopes    = @($RequiredScopes)
        Operations        = @($Operations)
    }

    $manifest |
        ConvertTo-Json `
            -Depth 10 |
        Set-Content `
            -LiteralPath (
                Join-Path `
                    -Path $engineRoot `
                    -ChildPath "engine.json"
            ) `
            -Encoding utf8

    $assessmentContent = @"
[CmdletBinding()]
param(
    [Parameter()]
    [switch]`$IncludeObjects,

    [Parameter()]
    [switch]`$ExportJson,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]`$OutputPath =
        ".\reports\$($Name.ToLowerInvariant())\$($Name.ToLowerInvariant())-assessment.json",

    [Parameter()]
    [switch]`$PassThru
)

`$ErrorActionPreference = "Stop"

try {
    `$findings = [System.Collections.Generic.List[object]]::new()

    # TODO: Collect and normalize $Name data.
    # TODO: Add findings with New-BKFinding.

    `$score = Measure-BKScore `
        -Findings @(`$findings)

    `$summary = [PSCustomObject]@{
        Status        = "Complete"
        Health        = `$score.Health
        Score         = `$score.Score
        TotalFindings = `$findings.Count
    }

    `$result = New-BKAssessmentResult `
        -Engine "$Name" `
        -Operation "${Name}Assessment" `
        -Summary `$summary `
        -Scores `$score `
        -Findings @(`$findings) `
        -Metadata @{
            EngineVersion = "$Version"
        }

    if (`$ExportJson.IsPresent) {
        `$result |
            Export-BKJson `
                -Path `$OutputPath
    }

    if (`$PassThru.IsPresent) {
        return `$result
    }
}
catch {
    throw "${Name} assessment failed: `$(`$_.Exception.Message)"
}
"@

    $discoveryContent = @"
[CmdletBinding()]
param(
    [Parameter()]
    [switch]`$PassThru
)

`$ErrorActionPreference = "Stop"

# TODO: Implement $Name discovery.
`$result = [PSCustomObject]@{
    Platform    = "Blackknight One"
    Engine      = "$Name"
    Operation   = "${Name}Discovery"
    GeneratedAt = (Get-Date).ToUniversalTime().ToString("o")
    Objects     = @()
}

if (`$PassThru.IsPresent) {
    return `$result
}
"@

    $analyzerContent = @"
[CmdletBinding()]
param(
    [Parameter()]
    [AllowNull()]
    [object]`$Discovery,

    [Parameter()]
    [switch]`$PassThru
)

`$ErrorActionPreference = "Stop"

# TODO: Implement $Name analysis.
`$result = [PSCustomObject]@{
    Platform    = "Blackknight One"
    Engine      = "$Name"
    Operation   = "${Name}Analysis"
    GeneratedAt = (Get-Date).ToUniversalTime().ToString("o")
    Findings    = @()
}

if (`$PassThru.IsPresent) {
    return `$result
}
"@

    Set-Content `
        -LiteralPath (
            Join-Path -Path $engineRoot -ChildPath $assessmentFile
        ) `
        -Value $assessmentContent `
        -Encoding utf8

    Set-Content `
        -LiteralPath (
            Join-Path -Path $engineRoot -ChildPath $discoveryFile
        ) `
        -Value $discoveryContent `
        -Encoding utf8

    Set-Content `
        -LiteralPath (
            Join-Path -Path $engineRoot -ChildPath $analyzerFile
        ) `
        -Value $analyzerContent `
        -Encoding utf8

    $privateReadme = @"
# $Name Private Helpers

Place internal helper functions for the $Name engine in this folder.
Private helpers are loaded into module scope but are not exported publicly.
"@

    Set-Content `
        -LiteralPath (
            Join-Path `
                -Path $engineRoot `
                -ChildPath "Private\README.md"
        ) `
        -Value $privateReadme `
        -Encoding utf8

    $testContent = @"
Describe "$Name engine scaffold" {
    It "has a valid engine manifest" {
        `$manifestPath = Join-Path `
            -Path `$PSScriptRoot `
            -ChildPath "..\engine.json"

        `$manifest = Get-Content `
            -LiteralPath `$manifestPath `
            -Raw |
            ConvertFrom-Json

        `$manifest.Name | Should -Be "$Name"
        `$manifest.Version | Should -Be "$Version"
    }

    It "contains all declared entry points" {
        foreach (`$entryPoint in @(
            "$assessmentFile"
            "$discoveryFile"
            "$analyzerFile"
        )) {
            Test-Path `
                -LiteralPath (
                    Join-Path `
                        -Path (Split-Path `$PSScriptRoot -Parent) `
                        -ChildPath `$entryPoint
                ) | Should -BeTrue
        }
    }
}
"@

    Set-Content `
        -LiteralPath (
            Join-Path `
                -Path $engineRoot `
                -ChildPath "Tests\$Name.Tests.ps1"
        ) `
        -Value $testContent `
        -Encoding utf8

    $engineReadme = @"
# $Name Engine

$Description

## Public command

````powershell
$assessmentCommand -PassThru
````

## Entry points

- `$assessmentFile`
- `$discoveryFile`
- `$analyzerFile`

## Development

Use Shared Framework helpers for findings, scoring, reporting, export,
Graph paging, and validation. Keep engine-specific helpers in `Private`.
"@

    Set-Content `
        -LiteralPath (
            Join-Path -Path $engineRoot -ChildPath "README.md"
        ) `
        -Value $engineReadme `
        -Encoding utf8

    if (-not $NoPublicWrapper.IsPresent) {
        $wrapperContent = @"
function $assessmentCommand {
    <#
    .SYNOPSIS
    Runs the Blackknight One $Name assessment.
    #>

    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]`$IncludeObjects,

        [Parameter()]
        [switch]`$ExportJson,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]`$OutputPath =
            ".\reports\$($Name.ToLowerInvariant())\$($Name.ToLowerInvariant())-assessment.json",

        [Parameter()]
        [switch]`$PassThru
    )

    `$engineScript = [System.IO.Path]::GetFullPath(
        (
            Join-Path `
                -Path `$PSScriptRoot `
                -ChildPath "..\..\$Name\$assessmentFile"
        )
    )

    if (
        -not (
            Test-Path `
                -LiteralPath `$engineScript `
                -PathType Leaf
        )
    ) {
        throw "$Name assessment engine was not found: `$engineScript"
    }

    `$parameters = @{
        IncludeObjects = `$IncludeObjects.IsPresent
        ExportJson     = `$ExportJson.IsPresent
        OutputPath     = `$OutputPath
        PassThru       = `$PassThru.IsPresent
    }

    try {
        `$engineOutput = @(
            & `$engineScript @parameters
        )

        `$result = `$engineOutput |
            Where-Object {
                `$null -ne `$_ -and
                `$_.PSObject.Properties.Name -contains "Operation" -and
                `$_.Operation -eq "${Name}Assessment"
            } |
            Select-Object -Last 1

        if (
            `$PassThru.IsPresent -and
            `$null -eq `$result
        ) {
            throw (
                "$Name assessment completed without returning " +
                "a valid result object."
            )
        }

        if (`$PassThru.IsPresent) {
            return `$result
        }
    }
    catch {
        throw "$Name assessment failed: `$(`$_.Exception.Message)"
    }
}
"@

        Set-Content `
            -LiteralPath $wrapperPath `
            -Value $wrapperContent `
            -Encoding utf8
    }

    $registry = @(
        Get-BKEngineRegistry `
            -Refresh `
            -IncludeInvalid
    )

    $createdEngine = $registry |
        Where-Object {
            $_.Name -eq $Name
        } |
        Select-Object -First 1

    $result = [PSCustomObject]@{
        Name              = $Name
        Category          = $Category
        Version           = $Version
        EngineRoot        = $engineRoot
        ManifestPath      = Join-Path `
            -Path $engineRoot `
            -ChildPath "engine.json"
        PublicWrapperPath = if ($NoPublicWrapper.IsPresent) {
            $null
        }
        else {
            $wrapperPath
        }
        IsValid           = $createdEngine.IsValid
        ValidationErrors  = @($createdEngine.ValidationErrors)
        CreatedAt         = (
            Get-Date
        ).ToUniversalTime().ToString("o")
    }

    Write-Host ""
    Write-Host "Blackknight engine scaffold created" `
        -ForegroundColor Green
    Write-Host "------------------------------------------------------------"
    Write-Host "Name        : $Name"
    Write-Host "Category    : $Category"
    Write-Host "Version     : $Version"
    Write-Host "Engine Root : $engineRoot"
    Write-Host "Manifest    : $($result.ManifestPath)"
    Write-Host "Valid       : $($result.IsValid)"

    if ($PassThru.IsPresent) {
        return $result
    }
}
