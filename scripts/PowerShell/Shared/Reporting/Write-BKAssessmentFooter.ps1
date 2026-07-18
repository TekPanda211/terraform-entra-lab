function Write-BKAssessmentFooter {
    [CmdletBinding()]
    param([Parameter(Mandatory, ValueFromPipeline)][object]$Result)
    process {
        Write-Host ("-" * 60)
        Write-Host "Engine: $($Result.Engine)"
        Write-Host "Generated: $($Result.GeneratedAt)"
        Write-Host "Confidence: $($Result.Confidence)%"
        Write-Host ""
    }
}
