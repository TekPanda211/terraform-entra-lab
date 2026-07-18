function Write-BKAssessmentFindings {
    [CmdletBinding()]
    param([Parameter(Mandatory, ValueFromPipeline)][object]$Result)
    process {
        $findings = @($Result.Findings)
        Write-Host "Findings: $($findings.Count)" -ForegroundColor Cyan
        if ($findings.Count -gt 0) {
            $findings |
                Select-Object Severity, Title, Recommendation |
                Format-Table -Wrap -AutoSize |
                Out-Host
        }
    }
}
