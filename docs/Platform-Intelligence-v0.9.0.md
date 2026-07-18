# Blackknight Platform Intelligence v0.9.0

This release introduces the first platform-wide assessment layer:

- Tenant digital twin object model
- Shared assessment context
- Multi-engine orchestration
- Cross-engine finding correlation
- Weighted risk assessment
- Executive object, JSON, and HTML reporting
- Tenant dashboard

## Core workflow

```powershell
$tenant = New-BKTenant -DisplayName 'Contoso' -PrimaryDomain 'contoso.com'
$context = New-BKAssessmentContext -Tenant $tenant
$assessment = Invoke-BKAssessment -Context $context -ContinueOnError -PassThru
Show-BKTenantDashboard -Assessment $assessment
New-BKExecutiveReport -Assessment $assessment -Format Html -Path '.\reports\executive.html'
```

The model is intentionally additive. Existing engines remain unchanged and their standardized results are collected into the shared context.
