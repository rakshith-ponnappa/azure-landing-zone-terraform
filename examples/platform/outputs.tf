output "management_group_ids" {
  description = "Management group IDs keyed by name."
  value       = module.governance.management_group_ids
}

output "log_analytics_workspace_id" {
  description = "Central Log Analytics workspace."
  value       = module.management.log_analytics_workspace_id
}

output "hub_virtual_network_id" {
  description = "Hub VNet ID (input to landing zones)."
  value       = module.connectivity.virtual_network_id
}

output "firewall_private_ip" {
  description = "Firewall private IP (next hop for spoke route tables)."
  value       = module.connectivity.firewall_private_ip
}

output "private_dns_zone_ids" {
  description = "Central private DNS zone IDs keyed by zone name."
  value       = module.connectivity.private_dns_zone_ids
}

output "deploy_identity_client_id" {
  description = "Client ID for the GitHub Actions OIDC login (AZURE_CLIENT_ID)."
  value       = module.deploy_identity.user_assigned_identity_client_id
}
