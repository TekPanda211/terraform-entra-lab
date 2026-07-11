# Blackknight One

> **Enterprise Identity Engineering Platform for Microsoft Entra, Terraform, and Infrastructure as Code**

<p align="center">
  <img src="docs/images/blackknight-one-hero.png"
       alt="Blackknight One Enterprise Identity Engineering Platform"
       width="100%">
</p>

![Version](https://img.shields.io/badge/version-0.5.0--alpha-blue)
![PowerShell](https://img.shields.io/badge/PowerShell-7+-5391FE?logo=powershell)
![Microsoft Graph](https://img.shields.io/badge/Microsoft%20Graph-SDK-00BCF2)
![Terraform](https://img.shields.io/badge/Terraform-Enabled-7B42BC?logo=terraform)
![Status](https://img.shields.io/badge/status-Active%20Development-success)

---

## One Source of Truth

Blackknight One is an open-source **Enterprise Identity Engineering Platform** that combines Microsoft Graph discovery, identity correlation, Terraform infrastructure analysis, policy validation, and engineering automation into a single operational experience.

Unlike traditional reporting tools that simply collect Microsoft Entra data, Blackknight One is designed to discover, understand, validate, correlate, and continuously improve enterprise identity environments.

The long-term vision is simple:

> **One Source of Truth for Enterprise Identity Engineering.**

---

# Why Blackknight One?

Modern Microsoft Entra environments are no longer managed through the portal alone.

Organizations now manage identity using:

- Microsoft Graph
- PowerShell
- Terraform
- Infrastructure as Code
- CI/CD Pipelines
- Zero Trust
- Identity Governance

Each produces valuable information, but none provide a unified operational picture.

Blackknight One bridges that gap.

Instead of asking:

> "Where do I find this information?"

Administrators can ask:

- What identities require attention?
- Why did my confidence score decrease?
- Which Global Administrators are highest risk?
- What changed since yesterday?
- Is my Terraform deployment safe?
- Will this Conditional Access policy break production?
- Can I deploy this identity configuration confidently?

---

# Platform Capabilities

Blackknight One is built around two equal engineering pillars.

---

# Microsoft Entra & Identity

Discover

- Tenant Inventory
- Users
- Groups
- Domains
- Licensing
- Authentication
- Conditional Access
- Directory Roles

Analyze

- Identity Correlation
- Trust Assessment
- Authorization Analysis
- Governance
- Operational Health
- Validation
- Confidence Scoring

Visualize

- Operational Dashboard
- Identity Intelligence
- Recommendations
- JSON Reports

---

# Infrastructure as Code & Terraform

Current

- Terraform Project Discovery
- Terraform Configuration Inventory
- Terraform Registry
- Platform Validation

Planned

- Terraform State Discovery
- Terraform Resource Inventory
- Terraform Plan Validation
- Drift Detection
- Module Analysis
- Security Best Practices
- Identity as Code Validation
- CI/CD Integration

Terraform is treated as a first-class engineering capability—not an add-on.

---

# Platform Architecture

```text
                         Blackknight One
          Enterprise Identity Engineering Platform
────────────────────────────────────────────────────────────

              Microsoft Graph          Terraform / IaC
                     │                       │
                     │                       │
         Discovery & Collection      Configuration Discovery
                     │                       │
                     └───────────┬───────────┘
                                 │
                         Correlation Engine
                                 │
                     Validation & Confidence
                                 │
                Identity Intelligence Platform
                                 │
              Dashboard • Reports • CI/CD Validation
```

---

# Current Engines

| Engine | Purpose |
|----------|----------|
| Identity | Microsoft Entra discovery |
| Trust | Zero Trust assessment |
| Governance | Governance analysis |
| Operations | Operational health |
| Correlation | Identity intelligence |
| Validation | Platform quality assurance |

---

# Quick Start

Clone the repository

```powershell
git clone https://github.com/<YOUR-REPOSITORY>/blackknight-one

cd blackknight-one
```

Import Blackknight

```powershell
Import-Module .\scripts\PowerShell\Platform\Blackknight-Platform.psm1 -Force
```

Validate the platform

```powershell
Test-BKPlatform
```

Connect to Microsoft Graph

```powershell
Connect-BKGraph
```

Run Identity Discovery

```powershell
.\scripts\PowerShell\Identity\Invoke-BKIdentityDiscovery.ps1
```

Run Trust Discovery

```powershell
.\scripts\PowerShell\Trust\Invoke-BKTrustDiscovery.ps1
```

Run Correlation

```powershell
.\scripts\PowerShell\Correlation\Invoke-BKCorrelation.ps1
```

Display the Dashboard

```powershell
Show-BKDashboard
```

Within minutes you'll have a complete operational view of your Microsoft Entra tenant.

---

# Documentation

Complete documentation lives in the **docs** directory.

| Document | Description |
|-----------|-------------|
| Getting Started | First-time setup |
| Installation | Requirements and installation |
| Quick Start | Ten-minute walkthrough |
| Architecture | Platform architecture |
| Platform Overview | Core platform concepts |
| Command Reference | All public commands |
| Engine Guides | Individual engine documentation |
| Examples | Real-world workflows |
| Roadmap | Planned capabilities |

---

# Roadmap

## Identity Engineering

- Group Correlation
- Device Correlation
- Licensing Correlation
- Application Correlation
- Identity Health Scoring
- Identity Drift Detection
- Privileged Identity Management
- Identity Protection
- Access Reviews
- Entitlement Management

---

## Zero Trust

- Conditional Access What If Simulation
- Conditional Access Policy Validation
- Authentication Strength Analysis
- Passkey Readiness
- Passwordless Adoption
- Security Baseline Validation

---

## Infrastructure as Code

Terraform

- State Discovery
- Resource Inventory
- Module Analysis
- Plan Validation
- Policy Validation
- Drift Detection
- Identity as Code Validation
- Automated Documentation Generation

---

## DevSecOps

- CI/CD Validation
- Pull Request Validation
- GitHub Actions Integration
- Azure DevOps Integration
- Configuration Drift Detection
- Continuous Compliance

---

## Platform

- GDAP Assessments
- Multi-Tenant Assessments
- REST API
- Power BI Integration
- Microsoft Sentinel Integration
- Historical Trending
- HTML Executive Reports

---

# Future Vision

Blackknight One is evolving beyond a discovery tool.

The long-term objective is to become a complete Enterprise Identity Engineering Platform capable of:

- Discovering enterprise identity infrastructure.
- Correlating identities, permissions, and trust signals.
- Validating security and operational health.
- Simulating identity and Conditional Access changes before deployment.
- Validating Terraform and Infrastructure as Code.
- Supporting CI/CD identity engineering pipelines.
- Detecting configuration drift over time.
- Providing confidence scores backed by evidence.
- Becoming the operational "One Source of Truth" for enterprise identity.

---

# Contributing

Community contributions are welcome.

Please read:

- CONTRIBUTING.md
- SECURITY.md

before submitting issues or pull requests.

---

# License

MIT License

---

# Built With

- PowerShell 7
- Microsoft Graph SDK
- Microsoft Entra
- Terraform
- Infrastructure as Code
- GitHub

---

> **Build • Coach • Mentor**

Blackknight One exists to help administrators and identity engineers understand, validate, and continuously improve enterprise identity platforms through engineering, automation, and repeatable best practices.