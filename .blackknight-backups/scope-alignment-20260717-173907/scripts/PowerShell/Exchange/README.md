# Exchange Engine

Assesses Exchange Online configuration and security.

## Public command

``powershell
Invoke-BKExchangeAssessment -PassThru
``

## Entry points

- $assessmentFile
- $discoveryFile
- $analyzerFile

## Development

Use Shared Framework helpers for findings, scoring, reporting, export,
Graph paging, and validation. Keep engine-specific helpers in Private.
