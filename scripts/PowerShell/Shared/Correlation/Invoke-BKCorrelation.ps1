function Invoke-BKCorrelationCore {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Context)

    $items = [System.Collections.Generic.List[object]]::new()
    $findings = @($Context.Results | ForEach-Object { @($_.Findings) } | Where-Object { $null -ne $_ })

    $groups = $findings | Group-Object -Property {
        $resource = $_.ResourceId
        if (-not $resource) { $resource = $_.ObjectId }
        if (-not $resource) { $resource = $_.Title }
        [string]$resource
    }

    foreach ($group in $groups) {
        if ($group.Count -lt 2 -or [string]::IsNullOrWhiteSpace($group.Name)) { continue }
        $engines = @($group.Group | ForEach-Object {
            if ($_.Engine) { $_.Engine } elseif ($_.Source) { $_.Source } else { 'Unknown' }
        } | Sort-Object -Unique)
        $item = [PSCustomObject]@{
            PSTypeName  = 'Blackknight.Correlation'
            Id          = [guid]::NewGuid().Guid
            Key         = $group.Name
            Type        = 'CrossEngineFinding'
            Engines     = $engines
            FindingCount= $group.Count
            Severity    = if (@($group.Group.Severity) -contains 'Critical') { 'Critical' } elseif (@($group.Group.Severity) -contains 'High') { 'High' } else { 'Medium' }
            Findings    = @($group.Group)
            GeneratedAt = [DateTimeOffset]::UtcNow
        }
        [void]$items.Add($item)
        [void]$Context.Correlations.Add($item)
        if ($Context.Tenant.Relationships) { [void]$Context.Tenant.Relationships.Add($item) }
    }
    @($items)
}
