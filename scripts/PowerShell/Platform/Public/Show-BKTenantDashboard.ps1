function Show-BKTenantDashboard {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Assessment)

    $context = if ($Assessment.Context) { $Assessment.Context } else { $Assessment }
    $risk = if ($Assessment.Risk) { $Assessment.Risk } else { Invoke-BKRiskAssessmentCore -Context $context }
    $name = if ($context.Tenant.DisplayName) { $context.Tenant.DisplayName } elseif ($context.Tenant.PrimaryDomain) { $context.Tenant.PrimaryDomain } else { 'Unknown tenant' }

    Write-Host ''
    Write-Host ('=' * 64)
    Write-Host 'BLACKKNIGHT ONE - TENANT DASHBOARD'
    Write-Host ('=' * 64)
    Write-Host ("Tenant             : {0}" -f $name)
    Write-Host ("Assessment Status  : {0}" -f $context.Status)
    Write-Host ("Overall Score      : {0}" -f $risk.Score)
    Write-Host ("Overall Health     : {0}" -f $risk.Health)
    Write-Host ("Engines Completed  : {0}" -f @($context.Results).Count)
    Write-Host ("Correlations       : {0}" -f @($context.Correlations).Count)
    Write-Host ("Errors             : {0}" -f @($context.Errors).Count)
    Write-Host ('-' * 64)
    Write-Host 'Engine Summary'
    foreach ($result in @($context.Results)) {
        $score = if ($result.Summary.Score -ne $null) { $result.Summary.Score } elseif ($result.Scores.Score -ne $null) { $result.Scores.Score } else { '-' }
        Write-Host ("{0,-30} {1,5}  Findings: {2}" -f $result.Engine,$score,@($result.Findings).Count)
    }
    Write-Host ('-' * 64)
    Write-Host 'Highest Risks'
    foreach ($item in @($risk.Risks | Sort-Object Weight -Descending | Select-Object -First 5)) {
        Write-Host ("[{0}] {1}" -f $item.Severity,$item.Title)
    }
    Write-Host ('=' * 64)
    $Assessment
}
