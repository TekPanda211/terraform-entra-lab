# Blackknight Shared Framework

The Blackknight Shared Framework provides reusable primitives for every assessment engine.

## Load order

1. Utilities
2. Findings
3. Scoring
4. Reporting
5. Export
6. Graph
7. Validation
8. Engine-private helpers
9. Platform-private helpers
10. Platform-public wrappers

Only files under `Platform/Public` are exported from the module. Shared and engine-private functions remain internal implementation details.

## Core helpers

- `ConvertTo-BKArray`
- `Get-BKPropertyValue`
- `New-BKFinding`
- `Measure-BKScore`
- `New-BKAssessmentResult`
- `Export-BKJson`
- `Invoke-BKGraphPagedRequest`
- `Test-BKRequiredGraphScopes`

## Validation

```powershell
Test-BKSharedFramework
Test-BKPlatform
```

## Engine adoption

New engines should use shared helpers instead of defining duplicate findings, scoring, JSON export, Graph paging, or property-access functions.
