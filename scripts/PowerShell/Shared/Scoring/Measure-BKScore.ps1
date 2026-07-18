function Measure-BKScore {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowEmptyCollection()]
        [object[]]$Findings = @(),

        [Parameter()]
        [ValidateRange(0, 100)]
        [double]$BaseScore = 100,

        [Parameter()]
        [hashtable]$SeverityWeights = @{
            Informational = 0
            Low           = 1
            Medium        = 3
            High          = 10
            Critical      = 25
        }
    )

    $penalty = 0.0

    foreach ($finding in @($Findings)) {
        if ($null -eq $finding) {
            continue
        }

        $severity = [string]$finding.Severity

        if ($SeverityWeights.ContainsKey($severity)) {
            $penalty += [double]$SeverityWeights[$severity]
        }
    }

    $score = [math]::Max(0, [math]::Round($BaseScore - $penalty, 2))

    $health = if ($score -ge 95) {
        "Excellent"
    }
    elseif ($score -ge 85) {
        "Healthy"
    }
    elseif ($score -ge 70) {
        "Warning"
    }
    elseif ($score -ge 50) {
        "Needs Attention"
    }
    else {
        "Critical"
    }

    [PSCustomObject]@{
        BaseScore = $BaseScore
        Penalty   = [math]::Round($penalty, 2)
        Score     = $score
        Health    = $health
    }
}
