function Write-BKAssessmentSummary {
    [CmdletBinding()]
    param([Parameter(Mandatory, ValueFromPipeline)][object]$Result)
    process {
        if ($null -ne $Result.Summary) {
            $Result.Summary | Format-List | Out-Host
        }
        if ($null -ne $Result.Scores) {
            Write-Host "Scores" -ForegroundColor Cyan
            $Result.Scores | Format-List | Out-Host
        }
    }
}
