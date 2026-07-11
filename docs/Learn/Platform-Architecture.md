\# Platform Architecture



> \*\*Estimated time:\*\* 20–30 minutes  

> \*\*Audience:\*\* Identity Engineers, Security Architects, Platform Engineers, Developers, Contributors, and Microsoft Partners



> \[!NOTE]

> Blackknight One is currently in \*\*v0.5.0-alpha\*\*. The architecture described in this document represents the current design direction and will continue to evolve as new capabilities are introduced.



\---



\# Learning Path



This guide is part of the Blackknight One learning path.



```text

Getting Started

&#x20;     │

&#x20;     ▼

Installation

&#x20;     │

&#x20;     ▼

Quick Start

&#x20;     │

&#x20;     ▼

Platform Overview

&#x20;     │

&#x20;     ▼

Platform Architecture

&#x20;     │

&#x20;     ▼

Command Reference

```



\---



\# Introduction



Blackknight One is designed as a modular Enterprise Identity Engineering Platform.



Rather than being built around individual scripts or isolated assessments, the platform is organized into reusable services, independent assessment engines, standardized reporting, and confidence scoring.



Every component follows the same engineering principles:



\- Modular

\- Reusable

\- Observable

\- Testable

\- Extensible



This architecture allows new capabilities to be added with minimal impact to the existing platform.



\---



\# Architectural Goals



Blackknight One has several architectural objectives.



\- Discover enterprise identity infrastructure.

\- Correlate information across Microsoft Graph services.

\- Validate engineering decisions before production deployment.

\- Produce actionable intelligence rather than raw inventory.

\- Support Infrastructure as Code and DevSecOps workflows.

\- Scale from a single Microsoft Entra tenant to multi-tenant Microsoft Partner environments.

\- Provide a consistent engineering experience through standardized services and reporting.



\---



\# Architectural Principles



Every feature added to Blackknight One should support one or more of the platform's engineering pillars.



\## Discover



Collect authoritative information from supported platforms.



Examples include:



\- Microsoft Entra ID

\- Microsoft Graph

\- Terraform

\- Microsoft 365



\---



\## Correlate



Relationships create intelligence.



Correlation combines information across workloads to produce insights that are not available through individual APIs.



Examples include:



\- User ↔ Directory Role

\- User ↔ Authentication Method

\- User ↔ Conditional Access

\- Group ↔ Administrative Role

\- Service Principal ↔ Permissions

\- Terraform ↔ Microsoft Graph



\---



\## Validate



Identity engineering requires validation before deployment.



Validation includes:



\- Platform Health

\- Configuration

\- Identity Security

\- Conditional Access

\- Terraform Plans

\- CI/CD Changes



\---



\## Understand



Collected information becomes useful when transformed into intelligence.



Examples include:



\- Confidence Scores

\- Recommendations

\- Identity Graphs

\- Drift Detection

\- Risk Indicators



\---



\## Automate



Every assessment should be repeatable.



Automation targets include:



\- PowerShell

\- Microsoft Graph

\- Terraform

\- GitHub Actions

\- Azure DevOps

\- REST APIs



\---



\# High-Level Architecture



```text

&#x20;                   Blackknight One

&#x20;       Enterprise Identity Engineering Platform



&#x20;                  Data Sources

────────────────────────────────────────────────────────



&#x20;Microsoft Graph     Terraform      Future APIs



&#x20;       │                 │               │

&#x20;       └─────────────────┼───────────────┘

&#x20;                         │



&#x20;                Discovery Services



&#x20;       Users

&#x20;       Groups

&#x20;       Domains

&#x20;       Licensing

&#x20;       Conditional Access

&#x20;       Authentication

&#x20;       Directory Roles



&#x20;                         │



&#x20;                Platform Services



&#x20;       Logging

&#x20;       Reporting

&#x20;       Validation

&#x20;       Configuration

&#x20;       Registries



&#x20;                         │



&#x20;               Assessment Engines



&#x20;       Identity

&#x20;       Trust

&#x20;       Governance

&#x20;       Operations

&#x20;       Validation

&#x20;       Terraform



&#x20;                         │



&#x20;               Correlation Engine



&#x20;       Identity Graph

&#x20;       Trust Correlation

&#x20;       Authorization

&#x20;       Recommendations



&#x20;                         │



&#x20;              Confidence Engine



&#x20;       Identity

&#x20;       Trust

&#x20;       Governance

&#x20;       Operations

&#x20;       Validation



&#x20;                         │



&#x20;            Presentation Layer



&#x20;       Dashboard

&#x20;       JSON Reports

&#x20;       Power BI

&#x20;       REST API (Planned)

```



\---



\# Platform Layers



Blackknight One is organized into logical layers.



\## Data Sources



External systems supplying authoritative data.



Current:



\- Microsoft Graph

\- Microsoft Entra ID



Future:



\- Terraform State

\- GitHub

\- Azure DevOps

\- Microsoft Sentinel



\---



\## Discovery Layer



Responsible for collecting information.



Discovery services never perform analysis.



They only retrieve and normalize data.



Examples include:



\- Get-BKUsers

\- Get-BKGroups

\- Get-BKDomains

\- Get-BKLicensing

\- Get-BKAuthenticationMethodsSummary

\- Get-BKConditionalAccessPolicies



\---



\## Platform Services Layer



Provides reusable services for every engine.



Current services include:



\- Logging

\- Reporting

\- Configuration

\- Validation

\- Registry

\- Confidence Scoring



These services eliminate duplicated code across assessment engines.



\---



\## Assessment Layer



Assessment engines perform analysis.



Current engines:



\- Identity Engine

\- Trust Engine

\- Correlation Engine



Future engines:



\- Governance Engine

\- Operations Engine

\- Terraform Engine



Each engine produces standardized result objects.



\---



\## Correlation Layer



The Correlation Layer combines information from multiple engines into operational intelligence.



Examples include:



\- Administrative exposure

\- MFA coverage

\- Identity Graph

\- Authentication readiness

\- Privileged access analysis



This layer transforms inventory into engineering insights.



\---



\## Confidence Layer



Confidence scores provide a measurable indication of engineering maturity.



Current confidence domains include:



\- Identity

\- Trust

\- Governance

\- Operations

\- Validation



Future domains:



\- Terraform

\- CI/CD

\- Identity Governance



Confidence is calculated using evidence rather than subjective scoring.



\---



\## Presentation Layer



The presentation layer provides information to administrators.



Current interfaces:



\- Dashboard

\- JSON Reports



Future interfaces:



\- HTML Reports

\- Power BI

\- REST API

\- Web Dashboard



\---



\# Platform Registries



Blackknight One maintains several registries.



\## Platform Registry



Defines the overall platform.



Includes:



\- Version

\- Engines

\- Services

\- Capabilities



\---



\## Service Registry



The Service Registry is the authoritative inventory of reusable services.



Each service defines:



\- Name

\- Category

\- Description

\- Required Graph Scopes

\- Status



The registry enables automatic documentation and capability discovery.



\---



\## Engine Registry



The Engine Registry describes every assessment engine.



Each engine specifies:



\- Name

\- Purpose

\- Version

\- Dependencies

\- Capabilities

\- Confidence Domains



This registry allows new engines to integrate without changing the platform core.



\---



\# Standard Data Flow



Every assessment follows the same lifecycle.



```text

Collect

&#x20;     │

Normalize

&#x20;     │

Analyze

&#x20;     │

Correlate

&#x20;     │

Validate

&#x20;     │

Score

&#x20;     │

Report

&#x20;     │

Present

```



This workflow provides consistency across every engine.



\---



\# Reporting Architecture



Assessment engines produce standardized result objects.



Result objects are exported to JSON using common platform services.



Benefits include:



\- Historical comparisons

\- Power BI integration

\- Automation

\- SIEM ingestion

\- CI/CD validation



Future report formats include:



\- HTML

\- Markdown

\- REST API

\- Executive summaries



\---



\# Infrastructure as Code



Terraform is a first-class platform capability.



Future Terraform support includes:



\- Configuration Discovery

\- State Analysis

\- Plan Validation

\- Drift Detection

\- Identity as Code

\- Security Validation



Terraform assessments will use the same confidence model as Microsoft Graph assessments.



\---



\# CI/CD Architecture



Blackknight One is designed to integrate directly into engineering pipelines.



Planned capabilities include:



\- GitHub Actions

\- Azure DevOps

\- Pull Request Validation

\- Conditional Access Simulation

\- Terraform Plan Validation

\- Confidence Gates



The objective is to identify identity engineering issues before deployment.



\---



\# Plugin Architecture



Future versions of Blackknight One will support extensible plugins.



Potential plugin categories include:



\- Additional discovery providers

\- Reporting providers

\- Visualization providers

\- Security analyzers

\- Compliance frameworks



Plugins will integrate through standardized engine and service interfaces.



\---



\# Roadmap



Planned architectural investments include:



\- Multi-tenant assessments

\- GDAP optimization

\- REST API

\- HTML reporting

\- Historical trending

\- Machine-assisted recommendations

\- Identity drift detection

\- Identity as Code

\- Continuous validation



\---



\# Related Documentation



Continue with:



\- Command Reference

\- Identity Engine

\- Trust Engine

\- Correlation Engine

\- Platform Development



\---



\# Summary



Blackknight One is designed around modular services, standardized assessment engines, reusable platform components, and evidence-based confidence scoring.



This layered architecture enables the platform to evolve without sacrificing consistency, maintainability, or extensibility.



Every future capability should reinforce the platform's five engineering pillars:



\- Discover

\- Correlate

\- Validate

\- Understand

\- Automate



Together, these principles provide the architectural foundation for Blackknight One's vision of becoming the \*\*One Source of Truth for Enterprise Identity Engineering\*\*.

