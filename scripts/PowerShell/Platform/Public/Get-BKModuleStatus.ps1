function Get-BKModuleStatus {
    <#
    .SYNOPSIS
    Returns the current Blackknight One module and framework load status.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$Detailed
    )

    $module = Get-Module -Name "Blackknight-Platform" -ErrorAction SilentlyContinue
    $shared = $script:BKSharedFramework
    $engineRegistry = $script:BKEngineRegistry

    $summary = [PSCustomObject]@{
        PSTypeName        = "Blackknight.ModuleStatus"
        ModuleName        = if ($module) { $module.Name } else { "Blackknight-Platform" }
        ModuleVersion     = if ($module) { $module.Version.ToString() } else { $null }
        ModuleLoaded      = $null -ne $module
        SharedLoaded      = $null -ne $shared
        SharedVersion     = if ($shared) { $shared.Version } else { $null }
        SharedStatus      = if ($shared) { $shared.Status } else { "NotLoaded" }
        SharedFiles       = if ($shared) { @($shared.LoadedFiles).Count } else { 0 }
        SharedFunctions   = if ($shared) { @($shared.LoadedFunctions).Count } else { 0 }
        PublicCommands    = if ($module) { @($module.ExportedCommands.Keys).Count } else { 0 }
        RegisteredEngines = if ($engineRegistry) { @($engineRegistry.Engines).Count } else { 0 }
        RefreshedAt       = [DateTimeOffset]::UtcNow
    }

    if (-not $Detailed.IsPresent) {
        return $summary
    }

    [PSCustomObject]@{
        PSTypeName = "Blackknight.ModuleStatusDetail"
        Summary    = $summary
        Components = if ($shared) { @($shared.Components) } else { @() }
        Engines    = if ($engineRegistry) { @($engineRegistry.Engines) } else { @() }
        Commands   = if ($module) { @($module.ExportedCommands.Keys | Sort-Object) } else { @() }
    }
}
