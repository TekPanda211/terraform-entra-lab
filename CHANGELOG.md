# Changelog

All notable changes to this project will be documented in this file.

## [v0.2.0] - 2026-07-07

### Added

- Environment-based naming model
- `terraform.tfvars` support
- Stable Terraform `for_each` keys
- Role-assignable Microsoft Entra ID groups
- Privileged group framework

### Infrastructure

- 3 role-assignable Microsoft Entra ID groups deployed

### Updated

- Group naming convention to support environment-based deployments
- Terraform group resource design

---

## [v0.1.0] - 2026-07-07

### Added

- Initial Terraform project structure
- Microsoft Entra ID provider configuration
- Azure CLI authentication
- Modular Terraform configuration
- Department-based security groups
- Dynamic resource creation using `for_each`
- IAM engineering documentation
- GitHub repository
- Terraform deployment to Microsoft Entra ID

### Infrastructure

- 27 Microsoft Entra ID security groups deployed

### Documentation

- Terraform Workflow
- IAM Audit Strategy
- Conditional Access Design
- Access Packages Design
- Security Checks
- Project Roadmap