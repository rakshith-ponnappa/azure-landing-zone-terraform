output "resource_group_name" {
  description = "Name of the hub resource group."
  value       = local.resource_group_name
}

output "virtual_network_id" {
  description = "Resource ID of the hub virtual network."
  value       = azurerm_virtual_network.hub.id
}

output "virtual_network_name" {
  description = "Name of the hub virtual network."
  value       = azurerm_virtual_network.hub.name
}

output "subnet_ids" {
  description = "Map of hub subnet name => resource ID (platform and additional subnets)."
  value = merge(
    { for s in azurerm_subnet.firewall : s.name => s.id },
    { for s in azurerm_subnet.bastion : s.name => s.id },
    { for s in azurerm_subnet.gateway : s.name => s.id },
    { for k, s in azurerm_subnet.additional : k => s.id },
  )
}

output "firewall_id" {
  description = "Resource ID of the Azure Firewall, or null when disabled."
  value       = try(azurerm_firewall.this[0].id, null)
}

output "firewall_private_ip" {
  description = "Private IP of the Azure Firewall. Use it as the next hop for spoke default routes and as the spoke DNS server when DNS proxy is enabled."
  value       = try(azurerm_firewall.this[0].ip_configuration[0].private_ip_address, null)
}

output "firewall_public_ip" {
  description = "Public IP address of the Azure Firewall, or null when disabled."
  value       = try(azurerm_public_ip.firewall[0].ip_address, null)
}

output "firewall_policy_id" {
  description = "Resource ID of the firewall policy. Attach additional `azurerm_firewall_policy_rule_collection_group` resources to it."
  value       = try(azurerm_firewall_policy.this[0].id, null)
}

output "bastion_id" {
  description = "Resource ID of Azure Bastion, or null when disabled."
  value       = try(azurerm_bastion_host.this[0].id, null)
}

output "private_dns_zone_ids" {
  description = "Map of private DNS zone name => resource ID."
  value       = { for k, z in azurerm_private_dns_zone.this : k => z.id }
}

output "hub_to_spoke_peering_ids" {
  description = "Map of spoke key => hub-side peering resource ID."
  value       = { for k, p in azurerm_virtual_network_peering.hub_to_spoke : k => p.id }
}
