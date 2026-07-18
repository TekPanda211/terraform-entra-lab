function New-BKTenantModel {
    [CmdletBinding()]
    param(
        [string]$TenantId,
        [string]$DisplayName,
        [string]$PrimaryDomain,
        [hashtable]$Metadata
    )

    [PSCustomObject]@{
        PSTypeName    = 'Blackknight.TenantModel'
        SchemaVersion = '1.0'
        TenantId      = $TenantId
        DisplayName   = $DisplayName
        PrimaryDomain = $PrimaryDomain
        CreatedAt     = [DateTimeOffset]::UtcNow
        Identity      = [ordered]@{ Users=@(); Groups=@(); Roles=@(); Applications=@(); ServicePrincipals=@() }
        Access        = [ordered]@{ ConditionalAccess=@(); AuthenticationStrengths=@(); NamedLocations=@() }
        Partner       = [ordered]@{ GDAP=@(); Customers=@(); Relationships=@() }
        Devices       = [ordered]@{ ManagedDevices=@(); Endpoints=@() }
        Security      = [ordered]@{ Defender=@{}; Findings=@(); Risks=@() }
        Cloud         = [ordered]@{ Azure=@{}; Subscriptions=@(); Resources=@() }
        Infrastructure= [ordered]@{ Terraform=@{} }
        Governance    = [ordered]@{ Purview=@{}; Licensing=@{} }
        Assessments   = [System.Collections.Generic.List[object]]::new()
        Relationships = [System.Collections.Generic.List[object]]::new()
        Metadata      = if ($Metadata) { $Metadata } else { @{} }
    }
}
