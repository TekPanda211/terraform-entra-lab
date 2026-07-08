<#
.SYNOPSIS
BlackKnight One Core Engine

.DESCRIPTION
The Core Engine is the entry point for BlackKnight One.

It discovers available engines, executes them, and prepares a unified
platform report.

Current Version:
- Operations Engine

Future Engines:
- Identity
- Trust
- Governance
- Endpoint
- Security
- Compliance
- Reporting
- AI
#>

[CmdletBinding()]
param()

$BlackKnightVersion = "0.4.0-alpha"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "        BlackKnight One" -ForegroundColor Cyan
Write-Host " Enterprise Identity Engineering Platform" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Version : $BlackKnightVersion"
Write-Host "Mission : Build • Coach • Mentor"
Write-Host "North Star : One Source of Truth"
Write-Host ""

$Root = Split-Path $PSScriptRoot -Parent

$GovernanceEngine = Join-Path $Root "Governance\Invoke-BlackKnightGovernance.ps1"

if (Test-Path $GovernanceEngine) {
    Write-Host "[+] Loading Governance Engine..." -ForegroundColor Green
    & $GovernanceEngine
}
else {
    Write-Warning "Governance Engine not found."
}

$OperationsEngine = Join-Path $Root "Operations\Invoke-BlackKnightOperations.ps1"

if (Test-Path $OperationsEngine) {
    Write-Host "[+] Loading Operations Engine..." -ForegroundColor Green
    & $OperationsEngine
}
else {
    Write-Warning "Operations Engine not found."
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " BlackKnight Core Complete" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
