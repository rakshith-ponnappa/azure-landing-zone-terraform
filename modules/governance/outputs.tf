output "root_management_group_id" {
  description = "Resource ID of the intermediate root management group."
  value       = azurerm_management_group.root.id
}

output "management_group_ids" {
  description = "Map of management group key (root, platform, landing_zones, sandbox, decommissioned and child names) => resource ID."
  value       = local.management_group_ids
}

output "management_group_names" {
  description = "Map of management group key => management group name."
  value = merge(
    { root = azurerm_management_group.root.name },
    { for k, mg in azurerm_management_group.top : k => mg.name },
    { for k, mg in azurerm_management_group.child : k => mg.name },
  )
}

output "policy_assignment_ids" {
  description = "Map of policy assignment label => resource ID."
  value = merge(
    {
      allowed_locations    = azurerm_management_group_policy_assignment.allowed_locations.id
      allowed_locations_rg = azurerm_management_group_policy_assignment.allowed_locations_rg.id
    },
    { for k, a in azurerm_management_group_policy_assignment.require_rg_tag : "require_rg_tag:${k}" => a.id },
    { for k, a in azurerm_management_group_policy_assignment.inherit_rg_tag : "inherit_rg_tag:${k}" => a.id },
    { for k, a in azurerm_management_group_policy_assignment.deny_public_ip : "deny_public_ip:${k}" => a.id },
    { for k, a in azurerm_management_group_policy_assignment.deny_nic_public_ip : "deny_nic_public_ip:${k}" => a.id },
  )
}
