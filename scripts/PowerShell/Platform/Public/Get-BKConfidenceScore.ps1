function Get-BKConfidenceScore {
    param(
        [Parameter(Mandatory)]
        [object[]]$Results
    )

    if (!$Results -or $Results.Count -eq 0) {
        return 0
    }

    [math]::Round(($Results.Confidence | Measure-Object -Average).Average, 2)
}