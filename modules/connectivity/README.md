# connectivity

Hub network: hub VNet, optional Azure Firewall (with an AKS egress rule set) and Azure Bastion, central private DNS zones, hub-side peerings and diagnostics.

## Usage

```hcl
module "connectivity" {
  source = "../../modules/connectivity"

  # see Inputs below
}
```

## Resources

- `azurerm_bastion_host`
- `azurerm_firewall`
- `azurerm_firewall_policy`
- `azurerm_firewall_policy_rule_collection_group`
- `azurerm_monitor_diagnostic_setting`
- `azurerm_private_dns_zone`
- `azurerm_private_dns_zone_virtual_network_link`
- `azurerm_public_ip`
- `azurerm_resource_group`
- `azurerm_subnet`
- `azurerm_virtual_network`
- `azurerm_virtual_network_peering`

## Inputs

| Name | Description | Required |
|---|---|:---:|
| `location` | Azure region for the hub network. | yes |
| `resource_group_name` | Name of the resource group that holds the hub network resources. | yes |
| `create_resource_group` | Create the resource group. Set to false to deploy into an existing resource group. | no |
| `virtual_network_name` | Name of the hub virtual network. | yes |
| `address_space` | Address space(s) of the hub virtual network, e.g. ["10.0.0.0/22"]. | yes |
| `dns_servers` | Custom DNS servers for the hub virtual network. Empty list keeps Azure-provided DNS (recommended when the firewall acts as DNS proxy). | no |
| `ddos_protection_plan_id` | Optional resource ID of an existing DDoS Network Protection plan to attach to the hub virtual network. | no |
| `gateway_subnet_address_prefix` | Optional CIDR for `GatewaySubnet` (/27 or larger). Reserves space for a VPN/ExpressRoute gateway; the gateway itself is out of scope. | no |
| `subnets` | Additional hub subnets keyed by subnet name (e.g. shared private endpoints or DNS resolver). Default outbound access is disabled on these subnets. | no |
| `firewall` | Azure Firewall configuration. Set to null to deploy the hub without a firewall. - `subnet_address_prefix` CIDR for `AzureFirewallSubnet` (/26 recommended). - `sku_tier` Standard or Premium (Premium enables IDPS in Deny mode on the policy). - `aks_egress_source_addresses` when non-empty, adds a rule collection group that allows the minimum egress an AKS cluster with Container Insights and the Azure Policy add-on needs. | no |
| `bastion` | Azure Bastion configuration. Set to null to skip Bastion. `subnet_address_prefix` is the CIDR for `AzureBastionSubnet` (/26 or larger). | no |
| `private_dns_zones` | Private DNS zones to create and link to the hub virtual network (for Private Link and private AKS API servers). | no |
| `spoke_peerings` | Hub-side peerings to spokes that are NOT vended by the lz-vending module (which creates its own hub-side peering). Keyed by a short spoke name. | no |
| `enable_diagnostics` | Send hub VNet, firewall and bastion diagnostics to `log_analytics_workspace_id`. | no |
| `log_analytics_workspace_id` | Resource ID of the Log Analytics workspace used when enable_diagnostics is true. | no |
| `tags` | Tags applied to all resources. | no |

## Outputs

| Name | Description |
|---|---|
| `resource_group_name` | Name of the hub resource group. |
| `virtual_network_id` | Resource ID of the hub virtual network. |
| `virtual_network_name` | Name of the hub virtual network. |
| `subnet_ids` | Map of hub subnet name => resource ID (platform and additional subnets). |
| `firewall_id` | Resource ID of the Azure Firewall, or null when disabled. |
| `firewall_private_ip` | Private IP of the Azure Firewall. Use it as the next hop for spoke default routes and as the spoke DNS server when DNS proxy is enabled. |
| `firewall_public_ip` | Public IP address of the Azure Firewall, or null when disabled. |
| `firewall_policy_id` | Resource ID of the firewall policy. Attach additional `azurerm_firewall_policy_rule_collection_group` resources to it. |
| `bastion_id` | Resource ID of Azure Bastion, or null when disabled. |
| `private_dns_zone_ids` | Map of private DNS zone name => resource ID. |
| `hub_to_spoke_peering_ids` | Map of spoke key => hub-side peering resource ID. |
