# Blackknight One Engine SDK

The Engine SDK standardizes how Blackknight One assessment engines are
created, discovered, validated, and exposed through the platform module.

## Commands

```powershell
Get-BKEngine

New-BKEngine `
    -Name GDAP `
    -Category MSP `
    -Description "Assesses GDAP relationships, role assignments, and delegated access security." `
    -SupportsGraph `
    -RequiredScopes "DelegatedAdminRelationship.Read.All" `
    -PassThru
```

## Generated structure

```text
scripts/PowerShell/GDAP/
├── engine.json
├── Invoke-BKGDAPAssessment.ps1
├── Invoke-BKGDAPDiscovery.ps1
├── Invoke-BKGDAPAnalyzer.ps1
├── Private/
│   └── README.md
├── Tests/
│   └── GDAP.Tests.ps1
└── README.md

scripts/PowerShell/Platform/Public/
└── Invoke-BKGDAPAssessment.ps1
```

## Manifest schema

Schema 2.0 remains backward compatible with the legacy `EntryPoint` field and
adds named entry points and capability metadata.

```json
{
  "Name": "GDAP",
  "DisplayName": "GDAP",
  "Version": "0.1.0",
  "SchemaVersion": "2.0",
  "Category": "MSP",
  "Description": "Assesses GDAP relationships, role assignments, and delegated access security.",
  "SupportsDashboard": true,
  "SupportsJson": true,
  "SupportsPassThru": true,
  "SupportsGraph": true,
  "EntryPoint": "Invoke-BKGDAPAssessment.ps1",
  "EntryPoints": {
    "Assessment": "Invoke-BKGDAPAssessment.ps1",
    "Discovery": "Invoke-BKGDAPDiscovery.ps1",
    "Analyzer": "Invoke-BKGDAPAnalyzer.ps1"
  },
  "PublicCommands": [
    "Invoke-BKGDAPAssessment"
  ],
  "Dependencies": [],
  "RequiredScopes": [],
  "Operations": [
    "Assessment",
    "Discovery",
    "Analysis"
  ]
}
```

## Load model

1. Shared Framework helpers load.
2. Engine manifests are discovered and validated.
3. Engine-private helpers load.
4. Platform-private helpers load.
5. Platform public wrappers load and are exported.

The engine registry is read-only to callers. Engine implementation scripts and
private helpers remain internal.
