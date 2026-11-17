# identity

RBAC role assignments and an optional user-assigned managed identity with federated credentials (e.g. GitHub Actions OIDC), so pipelines need no secrets.

## Usage

```hcl
module "identity" {
  source = "../../modules/identity"

  # see Inputs below
}
```

## Resources

- `azurerm_federated_identity_credential`
- `azurerm_role_assignment`
- `azurerm_user_assigned_identity`

## Inputs

| Name | Description | Required |
|---|---|:---:|
| `role_assignments` | Role assignments for existing principals (groups, service principals), keyed by a static label. Set exactly one of `role_definition_name` or `role_definition_id`. Prefer groups over users and set `principal_type` to avoid Entra ID replication delays for newly created principals. | no |
| `user_assigned_identity` | Optional user-assigned managed identity to create (e.g. a deployment identity for GitHub Actions OIDC). Null skips it. | no |
| `user_assigned_identity_role_assignments` | Role assignments for the user-assigned identity, keyed by a static label. Ignored when user_assigned_identity is null. | no |
| `federated_identity_credentials` | Federated credentials for the user-assigned identity, keyed by credential name. Defaults target GitHub Actions OIDC; `subject` examples: `repo:my-org/my-repo:environment:prod`, `repo:my-org/my-repo:ref:refs/heads/main`, `repo:my-org/my-repo:pull_request`. | no |
| `tags` | Tags applied to the user-assigned identity. | no |

## Outputs

| Name | Description |
|---|---|
| `role_assignment_ids` | Map of role assignment key => resource ID. |
| `user_assigned_identity_id` | Resource ID of the user-assigned identity, or null when not created. |
| `user_assigned_identity_client_id` | Client ID of the user-assigned identity (use as AZURE_CLIENT_ID for GitHub Actions OIDC), or null. |
| `user_assigned_identity_principal_id` | Object (principal) ID of the user-assigned identity, or null. |
| `federated_identity_credential_ids` | Map of federated credential name => resource ID. |
