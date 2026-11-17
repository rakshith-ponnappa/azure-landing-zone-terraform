output "subscription_id" {
  description = "GUID of the landing zone subscription."
  value       = local.subscription_id
}

output "subscription_resource_id" {
  description = "Resource ID (/subscriptions/<guid>) of the landing zone subscription."
  value       = local.subscription_resource_id
}

output "network_resource_group_name" {
  description = "Name of the spoke network resource group."
  value       = azurerm_resource_group.network.name
}

output "resource_group_ids" {
  description = "Map of resource group key (network + resource_groups keys) => resource ID."
  value       = local.resource_group_ids
}

output "resource_group_names" {
  description = "Map of resource group key => name."
  value = merge(
    { network = azurerm_resource_group.network.name },
    { for k, rg in azurerm_resource_group.workload : k => rg.name },
  )
}

output "virtual_network_id" {
  description = "Resource ID of the spoke virtual network."
  value       = azurerm_virtual_network.spoke.id
}

output "virtual_network_name" {
  description = "Name of the spoke virtual network."
  value       = azurerm_virtual_network.spoke.name
}

output "subnet_ids" {
  description = "Map of subnet name => resource ID. Available only after NSG and route table associations exist."
  value       = { for k, s in azurerm_subnet.this : k => s.id }

  depends_on = [
    azurerm_subnet_network_security_group_association.this,
    azurerm_subnet_route_table_association.this,
  ]
}

output "network_security_group_ids" {
  description = "Map of subnet name => NSG resource ID."
  value       = { for k, n in azurerm_network_security_group.this : k => n.id }
}

output "route_table_id" {
  description = "Resource ID of the spoke route table, or null when disabled."
  value       = try(azurerm_route_table.this[0].id, null)
}

output "budget_id" {
  description = "Resource ID of the subscription budget, or null when disabled."
  value       = try(azurerm_consumption_budget_subscription.this[0].id, null)
}

output "spoke_to_hub_peering_id" {
  description = "Resource ID of the spoke-to-hub peering, or null."
  value       = try(azurerm_virtual_network_peering.spoke_to_hub[0].id, null)
}

output "hub_to_spoke_peering_id" {
  description = "Resource ID of the hub-to-spoke peering, or null."
  value       = try(azurerm_virtual_network_peering.hub_to_spoke[0].id, null)
}
