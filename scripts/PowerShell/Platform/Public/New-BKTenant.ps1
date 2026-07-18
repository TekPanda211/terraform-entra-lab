function New-BKTenant {
    [CmdletBinding()]
    param([string]$TenantId,[string]$DisplayName,[string]$PrimaryDomain,[hashtable]$Metadata)
    New-BKTenantModel @PSBoundParameters
}
