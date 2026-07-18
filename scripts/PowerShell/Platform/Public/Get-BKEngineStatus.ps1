function Get-BKEngineStatus {
    <#
    .SYNOPSIS
    Returns runtime health and capability information for registered engines.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Name = "*",

        [Parameter()]
        [switch]$Refresh
    )

    $engines = @(
        Get-BKEngine `
            -Name $Name `
            -IncludeInvalid `
            -Refresh:$Refresh.IsPresent
    )

    foreach ($engine in $engines) {
        [PSCustomObject]@{
            Name              = $engine.Name
            DisplayName       = $engine.DisplayName
            Category          = $engine.Category
            Version           = $engine.Version
            Enabled           = $engine.Enabled
            IsValid           = $engine.IsValid
            HasAssessment     = $engine.HasAssessment
            SupportsDashboard = $engine.SupportsDashboard
            SupportsGraph     = $engine.SupportsGraph
            Operations        = @($engine.OperationNames)
            RequiredScopes    = @($engine.RequiredScopes)
            Status            = if (-not $engine.Enabled) {
                "Disabled"
            }
            elseif (-not $engine.IsValid) {
                "Invalid"
            }
            elseif (-not $engine.HasAssessment) {
                "DiscoveryOnly"
            }
            else {
                "Ready"
            }
            Errors            = @($engine.ValidationErrors)
            Warnings          = @($engine.ValidationWarnings)
        }
    }
}
