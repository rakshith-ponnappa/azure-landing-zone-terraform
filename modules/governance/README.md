# governance

Management-group hierarchy (root → platform / landing zones / sandbox / decommissioned, with CAF child groups) plus built-in policy assignments: allowed locations, required tags with inheritance, and deny public IPs.

## Usage

```hcl
module "governance" {
  source = "../../modules/governance"

  # see Inputs below
}
```

## Resources

- `azurerm_management_group`
- `azurerm_management_group_policy_assignment`
- `azurerm_management_group_subscription_association`
- `azurerm_role_assignment`

## Inputs

| Name | Description | Required |
|---|---|:---:|
| `root_id` | Short ID for the intermediate root management group. Child groups are named `<root_id>-<group>`. | yes |
| `root_display_name` | Display name of the intermediate root management group. | yes |
| `root_parent_management_group_id` | Resource ID of the parent for the intermediate root. Null places it under the tenant root group. | no |
| `platform_child_groups` | Child management groups created under Platform. | no |
| `landing_zone_child_groups` | Child management groups created under Landing Zones (CAF archetypes such as corp and online). | no |
| `subscription_placement` | Existing subscriptions to move into the hierarchy, keyed by a friendly name. `management_group` is a key from the `management_group_ids` output: root, platform, landing_zones, sandbox, decommissioned, or any child group name. Do not also place the same subscription with lz-vending. | no |
| `allowed_locations` | Regions where resources and resource groups may be deployed. Enforced at the intermediate root. | yes |
| `mandatory_tag_names` | Tag names that every resource group must carry. Pass the tagging module's `mandatory_tag_names` output. | no |
| `inherit_tags_from_resource_group` | Also assign a Modify policy per mandatory tag so resources inherit the tag from their resource group when missing. Creates a system-assigned identity per assignment with Tag Contributor at the root. | no |
| `deny_public_ip_management_groups` | Management group keys where public IP addresses and NICs with public IPs are denied. Defaults to the corp archetype. | no |
| `policy_enforcement_enabled` | Set to false to create all assignments with enforcement mode DoNotEnforce (audit-first rollout). | no |
| `policy_identity_location` | Region for the managed identities of Modify/DeployIfNotExists policy assignments. Required when inherit_tags_from_resource_group is true. | no |

## Outputs

| Name | Description |
|---|---|
| `root_management_group_id` | Resource ID of the intermediate root management group. |
| `management_group_ids` | Map of management group key (root, platform, landing_zones, sandbox, decommissioned and child names) => resource ID. |
| `management_group_names` | Map of management group key => management group name. |
| `policy_assignment_ids` | Map of policy assignment label => resource ID. |
