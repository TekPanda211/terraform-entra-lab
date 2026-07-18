# Blackknight One Engine SDK

The Engine SDK standardizes how Blackknight One assessment engines are
created, discovered, validated, and exposed through the platform module.

## Commands

```powershell
Get-BKEngine

New-BKEngine `
    -Name Exchange `
    -Category Messaging `
    -Description "Assesses Exchange Online configuration and security." `
    -SupportsGraph `
    -RequiredScopes "Exchange.ManageAsApp" `
    -PassThru
```

## Generated structure

```text
scripts/PowerShell/Exchange/
├── engine.json
├── Invoke-BKExchangeAssessment.ps1
├── Invoke-BKExchangeDiscovery.ps1
├── Invoke-BKExchangeAnalyzer.ps1
├── Private/
│   └── README.md
├── Tests/
│   └── Exchange.Tests.ps1
└── README.md

scripts/PowerShell/Platform/Public/
└── Invoke-BKExchangeAssessment.ps1
```

## Manifest schema

Schema 2.0 remains backward compatible with the legacy `EntryPoint` field and
adds named entry points and capability metadata.

```json
{
  "Name": "Exchange",
  "DisplayName": "Exchange",
  "Version": "0.1.0",
  "SchemaVersion": "2.0",
  "Category": "Messaging",
  "Description": "Assesses Exchange Online configuration and security.",
  "SupportsDashboard": true,
  "SupportsJson": true,
  "SupportsPassThru": true,
  "SupportsGraph": true,
  "EntryPoint": "Invoke-BKExchangeAssessment.ps1",
  "EntryPoints": {
    "Assessment": "Invoke-BKExchangeAssessment.ps1",
    "Discovery": "Invoke-BKExchangeDiscovery.ps1",
    "Analyzer": "Invoke-BKExchangeAnalyzer.ps1"
  },
  "PublicCommands": [
    "Invoke-BKExchangeAssessment"
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
