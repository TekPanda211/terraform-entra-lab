function Get-BKPlatformInventory {
    [CmdletBinding()]
    param()

    Write-BKLog -Message "Collecting Blackknight platform inventory..." -Level Info

    $repoRoot = (Get-Location).Path
    $config = Get-BKPlatformConfiguration
    $services = Get-BKServiceManifest
    $engines = Get-BKEngineManifest

    $engineRoot = Join-Path $repoRoot $config.EngineRoot
    $reportRoot = Join-Path $repoRoot $config.ReportRoot
    $configurationRoot = Join-Path $repoRoot $config.ConfigurationRoot

    $psFiles = Get-ChildItem -Path $engineRoot -Filter "*.ps1" -Recurse -ErrorAction SilentlyContinue
    $reports = Get-ChildItem -Path $reportRoot -Filter "*.json" -Recurse -ErrorAction SilentlyContinue
    $configs = Get-ChildItem -Path $configurationRoot -Filter "*.json" -Recurse -ErrorAction SilentlyContinue
    $docs = Get-ChildItem -Path (Join-Path $repoRoot "docs") -Filter "*.md" -Recurse -ErrorAction SilentlyContinue
    $schemas = Get-ChildItem -Path (Join-Path $repoRoot "schemas") -Filter "*.json" -Recurse -ErrorAction SilentlyContinue
    $terraformFiles = Get-ChildItem -Path (Join-Path $repoRoot "terraform") -Filter "*.tf" -Recurse -ErrorAction SilentlyContinue

    $capabilities = foreach ($engine in $engines) {
        foreach ($capability in ($engine.Capabilities -split ", ")) {
            [PSCustomObject]@{
                Engine     = $engine.DisplayName
                Capability = $capability
            }
        }
    }

    $serviceCount = $services.Services.Count
    $graphServiceCount = ($services.Services | Where-Object { $_.RequiresGraph -eq $true }).Count
    $integratedServiceCount = ($services.Services | Where-Object { $_.Status -eq "Integrated" }).Count

    [PSCustomObject]@{
        PlatformName       = $config.Platform.Name
        PlatformVersion    = $config.Platform.Version
        Mission            = $config.Platform.Mission
        NorthStar          = $config.Platform.NorthStar

        Engines            = $engines.Count
        Services           = $serviceCount
        Capabilities       = $capabilities.Count

        GraphServices      = $graphServiceCount
        IntegratedServices = $integratedServiceCount

        PowerShellFiles    = $psFiles.Count
        Reports            = $reports.Count
        ConfigFiles        = $configs.Count
        DocumentationFiles = $docs.Count
        SchemaFiles        = $schemas.Count
        TerraformFiles     = $terraformFiles.Count

        Timestamp          = (Get-Date).ToUniversalTime().ToString("o")
    }
}