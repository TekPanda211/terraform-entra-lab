function Get-BKPlatformConfiguration {

    [CmdletBinding()]
    param()

    $moduleRoot = Split-Path $PSScriptRoot -Parent
    $configPath = Join-Path $moduleRoot "Registry\platform.json"

    if (!(Test-Path $configPath)) {
        throw "Platform configuration not found."
    }

    Get-Content $configPath -Raw | ConvertFrom-Json

}