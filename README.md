# Blackknight One

> **Enterprise Identity Engineering Platform**

![Version](https://img.shields.io/badge/version-0.5.0--alpha-blue)
![PowerShell](https://img.shields.io/badge/PowerShell-7+-5391FE)
![Microsoft Graph](https://img.shields.io/badge/Microsoft-Graph-0078D4)
![Status](https://img.shields.io/badge/status-active-success)

---

## What is Blackknight One?

Blackknight One is a modular Microsoft Entra identity engineering platform built to discover, correlate, validate, and continuously improve enterprise identity environments.

Unlike traditional inventory scripts that simply collect information, Blackknight One builds an **Identity Intelligence Model** by correlating identity, authentication, authorization, governance, trust, and operational data into actionable engineering insights.

The goal is simple:

> **Help engineers understand not just *what* exists, but whether it is healthy, secure, and operating as intended.**

---

# Mission

> **Build • Coach • Mentor**

Blackknight One exists to help identity engineers:

- Build secure Microsoft Entra environments
- Coach organizations toward Zero Trust maturity
- Mentor engineers through transparent engineering practices

---

# North Star

> **One Source of Truth**

Every dashboard...

Every report...

Every recommendation...

Every confidence score...

...is generated from reusable platform services built around a single authoritative identity model.

---

# Engineering Philosophy

Blackknight One follows several guiding principles.

## One Source of Truth

Collect information once.

Reuse it everywhere.

Never duplicate discovery.

---

## Correlation Before Conclusions

Raw inventory has little value.

Relationships create intelligence.

Identity

↓

Authentication

↓

Authorization

↓

Trust

↓

Governance

↓

Recommendations

---

## Explainable Engineering

Every recommendation should answer:

- Why was this generated?
- What data supports it?
- How confident is the conclusion?

---

## Confidence Over Compliance

Instead of simply saying:

> PASS

Blackknight measures engineering confidence.

Identity confidence.

Trust confidence.

Governance confidence.

Operational confidence.

Platform confidence.

---

# Platform Architecture

```
                    Blackknight One

                           Platform
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
     Registry              Validation            Reporting
        │                      │                      │
        └──────────────────────┼──────────────────────┘
                               │
                     Platform Services
                               │
        ┌───────────────┬───────────────┬───────────────┐
        │               │               │               │
    Identity         Trust        Governance      Operations
        │               │               │               │
        └───────────────┼───────────────┴───────────────┘
                        │
                  Correlation Engine
                        │
                 Identity Intelligence
                        │
                  Dashboard & Reports
```

---

# Current Platform Status

| Component | Status |
|-----------|--------|
| Platform Registry | ✅ Complete |
| Engine Registry | ✅ Complete |
| Service Registry | ✅ Complete |
| Validation Framework | ✅ Complete |
| Dashboard | ✅ Complete |
| Identity Discovery | ✅ Complete |
| Trust Discovery | ✅ Complete |
| Authorization Discovery | ✅ Complete |
| Correlation Engine | ✅ Complete |
| Governance Engine | 🚧 In Progress |
| Operations Engine | 🚧 In Progress |

---

# Current Capabilities

## Platform

- Engine Registry
- Service Registry
- Configuration Registry
- Validation Framework
- Confidence Framework
- Dashboard Framework

---

## Identity Discovery

- Organization Discovery
- Tenant Discovery
- Domain Discovery
- User Discovery
- Group Discovery
- Licensing Discovery

---

## Trust Discovery

- Conditional Access Policies
- Named Locations
- Authentication Methods
- MFA Registration
- Passwordless Readiness
- SSPR Readiness
- System Preferred Authentication

---

## Authorization Discovery

- Directory Roles
- Privileged Identity Detection
- Service Principal Role Discovery
- Deprecated Role Detection
- Role Assignment Correlation

---

## Correlation

- Identity Graph
- Authentication Correlation
- Authorization Correlation
- Identity Attention Detection
- Confidence Scoring

---

# Example Dashboard

```
==========================================================
                 BLACKKNIGHT ONE
      Enterprise Identity Engineering Platform
==========================================================

Platform
----------------------------------------------------------
Version                  0.5.0-alpha

Registered Engines       6
Platform Services        24
Capabilities             34

Tenant
----------------------------------------------------------
Tenant                   BlackKnight Networking
Users                    10
Groups                   35
Guests                   1

Confidence
----------------------------------------------------------
Identity                 85%
Trust                    75%
Governance               75%
Operations               75%
Validation               98%

Overall Platform Confidence
==========================================================
83.45%
==========================================================

Top Recommendations

• Enable Passwordless Authentication
• Review Deprecated Directory Roles
• Complete Access Package Discovery
• Complete Administrative Unit Discovery
```

---

# Platform Services

Blackknight is built around reusable platform services.

Every engine consumes the same services.

Every dashboard uses the same data.

Every report comes from the same model.

This eliminates duplicate discovery and creates a single source of truth.

---

# Engine Overview

## Identity Engine

Responsible for Microsoft Entra discovery.

Produces:

- Tenant Inventory
- Users
- Groups
- Domains
- Licensing
- Identity Confidence

---

## Trust Engine

Responsible for Zero Trust posture.

Produces:

- Conditional Access
- Named Locations
- MFA
- Passwordless
- Authentication Methods
- Trust Confidence

---

## Governance Engine

Responsible for identity governance.

Current roadmap:

- Access Packages
- Catalogs
- Administrative Units
- Dynamic Groups
- Access Reviews
- Entitlement Management

---

## Operations Engine

Responsible for operational engineering.

Current roadmap:

- Workforce Lifecycle
- License Operations
- Identity Requests
- Partner Operations
- Incident Response

---

## Correlation Engine

The Correlation Engine is the heart of Blackknight One.

Rather than displaying disconnected Microsoft Graph objects, it builds an identity intelligence model.

Current correlations include:

- Users ↔ Authentication
- Users ↔ Directory Roles
- MFA Coverage
- Passwordless Readiness
- Privileged Identity Detection
- Deprecated Role Detection
- Identity Attention Indicators

---

# Identity Intelligence

The long-term vision is to represent every identity as a complete engineering object.

```
Todd Crow

Identity
──────────────────────────────
Enabled
Member
Department: IT

Authentication
──────────────────────────────
MFA ✔
Passwordless ✘
SSPR ✔

Authorization
──────────────────────────────
Global Administrator
Exchange Administrator

Devices
──────────────────────────────
Hybrid Joined
Compliant

Applications
──────────────────────────────
Enterprise Apps

Governance
──────────────────────────────
Access Packages
Administrative Units

Risk
──────────────────────────────
Low

Overall Identity Health
──────────────────────────────
92%
```

---

# Why Blackknight One?

Blackknight One is not another Microsoft Graph script.

It is not another inventory tool.

It is an identity engineering platform.

Every recommendation is explainable.

Every confidence score is measurable.

Every dashboard is generated from correlated data.

The goal is to help engineers understand **why** something matters—not simply that it exists.

---

# Roadmap

## Version 0.5

- Identity Intelligence
- Directory Role Correlation
- Dashboard
- Validation Framework

---

## Version 0.6

- Privileged Identity Management (PIM)
- Administrative Units
- Access Packages
- Catalog Discovery
- Entitlement Management

---

## Version 0.7

- Devices
- Applications
- Enterprise Applications
- Service Principals
- Managed Identities

---

## Version 0.8

- Identity Protection
- Sign-In Analytics
- Risk Detection
- Audit Correlation

---

## Version 0.9

- GDAP Intelligence
- Cross-Tenant Access
- B2B Collaboration
- Multi-Tenant Correlation

---

## Version 1.0

**Identity Engineering Operating System**

---

# Contributing

Blackknight One is built around modular services and reusable engines.

Contributions should:

- Follow existing platform architecture
- Prefer reusable services over duplicate code
- Maintain readable PowerShell
- Preserve One Source of Truth principles
- Include validation and reporting support

---

# Current Version

**0.5.0-alpha**

Current Metrics

- Registered Engines: 6
- Platform Services: 24+
- Capabilities: 34+
- Microsoft Graph Services: Growing
- Validation Framework: Operational
- Dashboard: Operational
- Identity Intelligence: In Active Development

---

## Vision

> **Build the world's most transparent Microsoft identity engineering platform.**

Every engineer should be able to understand **how** their identity environment works, **why** recommendations are made, and **what** to improve next.

That is the purpose of Blackknight One.