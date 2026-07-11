\# Platform Overview



> \*\*Estimated time:\*\* 15–20 minutes  

> \*\*Audience:\*\* Identity Engineers, Security Architects, Microsoft Partners, IT Professionals, and Platform Engineers



> \[!NOTE]

> Blackknight One is currently in \*\*v0.5.0-alpha\*\*. Features, architecture, and documentation continue to evolve as the platform matures. Community feedback and contributions are encouraged through the GitHub repository.



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



Enterprise identity has become one of the most critical components of modern IT infrastructure.



Organizations no longer manage identities solely through graphical administration portals. Identity is increasingly engineered through automation, Infrastructure as Code (IaC), Continuous Integration and Continuous Delivery (CI/CD), policy validation, and Microsoft Graph.



Blackknight One was created to help organizations engineer identity with the same rigor traditionally applied to infrastructure and software.



Rather than functioning as another reporting tool, Blackknight One is designed as an \*\*Enterprise Identity Engineering Platform\*\*.



Our vision is simple:



> \*\*One Source of Truth for Enterprise Identity Engineering\*\*



\---



\# The Challenge



Modern Microsoft Entra environments contain thousands of interconnected objects.



Examples include:



\- Users

\- Groups

\- Devices

\- Service Principals

\- Applications

\- Administrative Roles

\- Conditional Access Policies

\- Authentication Methods

\- Licensing

\- Identity Governance

\- Terraform Configurations

\- CI/CD Pipelines



Each workload exposes valuable information, but that information is fragmented across multiple services and administrative experiences.



Engineers frequently ask questions such as:



\- Which Global Administrators are protected by MFA?

\- Which Conditional Access policies protect privileged identities?

\- What changed since yesterday?

\- Is our Terraform deployment safe?

\- Will this configuration reduce our security posture?

\- How confident are we in our identity platform?



Traditional administrative tools rarely answer these questions holistically.



\---



\# The Blackknight One Approach



Blackknight One approaches identity as an engineering discipline rather than a collection of administrative tasks.



Instead of collecting isolated information, the platform continuously:



1\. Discovers

2\. Correlates

3\. Validates

4\. Understands

5\. Automates



These five engineering pillars define every capability within Blackknight One.



\---



\# The Five Engineering Pillars



\## Discover



Understand the current state of the environment.



Examples include:



\- Tenant Discovery

\- User Inventory

\- Group Inventory

\- Licensing

\- Conditional Access

\- Directory Roles

\- Authentication Methods

\- Terraform Configuration Discovery



\---



\## Correlate



Relationships create intelligence.



Blackknight One correlates information across multiple workloads to answer questions that individual Microsoft services cannot answer independently.



Examples include:



\- User ↔ Authentication

\- User ↔ Directory Role

\- User ↔ License

\- Group ↔ Role

\- Service Principal ↔ Permission

\- Identity ↔ Conditional Access

\- Terraform ↔ Microsoft Graph



\---



\## Validate



Engineering requires validation.



Blackknight One continuously validates:



\- Platform health

\- Configuration

\- Identity posture

\- Security posture

\- Zero Trust maturity

\- Terraform deployments

\- CI/CD changes



Validation reduces operational risk before changes reach production.



\---



\## Understand



Collected information becomes useful only when transformed into actionable intelligence.



Blackknight One produces:



\- Confidence Scores

\- Identity Intelligence

\- Recommendations

\- Drift Detection

\- Risk Indicators

\- Engineering Insights



The objective is to help engineers understand \*why\* something matters—not simply report that it exists.



\---



\## Automate



Modern identity platforms are engineered through automation.



Blackknight One is designed to integrate with:



\- PowerShell

\- Microsoft Graph

\- Terraform

\- GitHub Actions

\- Azure DevOps

\- Power BI

\- Microsoft Sentinel

\- REST APIs (planned)



Automation enables repeatable, validated identity engineering workflows.



\---



\# Platform Workflow



A typical assessment follows this sequence.



```text

Discover

&#x20;     │

&#x20;     ▼

Correlate

&#x20;     │

&#x20;     ▼

Validate

&#x20;     │

&#x20;     ▼

Understand

&#x20;     │

&#x20;     ▼

Automate

```



Every engine contributes to one or more stages of this workflow.



\---



\# Platform Components



Blackknight One consists of several major components.



\## Platform



Provides the common foundation for:



\- Configuration

\- Services

\- Registry

\- Validation

\- Reporting



\---



\## Discovery Services



Reusable Microsoft Graph collection services.



Examples include:



\- Users

\- Groups

\- Domains

\- Licensing

\- Conditional Access

\- Authentication Methods



Discovery services avoid duplicate Graph queries across engines.



\---



\## Assessment Engines



Assessment engines analyze collected information.



Current engines include:



\- Identity

\- Trust

\- Correlation

\- Governance (planned)

\- Operations (planned)

\- Validation

\- Terraform (planned)



Each engine produces standardized output.



\---



\## Correlation Engine



The Correlation Engine combines information from multiple discovery services into a unified operational model.



Examples include:



\- Identity Graph

\- Administrative Exposure

\- Authentication Readiness

\- Privileged Access

\- Role Assignments



Correlation transforms inventory into intelligence.



\---



\## Confidence Engine



Confidence scores summarize engineering maturity.



Current scoring domains include:



\- Identity

\- Trust

\- Governance

\- Operations

\- Validation



Future versions will introduce additional domains including Terraform and CI/CD.



\---



\## Dashboard



The operational dashboard provides a consolidated view of:



\- Platform Health

\- Tenant Summary

\- Confidence Scores

\- Recommendations

\- Engine Status



The dashboard serves as the primary operational interface for Blackknight One.



\---



\# Current Capabilities



Current platform capabilities include:



\- Microsoft Graph Discovery

\- Identity Inventory

\- Group Inventory

\- Licensing Inventory

\- Conditional Access Discovery

\- Authentication Method Analysis

\- Directory Role Analysis

\- Identity Correlation

\- Trust Assessment

\- Confidence Scoring

\- JSON Reporting

\- Platform Validation



\---



\# Future Vision



Blackknight One is evolving beyond identity discovery.



Future capabilities include:



\## Identity Engineering



\- Application Discovery

\- Service Principal Analysis

\- Device Inventory

\- Privileged Identity Management

\- Identity Governance

\- Access Reviews

\- Entitlement Management



\---



\## Infrastructure as Code



\- Terraform State Analysis

\- Terraform Plan Validation

\- Drift Detection

\- Identity as Code Validation



\---



\## DevSecOps



\- GitHub Actions

\- Azure DevOps

\- Pull Request Validation

\- CI/CD Confidence Gates

\- Automated Security Validation



\---



\## Intelligence



\- Historical Trending

\- Machine-Assisted Recommendations

\- Risk Modeling

\- Executive Dashboards

\- Power BI Integration



\---



\# Design Principles



Blackknight One follows several guiding principles.



\- Modular

\- Reusable

\- Observable

\- Testable

\- Extensible

\- Engineering First

\- Graph Native

\- Infrastructure as Code Ready



Every new capability should reinforce these principles.



\---



\# Roadmap



Future releases will continue expanding the platform through:



\- Additional assessment engines

\- Terraform integration

\- Plugin architecture

\- REST API

\- Multi-tenant assessments

\- GDAP optimization

\- Identity as Code

\- Continuous validation



\---



\# Related Documentation



Continue with:



\- Platform Architecture

\- Command Reference

\- Identity Engine

\- Trust Engine

\- Correlation Engine

\- Terraform Engine



\---



\## About Blackknight One



Blackknight One is an open-source Enterprise Identity Engineering Platform designed to help organizations discover, correlate, validate, understand, and automate Microsoft Entra environments.



Its long-term objective is to become the industry's most comprehensive engineering platform for Microsoft identity, Infrastructure as Code, and Zero Trust.

