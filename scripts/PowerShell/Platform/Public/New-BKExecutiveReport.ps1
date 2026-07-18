function New-BKExecutiveReport {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Assessment,[ValidateSet('Object','Json','Html')][string]$Format='Object',[string]$Path)
    New-BKExecutiveReportCore @PSBoundParameters
}
