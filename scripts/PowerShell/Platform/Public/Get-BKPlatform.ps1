function Get-BKPlatform {

    [CmdletBinding()]
    param()

    Write-BKLog -Message "Collecting Blackknight platform information..." -Level Info

    $configuration = Get-BKPlatformConfiguration
    $services      = Get-BKServiceManifest
    $engines       = Get-BKEngineManifest
    $capabilities  = Get-BKCapabilities
    $inventory     = Get-BKPlatformInventory

    [PSCustomObject]@{

        Name           = $configuration.Platform.Name
        Version        = $configuration.Platform.Version
        Mission        = $configuration.Platform.Mission
        NorthStar      = $configuration.Platform.NorthStar

        EngineCount    = $engines.Count
        ServiceCount   = $services.Services.Count
        CapabilityCount= $capabilities.Count

        Inventory      = $inventory
        Engines         = $engines
        Services        = $services.Services
        Capabilities    = $capabilities

    }

}