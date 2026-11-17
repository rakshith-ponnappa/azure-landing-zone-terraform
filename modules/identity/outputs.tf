output "role_assignment_ids" {
  description = "Map of role assignment key => resource ID."
  value       = { for k, r in azurerm_role_assignment.this : k => r.id }
}

output "user_assigned_identity_id" {
  description = "Resource ID of the user-assigned identity, or null when not created."
  value       = try(azurerm_user_assigned_identity.this[0].id, null)
}

output "user_assigned_identity_client_id" {
  description = "Client ID of the user-assigned identity (use as AZURE_CLIENT_ID for GitHub Actions OIDC), or null."
  value       = try(azurerm_user_assigned_identity.this[0].client_id, null)
}

output "user_assigned_identity_principal_id" {
  description = "Object (principal) ID of the user-assigned identity, or null."
  value       = try(azurerm_user_assigned_identity.this[0].principal_id, null)
}

output "federated_identity_credential_ids" {
  description = "Map of federated credential name => resource ID."
  value       = { for k, c in azurerm_federated_identity_credential.this : k => c.id }
}
