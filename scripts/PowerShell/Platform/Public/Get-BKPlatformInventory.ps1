function Get-BKPlatformInventory {
    [CmdletBinding()]
    param()

    Write-BKLog -Message "Collecting Blackknight platform inventory..." -Level Info

    $repoRoot = (Get-Location).Path
    $config = Get-BKPlatformConfiguration

    $engineRoot = Join-Path $repoRoot $config.EngineRoot
    $reportRoot = Join-Path $repoRoot $config.ReportRoot
    $configurationRoot = Join-Path $repoRoot $config.ConfigurationRoot
    $servicesManifestPath = Join-Path $repoRoot $config.ServicesManifest

    $engineManifests = Get-ChildItem -Path $engineRoot -Filter "engine.json" -Recurse -ErrorAction SilentlyContinue
    $psFiles = Get-ChildItem -Path $engineRoot -Filter "*.ps1" -Recurse -ErrorAction SilentlyContinue
    $reports = Get-ChildItem -Path $reportRoot -Filter "*.json" -Recurse -ErrorAction SilentlyContinue
    $configs = Get-ChildItem -Path $configurationRoot -Filter "*.json" -Recurse -ErrorAction SilentlyContinue
    $docs = Get-ChildItem -Path (Join-Path $repoRoot "docs") -Filter "*.md" -Recurse -ErrorAction SilentlyContinue
    $schemas = Get-ChildItem -Path (Join-Path $repoRoot "schemas") -Filter "*.json" -Recurse -ErrorAction SilentlyContinue
    $terraformFiles = Get-ChildItem -Path (Join-Path $repoRoot "terraform") -Filter "*.tf" -Recurse -ErrorAction SilentlyContinue

    $capabilities = Get-BKCapabilities

    $serviceCount = 0
    $graphServiceCount = 0
    $integratedServiceCount = 0

    if (Test-Path $servicesManifestPath) {
        $serviceManifest = Get-Content $servicesManifestPath -Raw | ConvertFrom-Json

        $serviceCount = $serviceManifest.Services.Count
        $graphServiceCount = ($serviceManifest.Services | Where-Object { $_.RequiresGraph -eq $true }).Count
        $integratedServiceCount = ($serviceManifest.Services | Where-Object { $_.Status -eq "Integrated" }).Count
    }

    [PSCustomObject]@{
        PlatformName       = $config.Platform.Name
        PlatformVersion    = $config.Platform.Version
        Mission            = $config.Platform.Mission
        NorthStar          = $config.Platform.NorthStar

        Engines            = $engineManifests.Count
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