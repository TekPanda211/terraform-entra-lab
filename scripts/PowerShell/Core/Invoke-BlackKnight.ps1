<#
.SYNOPSIS
Blackknight One Core Engine

.DESCRIPTION
The Core Engine is the entry point for Blackknight One.

It discovers enabled engines, executes them, and prepares unified platform reporting.
#>

[CmdletBinding()]
param(
    [switch]$ExportJson,
    [string]$OutputPath = ".\reports\platform"
)

$BlackKnightVersion = "0.4.0-alpha"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "        Blackknight One" -ForegroundColor Cyan
Write-Host " Enterprise Identity Engineering Platform" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Version    : $BlackKnightVersion"
Write-Host "Mission    : Build • Coach • Mentor"
Write-Host "North Star : One Source of Truth"
Write-Host ""

$Root = Split-Path $PSScriptRoot -Parent

$EngineManifests = Get-ChildItem -Path $Root -Filter "engine.json" -Recurse -ErrorAction SilentlyContinue

if (!$EngineManifests) {
    Write-Warning "No engine manifests found."
}
else {
    foreach ($ManifestFile in $EngineManifests) {
        $Manifest = Get-Content $ManifestFile.FullName -Raw | ConvertFrom-Json

        if ($Manifest.Enabled -ne $true) {
            Write-Host "[-] Skipping disabled engine: $($Manifest.DisplayName)" -ForegroundColor Yellow
            continue
        }

        $EngineFolder = Split-Path $ManifestFile.FullName -Parent
        $EntryPoint = Join-Path $EngineFolder $Manifest.EntryPoint

        if (Test-Path $EntryPoint) {
            Write-Host "[+] Loading $($Manifest.DisplayName)..." -ForegroundColor Green

            if ($ExportJson) {
                & $EntryPoint -ExportJson
            }
            else {
                & $EntryPoint
            }
        }
        else {
            Write-Warning "Entry point not found for $($Manifest.DisplayName): $EntryPoint"
        }
    }
}

if ($ExportJson) {
    if (!(Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }

    $engineReports = Get-ChildItem -Path ".\reports" -Filter "*.json" -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notlike "*\reports\platform\*" }

    $platformReport = foreach ($report in $engineReports) {
        Get-Content $report.FullName -Raw | ConvertFrom-Json
    }

    $platformPath = Join-Path $OutputPath "blackknight-platform-report.json"

    $platformReport | ConvertTo-Json -Depth 10 | Out-File -FilePath $platformPath -Encoding utf8

    Write-Host ""
    Write-Host "Exported unified platform report to $platformPath" -ForegroundColor Green
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " Blackknight Core Complete"
Write-Host "=========================================" -ForegroundColor Cyan