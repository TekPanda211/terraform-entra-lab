# Blackknight Loader Stabilization v0.9.1

This focused patch fixes the Shared Framework wiring issue that prevented the Platform Intelligence commands from finding their private implementations.

## Changes

- Adds `Models`, `Context`, `Correlation`, `Risk`, and `Orchestration` to the Shared Framework load order.
- Requires all Platform Intelligence core functions during framework startup.
- Discovers additional Shared Framework component folders automatically after the declared dependency order.
- Parses every shared helper before dot-sourcing it.
- Adds component-level load status tracking.
- Adds `Get-BKModuleStatus` for module, framework, component, command, and engine diagnostics.
- Updates the module version to `0.9.1`.

## Install

```powershell
Set-Location "C:\Users\ToddCrow\Source\blackknight-one"

Expand-Archive `
    -LiteralPath "C:\Users\ToddCrow\Downloads\Blackknight-Loader-Stabilization-v0.9.1.zip" `
    -DestinationPath ".\loader-091-install" `
    -Force

& ".\loader-091-install\Blackknight-Loader-Stabilization-v0.9.1\Install-BKLoaderStabilization.ps1" `
    -RepositoryRoot "C:\Users\ToddCrow\Source\blackknight-one"
```

## Reload and validate

```powershell
Remove-Module Blackknight-Platform -ErrorAction SilentlyContinue

Import-Module `
    ".\scripts\PowerShell\Platform\Blackknight-Platform.psd1" `
    -Force `
    -Verbose

Get-BKModuleStatus | Format-List
Get-BKModuleStatus -Detailed
```

## Functional validation

```powershell
$tenant = New-BKTenant `
    -DisplayName "Todd's Lab Tenant" `
    -PrimaryDomain "yourtenant.onmicrosoft.com"

$context = New-BKAssessmentContext `
    -Tenant $tenant `
    -Name "Full Tenant Assessment"

$tenant | Format-List DisplayName, PrimaryDomain, SchemaVersion
$context | Format-List Name, Status, SchemaVersion
```

Then run the orchestrator:

```powershell
$assessment = Invoke-BKAssessment `
    -Context $context `
    -ContinueOnError `
    -PassThru

$assessment | Format-List
```
