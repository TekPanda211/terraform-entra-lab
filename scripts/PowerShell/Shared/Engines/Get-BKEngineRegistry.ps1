function Get-BKEngineRegistry {
    <#
    .SYNOPSIS
    Discovers Blackknight One engine manifests.

    .DESCRIPTION
    Discovers engine.json files beneath the PowerShell engine root, validates
    each manifest, and returns normalized engine registry records. Platform and
    Shared folders are excluded automatically.
    #>

    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$PowerShellRoot,

        [Parameter()]
        [switch]$IncludeInvalid,

        [Parameter()]
        [switch]$Refresh
    )

    if ([string]::IsNullOrWhiteSpace($PowerShellRoot)) {
        $PowerShellRoot = [System.IO.Path]::GetFullPath(
            (
                Join-Path `
                    -Path $PSScriptRoot `
                    -ChildPath "..\.."
            )
        )
    }
    else {
        $PowerShellRoot = [System.IO.Path]::GetFullPath(
            $PowerShellRoot
        )
    }

    if (
        -not (
            Test-Path `
                -LiteralPath $PowerShellRoot `
                -PathType Container
        )
    ) {
        throw "PowerShell engine root was not found: $PowerShellRoot"
    }

    if (
        -not $Refresh.IsPresent -and
        $null -ne $script:BKEngineRegistry -and
        $script:BKEngineRegistry.PowerShellRoot -eq $PowerShellRoot
    ) {
        $cachedEngines = @($script:BKEngineRegistry.Engines)

        if ($IncludeInvalid.IsPresent) {
            return $cachedEngines
        }

        return @(
            $cachedEngines |
                Where-Object {
                    $_.IsValid
                }
        )
    }

    $manifestFiles = @(
        Get-ChildItem `
            -LiteralPath $PowerShellRoot `
            -Filter "engine.json" `
            -File `
            -Recurse `
            -ErrorAction Stop |
            Where-Object {
                $relativePath = [System.IO.Path]::GetRelativePath(
                    $PowerShellRoot,
                    $_.FullName
                )

                $firstSegment = (
                    $relativePath -split '[\\/]'
                )[0]

                $firstSegment -notin @(
                    "Platform"
                    "Shared"
                )
            } |
            Sort-Object FullName
    )

    $engines = [System.Collections.Generic.List[object]]::new()

    foreach ($manifestFile in $manifestFiles) {
        try {
            $manifest = Get-Content `
                -LiteralPath $manifestFile.FullName `
                -Raw `
                -ErrorAction Stop |
                ConvertFrom-Json `
                    -ErrorAction Stop

            $validation = Test-BKEngineManifest `
                -Manifest $manifest `
                -ManifestPath $manifestFile.FullName

            $entryPoints = [ordered]@{}

            $legacyEntryPoint = [string](
                Get-BKPropertyValue `
                    -InputObject $manifest `
                    -Name "EntryPoint"
            )

            if (-not [string]::IsNullOrWhiteSpace($legacyEntryPoint)) {
                $entryPoints.Assessment = $legacyEntryPoint
            }

            $manifestEntryPoints = Get-BKPropertyValue `
                -InputObject $manifest `
                -Name "EntryPoints"

            if ($null -ne $manifestEntryPoints) {
                foreach ($property in $manifestEntryPoints.PSObject.Properties) {
                    $entryPoints[$property.Name] = [string]$property.Value
                }
            }

            $engines.Add(
                [PSCustomObject]@{
                    Name              = [string]$manifest.Name
                    DisplayName       = [string](
                        Get-BKPropertyValue `
                            -InputObject $manifest `
                            -Name "DisplayName" `
                            -DefaultValue $manifest.Name
                    )
                    Version           = [string]$manifest.Version
                    SchemaVersion     = [string](
                        Get-BKPropertyValue `
                            -InputObject $manifest `
                            -Name "SchemaVersion" `
                            -DefaultValue "1.0"
                    )
                    Category          = [string](
                        Get-BKPropertyValue `
                            -InputObject $manifest `
                            -Name "Category" `
                            -DefaultValue "General"
                    )
                    Description       = [string]$manifest.Description
                    Root              = $manifestFile.Directory.FullName
                    ManifestPath      = $manifestFile.FullName
                    EntryPoints       = [PSCustomObject]$entryPoints
                    PublicCommands    = @(
                        Get-BKPropertyValue `
                            -InputObject $manifest `
                            -Name "PublicCommands" `
                            -DefaultValue @()
                    )
                    Operations        = @(
                        Get-BKPropertyValue `
                            -InputObject $manifest `
                            -Name "Operations" `
                            -DefaultValue @()
                    )
                    OperationNames    = @($entryPoints.Keys)
                    Dependencies      = @(
                        Get-BKPropertyValue `
                            -InputObject $manifest `
                            -Name "Dependencies" `
                            -DefaultValue @()
                    )
                    RequiredScopes    = @(
                        Get-BKPropertyValue `
                            -InputObject $manifest `
                            -Name @(
                                "RequiredScopes"
                                "MinimumScopes"
                            ) `
                            -DefaultValue @()
                    )
                    Enabled           = [bool](
                        Get-BKPropertyValue `
                            -InputObject $manifest `
                            -Name "Enabled" `
                            -DefaultValue $true
                    )
                    Status            = [string](
                        Get-BKPropertyValue `
                            -InputObject $manifest `
                            -Name "Status" `
                            -DefaultValue "Available"
                    )
                    SupportsDashboard = [bool](
                        Get-BKPropertyValue `
                            -InputObject $manifest `
                            -Name "SupportsDashboard" `
                            -DefaultValue (
                                $entryPoints.Contains("Assessment") -or
                                -not [string]::IsNullOrWhiteSpace($legacyEntryPoint)
                            )
                    )
                    SupportsJson      = [bool](
                        Get-BKPropertyValue `
                            -InputObject $manifest `
                            -Name "SupportsJson" `
                            -DefaultValue $true
                    )
                    SupportsPassThru  = [bool](
                        Get-BKPropertyValue `
                            -InputObject $manifest `
                            -Name "SupportsPassThru" `
                            -DefaultValue $true
                    )
                    SupportsGraph     = [bool](
                        Get-BKPropertyValue `
                            -InputObject $manifest `
                            -Name @(
                                "SupportsGraph"
                                "RequiresGraph"
                            ) `
                            -DefaultValue $false
                    )
                    HasAssessment     = (
                        $entryPoints.Contains("Assessment") -or
                        -not [string]::IsNullOrWhiteSpace($legacyEntryPoint)
                    )
                    Capabilities      = @(
                        Get-BKPropertyValue `
                            -InputObject $manifest `
                            -Name "Capabilities" `
                            -DefaultValue @()
                    )
                    ProducesReport    = [bool](
                        Get-BKPropertyValue `
                            -InputObject $manifest `
                            -Name "ProducesReport" `
                            -DefaultValue $false
                    )
                    IsValid           = $validation.IsValid
                    ValidationErrors  = @($validation.Errors)
                    ValidationWarnings = @($validation.Warnings)
                    Manifest          = $manifest
                }
            )
        }
        catch {
            $engines.Add(
                [PSCustomObject]@{
                    Name               = $manifestFile.Directory.Name
                    DisplayName        = $manifestFile.Directory.Name
                    Version            = $null
                    SchemaVersion      = $null
                    Category           = "Unknown"
                    Description        = $null
                    Root               = $manifestFile.Directory.FullName
                    ManifestPath       = $manifestFile.FullName
                    EntryPoints        = $null
                    PublicCommands     = @()
                    Operations         = @()
                    OperationNames     = @()
                    Dependencies       = @()
                    RequiredScopes     = @()
                    Enabled            = $false
                    Status             = "Invalid"
                    SupportsDashboard  = $false
                    SupportsJson       = $false
                    SupportsPassThru   = $false
                    SupportsGraph      = $false
                    HasAssessment      = $false
                    Capabilities       = @()
                    ProducesReport     = $false
                    IsValid            = $false
                    ValidationErrors   = @($_.Exception.Message)
                    ValidationWarnings = @()
                    Manifest           = $null
                }
            )
        }
    }

    $script:BKEngineRegistry = [PSCustomObject]@{
        PowerShellRoot = $PowerShellRoot
        RefreshedAt    = (
            Get-Date
        ).ToUniversalTime().ToString("o")
        Engines        = @($engines)
    }

    if ($IncludeInvalid.IsPresent) {
        return @($engines)
    }

    return @(
        $engines |
            Where-Object {
                $_.IsValid
            }
    )
}
