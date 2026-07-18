function Invoke-BKCorrelation {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Context)
    Invoke-BKCorrelationCore @PSBoundParameters
}
