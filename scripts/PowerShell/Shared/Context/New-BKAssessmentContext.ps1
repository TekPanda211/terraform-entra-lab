function New-BKAssessmentContextCore {
    [CmdletBinding()]
    param(
        [object]$Tenant,
        [string]$Name = 'Blackknight Assessment',
        [string]$OutputPath = '.\reports',
        [hashtable]$Metadata
    )

    if (-not $Tenant) { $Tenant = New-BKTenantModel }
    [PSCustomObject]@{
        PSTypeName    = 'Blackknight.AssessmentContext'
        SchemaVersion = '1.0'
        Id            = [guid]::NewGuid().Guid
        Name          = $Name
        StartedAt     = [DateTimeOffset]::UtcNow
        CompletedAt   = $null
        Status        = 'Created'
        OutputPath    = $OutputPath
        Tenant        = $Tenant
        Results       = [System.Collections.Generic.List[object]]::new()
        Correlations  = [System.Collections.Generic.List[object]]::new()
        Risks         = [System.Collections.Generic.List[object]]::new()
        Errors        = [System.Collections.Generic.List[object]]::new()
        Metadata      = if ($Metadata) { $Metadata } else { @{} }
    }
}
