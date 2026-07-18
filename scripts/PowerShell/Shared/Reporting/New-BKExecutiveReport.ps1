function New-BKExecutiveReportCore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Assessment,
        [ValidateSet('Object','Json','Html')][string]$Format = 'Object',
        [string]$Path
    )

    $context = if ($Assessment.Context) { $Assessment.Context } else { $Assessment }
    $risk = if ($Assessment.Risk) { $Assessment.Risk } else { Invoke-BKRiskAssessmentCore -Context $context }
    $topRisks = @($risk.Risks | Sort-Object Weight -Descending | Select-Object -First 10)
    $report = [PSCustomObject]@{
        PSTypeName       = 'Blackknight.ExecutiveReport'
        SchemaVersion    = '1.0'
        GeneratedAt      = [DateTimeOffset]::UtcNow
        Tenant           = $context.Tenant
        OverallScore     = $risk.Score
        OverallHealth    = $risk.Health
        EnginesCompleted = @($context.Results).Count
        Correlations     = @($context.Correlations).Count
        Errors           = @($context.Errors).Count
        TopRisks         = $topRisks
        EngineSummary    = @($context.Results | ForEach-Object {
            [PSCustomObject]@{ Engine=$_.Engine; Status=$_.Status; Score=$_.Summary.Score; Findings=@($_.Findings).Count }
        })
    }

    if ($Format -eq 'Json') {
        $content = $report | ConvertTo-Json -Depth 12
        if ($Path) { $parent=Split-Path $Path -Parent; if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }; Set-Content -LiteralPath $Path -Value $content -Encoding utf8 }
        return $content
    }
    if ($Format -eq 'Html') {
        $rows = ($report.EngineSummary | ForEach-Object { "<tr><td>$($_.Engine)</td><td>$($_.Status)</td><td>$($_.Score)</td><td>$($_.Findings)</td></tr>" }) -join "`n"
        $html = "<!doctype html><html><head><meta charset='utf-8'><title>Blackknight Executive Report</title><style>body{font-family:Segoe UI,Arial;margin:36px}table{border-collapse:collapse;width:100%}th,td{border:1px solid #ccc;padding:8px;text-align:left}.score{font-size:42px;font-weight:700}</style></head><body><h1>Blackknight One Executive Report</h1><div class='score'>$($report.OverallScore)</div><h2>$($report.OverallHealth)</h2><p>Engines: $($report.EnginesCompleted) | Correlations: $($report.Correlations) | Errors: $($report.Errors)</p><h2>Engine Summary</h2><table><tr><th>Engine</th><th>Status</th><th>Score</th><th>Findings</th></tr>$rows</table></body></html>"
        if ($Path) { $parent=Split-Path $Path -Parent; if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }; Set-Content -LiteralPath $Path -Value $html -Encoding utf8 }
        return $html
    }
    $report
}
