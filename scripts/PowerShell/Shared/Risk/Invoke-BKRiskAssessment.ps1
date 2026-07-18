function Invoke-BKRiskAssessmentCore {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Context)

    $weights = @{ Critical=25; High=12; Medium=5; Low=2; Informational=0 }
    $findings = @($Context.Results | ForEach-Object { @($_.Findings) } | Where-Object { $null -ne $_ })
    $scorePenalty = 0
    $risks = [System.Collections.Generic.List[object]]::new()

    foreach ($finding in $findings) {
        $severity = if ($finding.Severity) { [string]$finding.Severity } else { 'Medium' }
        $weight = if ($weights.ContainsKey($severity)) { $weights[$severity] } else { 5 }
        $scorePenalty += $weight
        $risk = [PSCustomObject]@{
            PSTypeName = 'Blackknight.Risk'
            Id         = [guid]::NewGuid().Guid
            Title      = if ($finding.Title) { $finding.Title } else { 'Assessment finding' }
            Severity   = $severity
            Weight     = $weight
            Engine     = if ($finding.Engine) { $finding.Engine } else { 'Unknown' }
            ResourceId = $finding.ResourceId
            Finding    = $finding
        }
        [void]$risks.Add($risk)
        [void]$Context.Risks.Add($risk)
    }

    foreach ($correlation in @($Context.Correlations)) {
        $bonus = if ($correlation.Severity -eq 'Critical') { 10 } elseif ($correlation.Severity -eq 'High') { 6 } else { 3 }
        $scorePenalty += $bonus
    }

    $score = [math]::Max(0, 100 - [math]::Min(100, $scorePenalty))
    $health = if ($score -ge 90) { 'Excellent' } elseif ($score -ge 75) { 'Good' } elseif ($score -ge 60) { 'Needs Attention' } else { 'High Risk' }
    [PSCustomObject]@{
        PSTypeName       = 'Blackknight.RiskAssessment'
        Score            = $score
        Health           = $health
        TotalRisks       = $risks.Count
        Critical         = @($risks | Where-Object Severity -eq 'Critical').Count
        High             = @($risks | Where-Object Severity -eq 'High').Count
        Medium           = @($risks | Where-Object Severity -eq 'Medium').Count
        Low              = @($risks | Where-Object Severity -eq 'Low').Count
        CorrelationCount = @($Context.Correlations).Count
        Risks            = @($risks)
        GeneratedAt      = [DateTimeOffset]::UtcNow
    }
}
