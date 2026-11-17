# lz-vending

Subscription vending for an application landing zone: optional subscription alias, management-group placement, network and workload resource groups, spoke VNet with NSGs, a route table to the hub firewall, hub peering (both sides), a budget and app-team RBAC.

## Usage

```hcl
module "lz_vending" {
  source = "../../modules/lz-vending"

  # see Inputs below
}
```

## Resources

- `azurerm_consumption_budget_subscription`
- `azurerm_management_group_subscription_association`
- `azurerm_network_security_group`
- `azurerm_resource_group`
- `azurerm_role_assignment`
- `azurerm_route`
- `azurerm_route_table`
- `azurerm_subnet`
- `azurerm_subnet_network_security_group_association`
- `azurerm_subnet_route_table_association`
- `azurerm_subscription`
- `azurerm_virtual_network`
- `azurerm_virtual_network_peering`

## Inputs

| Name | Description | Required |
|---|---|:---:|
| `location` | Azure region for the landing zone resources. | yes |
| `subscription_id` | GUID of an existing landing zone subscription. Null uses the subscription the default azurerm provider targets. Ignored when subscription_alias_enabled is true. | no |
| `subscription_alias_enabled` | Create a NEW subscription through a subscription alias (requires an EA/MCA billing scope and the matching billing role). Off by default; see the module README for the two-stage workflow. | no |
| `subscription_alias` | Subscription alias settings, required when subscription_alias_enabled is true. `workload` is Production or DevTest. | no |
| `management_group_id` | Resource ID of the management group to place the subscription in (e.g. the corp landing zone group). Null leaves placement unchanged. | no |
| `network_resource_group_name` | Name of the resource group for the spoke VNet, NSGs and route table. | yes |
| `resource_groups` | Additional workload resource groups keyed by a short label (e.g. `aks`, `data`). The key `network` is reserved. | no |
| `virtual_network` | Spoke virtual network. Subnets are keyed by subnet name. - `route_to_firewall` associates the subnet with the route table (when `route_table` is set). - `create_network_security_group` creates an empty NSG (platform default rules only) per subnet; add rules with `azurerm_network_security_rule` using the `network_security_group_ids` output. - `dns_servers` set to the hub firewall private IP when it runs as DNS proxy. | yes |
| `hub_peering` | Peer the spoke with the hub. The hub-side peering is created with the `azurerm.hub` provider when create_hub_side is true. Null disables peering. | no |
| `route_table` | Route table that sends 0.0.0.0/0 to the hub firewall. Null skips the route table. | no |
| `budget` | Monthly subscription budget with e-mail alerts. Null skips the budget. `start_date` defaults to the first day of the current month (RFC 3339). | no |
| `app_team_role_assignments` | RBAC for the application team, keyed by a static label. Scope is the subscription unless `resource_group_key` names `network` or a key of `resource_groups`. Owner, User Access Administrator and Role Based Access Control Administrator are rejected; grant those via the identity module with a documented exception. | no |
| `tags` | Tags applied to all resources (and the subscription when an alias is created). | no |

## Outputs

| Name | Description |
|---|---|
| `subscription_id` | GUID of the landing zone subscription. |
| `subscription_resource_id` | Resource ID (/subscriptions/<guid>) of the landing zone subscription. |
| `network_resource_group_name` | Name of the spoke network resource group. |
| `resource_group_ids` | Map of resource group key (network + resource_groups keys) => resource ID. |
| `resource_group_names` | Map of resource group key => name. |
| `virtual_network_id` | Resource ID of the spoke virtual network. |
| `virtual_network_name` | Name of the spoke virtual network. |
| `subnet_ids` | Map of subnet name => resource ID. Available only after NSG and route table associations exist. |
| `network_security_group_ids` | Map of subnet name => NSG resource ID. |
| `route_table_id` | Resource ID of the spoke route table, or null when disabled. |
| `budget_id` | Resource ID of the subscription budget, or null when disabled. |
| `spoke_to_hub_peering_id` | Resource ID of the spoke-to-hub peering, or null. |
| `hub_to_spoke_peering_id` | Resource ID of the hub-to-spoke peering, or null. |
