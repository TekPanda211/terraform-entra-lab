[CmdletBinding()]
param(
    [Parameter()]
    [switch]$IncludeObjects,

    [Parameter()]
    [switch]$ExportJson,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath =
        ".\reports\exchange\exchange-assessment.json",

    [Parameter()]
    [switch]$PassThru
)

$ErrorActionPreference = "Stop"

try {
    $findings =
        [System.Collections.Generic.List[object]]::new()

    # TODO: Collect and normalize Exchange data.
    # TODO: Add findings with New-BKFinding.

    $scoreParameters = @{
        Findings = @($findings)
    }

    $score =
        Measure-BKScore @scoreParameters

    $summary = [PSCustomObject]@{
        Status        = "Complete"
        Health        = $score.Health
        Score         = $score.Score
        TotalFindings = $findings.Count
    }

    $assessmentParameters = @{
        Engine    = "Exchange"
        Operation = "ExchangeAssessment"
        Summary   = $summary
        Scores    = $score
        Findings  = @($findings)
        Metadata  = @{
            EngineVersion = "0.1.0"
        }
    }

    $result =
        New-BKAssessmentResult @assessmentParameters

    if ($IncludeObjects.IsPresent) {
        if (
            $result.PSObject.Properties.Name -contains
            "Objects"
        ) {
            $result.Objects = @()
        }
    }

    if ($ExportJson.IsPresent) {
        $exportParameters = @{
            Path = $OutputPath
        }

        $result |
            Export-BKJson @exportParameters
    }

    if ($PassThru.IsPresent) {
        return $result
    }

    $result
}
catch {
    throw (
        "Exchange assessment failed: " +
        $_.Exception.Message
    )
}