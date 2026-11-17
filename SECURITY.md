# Security Policy

## Reporting a vulnerability

Please report security issues privately through GitHub's
[private vulnerability reporting](../../security/advisories/new) rather than in a public issue.

## Using this repository safely

- Never commit real `terraform.tfvars`, `backend.tf` or state files; they are git-ignored.
- Authenticate pipelines with OIDC federated credentials (see `modules/identity`), not client secrets.
- Keep remote state in a storage account with Entra ID authentication and shared-key access disabled.
- Review `terraform plan` output for policy and RBAC changes before applying at management-group scope.
