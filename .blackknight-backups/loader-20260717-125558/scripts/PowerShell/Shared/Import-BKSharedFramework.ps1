[CmdletBinding()]
param(
    [Parameter()]
    [switch]$PassThru
)

$ErrorActionPreference = "Stop"

$sharedRoot = $PSScriptRoot
$manifestPath = Join-Path -Path $sharedRoot -ChildPath "shared.json"

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Blackknight Shared Framework manifest was not found: $manifestPath"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw -ErrorAction Stop |
    ConvertFrom-Json -ErrorAction Stop

$loadedFiles = [System.Collections.Generic.List[string]]::new()
$loadedFunctions = [System.Collections.Generic.List[string]]::new()

foreach ($category in @($manifest.LoadOrder)) {
    $categoryPath = Join-Path -Path $sharedRoot -ChildPath ([string]$category)

    if (-not (Test-Path -LiteralPath $categoryPath -PathType Container)) {
        throw "Required Shared Framework category was not found: $categoryPath"
    }

    $helperFiles = @(
        Get-ChildItem -LiteralPath $categoryPath -Filter "*.ps1" -File -ErrorAction Stop |
            Sort-Object Name, FullName
    )

    foreach ($helperFile in $helperFiles) {
        Write-Verbose "Loading shared helper: $($helperFile.FullName)"
        . $helperFile.FullName
        $loadedFiles.Add($helperFile.FullName)
        $loadedFunctions.Add($helperFile.BaseName)
    }
}

$missingFunctions = @(
    @($manifest.RequiredHelpers) |
        Where-Object {
            $null -eq (Get-Command -Name ([string]$_) -CommandType Function -ErrorAction SilentlyContinue)
        }
)

if ($missingFunctions.Count -gt 0) {
    throw "Shared Framework failed to load required helpers: $($missingFunctions -join ', ')"
}

$script:BKSharedFramework = [PSCustomObject]@{
    Name            = [string]$manifest.Name
    Version         = [string]$manifest.Version
    SchemaVersion   = [string]$manifest.SchemaVersion
    Root            = $sharedRoot
    ManifestPath    = $manifestPath
    LoadedAt        = (Get-Date).ToUniversalTime().ToString("o")
    LoadedFiles     = @($loadedFiles)
    LoadedFunctions = @($loadedFunctions | Sort-Object -Unique)
}

if ($PassThru.IsPresent) {
    return $script:BKSharedFramework
}
