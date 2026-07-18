function New-BKAssessmentContext {
    [CmdletBinding()]
    param([object]$Tenant,[string]$Name='Blackknight Assessment',[string]$OutputPath='.\reports',[hashtable]$Metadata)
    New-BKAssessmentContextCore @PSBoundParameters
}
