function Invoke-BKRiskAssessment {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Context)
    Invoke-BKRiskAssessmentCore @PSBoundParameters
}
