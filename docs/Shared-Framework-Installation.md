# Shared Framework v0.8.0 Installation

Extract this package into the repository root and allow existing paths to merge.

## Files replaced

- `scripts/PowerShell/Platform/Blackknight-Platform.psm1`
- `scripts/PowerShell/Platform/Public/Test-BKPlatform.ps1`

## Files added

- `scripts/PowerShell/Shared/**`
- `scripts/PowerShell/Platform/Public/Test-BKSharedFramework.ps1`
- `tests/Shared/SharedFramework.Tests.ps1`
- `docs/shared-framework.md`

## Reload

```powershell
Remove-Module Blackknight-Platform -ErrorAction SilentlyContinue
Import-Module ".\scripts\PowerShell\Platform\Blackknight-Platform.psd1" -Force -Verbose
```

## Validate

```powershell
Test-BKSharedFramework
Test-BKPlatform

Get-Command -Module Blackknight-Platform |
    Sort-Object Name |
    Format-Table Name, CommandType, Source -AutoSize
```

Shared helpers must load internally but must not appear in `Get-Command -Module Blackknight-Platform`.

## Pester

```powershell
Invoke-Pester ".\tests\Shared\SharedFramework.Tests.ps1" -Output Detailed
```

## Rollback

Restore `Blackknight-Platform.psm1` and `Test-BKPlatform.ps1` from Git, then remove `scripts/PowerShell/Shared`, `Test-BKSharedFramework.ps1`, and `tests/Shared`.
