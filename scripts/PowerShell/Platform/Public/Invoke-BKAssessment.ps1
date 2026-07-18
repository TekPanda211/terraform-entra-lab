function Invoke-BKAssessment {
    [CmdletBinding()]
    param([string[]]$Engine,[object]$Context,[switch]$ContinueOnError,[switch]$SkipCorrelation,[switch]$SkipRisk,[switch]$PassThru)
    Invoke-BKAssessmentCore @PSBoundParameters
}
