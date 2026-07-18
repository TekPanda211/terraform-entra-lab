function New-BKEngine {
    <#
    .SYNOPSIS
    Creates a manifest-driven Blackknight assessment engine scaffold.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][ValidatePattern('^[A-Za-z][A-Za-z0-9]+$')][string]$Name,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Category,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Description,
        [Parameter()][ValidatePattern('^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$')][string]$Version = "0.1.0",
        [Parameter()][string[]]$RequiredScopes = @(),
        [Parameter()][string[]]$Dependencies = @(),
        [Parameter()][switch]$SupportsGraph,
        [Parameter()][switch]$NoPublicWrapper,
        [Parameter()][switch]$Force,
        [Parameter()][switch]$PassThru
    )

    $powerShellRoot = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath "..\.."))
    $engineRoot = Join-Path -Path $powerShellRoot -ChildPath $Name
    $publicRoot = Join-Path -Path $powerShellRoot -ChildPath "Platform\Public"
    $assessmentCommand = "Invoke-BK${Name}Assessment"
    $discoveryCommand = "Invoke-BK${Name}Discovery"
    $analyzerCommand = "Invoke-BK${Name}Analyzer"
    $assessmentFile = "$assessmentCommand.ps1"
    $discoveryFile = "$discoveryCommand.ps1"
    $analyzerFile = "$analyzerCommand.ps1"
    $wrapperPath = Join-Path -Path $publicRoot -ChildPath $assessmentFile

    if ((Test-Path -LiteralPath $engineRoot) -and -not $Force.IsPresent) {
        throw "Engine folder already exists: $engineRoot. Use -Force to replace generated scaffold files."
    }
    if (-not $NoPublicWrapper.IsPresent -and (Test-Path -LiteralPath $wrapperPath) -and -not $Force.IsPresent) {
        throw "Public wrapper already exists: $wrapperPath. Use -Force to replace it."
    }
    if (-not $PSCmdlet.ShouldProcess($engineRoot, "Create Blackknight engine scaffold")) { return }

    foreach ($directory in @($engineRoot, (Join-Path $engineRoot "Private"), (Join-Path $engineRoot "Tests"))) {
        New-Item -Path $directory -ItemType Directory -Force | Out-Null
    }

    $manifest = [ordered]@{
        Name = $Name
        DisplayName = "$Name Assessment"
        Version = $Version
        SchemaVersion = "2.0"
        Category = $Category
        Description = $Description
        SupportsDashboard = $true
        SupportsJson = $true
        SupportsPassThru = $true
        SupportsGraph = $SupportsGraph.IsPresent
        EntryPoint = $assessmentFile
        EntryPoints = [ordered]@{ Assessment = $assessmentFile; Discovery = $discoveryFile; Analyzer = $analyzerFile }
        PublicCommands = if ($NoPublicWrapper.IsPresent) { @() } else { @($assessmentCommand) }
        Dependencies = @($Dependencies)
        RequiredScopes = @($RequiredScopes)
        Operations = @("Assessment", "Discovery", "Analyzer")
    }
    $manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $engineRoot "engine.json") -Encoding utf8

    $assessmentContent = @"
[CmdletBinding()]
param(
    [Parameter()][switch]`$IncludeObjects,
    [Parameter()][switch]`$ExportJson,
    [Parameter()][string]`$OutputPath = ".\reports\$($Name.ToLowerInvariant())\$($Name.ToLowerInvariant())-assessment.json",
    [Parameter()][switch]`$PassThru
)
`$ErrorActionPreference = "Stop"
`$findings = [System.Collections.Generic.List[object]]::new()
# TODO: Collect $Name data and add findings with New-BKFinding.
`$score = Measure-BKScore -Findings @(`$findings)
`$summary = [PSCustomObject]@{ Status = "Complete"; Health = `$score.Health; Score = `$score.Score; TotalFindings = `$findings.Count }
`$result = New-BKAssessmentResult -Engine "$Name" -EngineVersion "$Version" -Category "$Category" -Operation "${Name}Assessment" -Summary `$summary -Scores `$score -Findings @(`$findings) -Metadata @{ EngineVersion = "$Version" } -Confidence 100
if (`$ExportJson.IsPresent) { `$result | Export-BKJson -Path `$OutputPath }
if (`$PassThru.IsPresent) { return `$result }
`$result | Write-BKAssessmentSummary
`$result | Write-BKAssessmentFindings
`$result | Write-BKAssessmentFooter
"@
    Set-Content -LiteralPath (Join-Path $engineRoot $assessmentFile) -Value $assessmentContent -Encoding utf8

    $discoveryContent = @"
[CmdletBinding()]
param([Parameter()][switch]`$PassThru)
`$result = [PSCustomObject]@{ Platform = "Blackknight One"; Engine = "$Name"; Operation = "${Name}Discovery"; GeneratedAt = (Get-Date).ToUniversalTime().ToString("o"); Objects = @() }
if (`$PassThru.IsPresent) { return `$result }
`$result
"@
    Set-Content -LiteralPath (Join-Path $engineRoot $discoveryFile) -Value $discoveryContent -Encoding utf8

    $analyzerContent = @"
[CmdletBinding()]
param([Parameter(ValueFromPipeline)][object]`$InputObject, [Parameter()][switch]`$PassThru)
begin { `$items = [System.Collections.Generic.List[object]]::new() }
process { if (`$null -ne `$InputObject) { `$items.Add(`$InputObject) } }
end { `$result = [PSCustomObject]@{ Platform = "Blackknight One"; Engine = "$Name"; Operation = "${Name}Analyzer"; Analyzed = `$items.Count }; if (`$PassThru.IsPresent) { return `$result }; `$result }
"@
    Set-Content -LiteralPath (Join-Path $engineRoot $analyzerFile) -Value $analyzerContent -Encoding utf8

    $readme = "# $Name Engine`n`n$Description`n`nGenerated by Blackknight Framework v0.8.1.`n"
    Set-Content -LiteralPath (Join-Path $engineRoot "README.md") -Value $readme -Encoding utf8

    if (-not $NoPublicWrapper.IsPresent) {
        $wrapperContent = @"
function $assessmentCommand {
    [CmdletBinding()]
    param(
        [Parameter()][switch]`$IncludeObjects,
        [Parameter()][switch]`$ExportJson,
        [Parameter()][string]`$OutputPath = ".\reports\$($Name.ToLowerInvariant())\$($Name.ToLowerInvariant())-assessment.json",
        [Parameter()][switch]`$PassThru
    )
    `$parameters = @{
        IncludeObjects = `$IncludeObjects.IsPresent
        ExportJson = `$ExportJson.IsPresent
        OutputPath = `$OutputPath
        PassThru = `$PassThru.IsPresent
    }
    Invoke-BKEngine -Name "$Name" -Operation "Assessment" -Parameters `$parameters -PassThru:`$PassThru.IsPresent
}
"@
        Set-Content -LiteralPath $wrapperPath -Value $wrapperContent -Encoding utf8
    }

    $validation = Test-BKEngineManifest -Manifest $manifest -ManifestPath (Join-Path $engineRoot "engine.json")
    $result = [PSCustomObject]@{
        Name = $Name; Category = $Category; Version = $Version; EngineRoot = $engineRoot
        ManifestPath = (Join-Path $engineRoot "engine.json"); PublicWrapperPath = if ($NoPublicWrapper.IsPresent) { $null } else { $wrapperPath }
        IsValid = $validation.IsValid; ValidationErrors = @($validation.Errors); CreatedAt = (Get-Date).ToUniversalTime().ToString("o")
    }
    Write-Host "Blackknight engine scaffold created" -ForegroundColor Green
    Write-Host ("-" * 60)
    $result | Format-List Name, Category, Version, EngineRoot, ManifestPath, IsValid | Out-Host
    $null = Get-BKEngineRegistry -Refresh -IncludeInvalid
    if ($PassThru.IsPresent) { return $result }
}
