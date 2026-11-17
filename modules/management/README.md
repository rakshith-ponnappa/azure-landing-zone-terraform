# management

Central Log Analytics workspace (optionally with an Automation account) and a helper to attach diagnostic settings to any resource.

## Usage

```hcl
module "management" {
  source = "../../modules/management"

  # see Inputs below
}
```

## Resources

- `azurerm_automation_account`
- `azurerm_log_analytics_linked_service`
- `azurerm_log_analytics_workspace`
- `azurerm_monitor_diagnostic_setting`
- `azurerm_resource_group`

## Inputs

| Name | Description | Required |
|---|---|:---:|
| `location` | Azure region for the management resources. | yes |
| `resource_group_name` | Name of the resource group that holds the management resources. | yes |
| `create_resource_group` | Create the resource group. Set to false to deploy into an existing resource group. | no |
| `log_analytics_workspace_name` | Name of the central Log Analytics workspace. | yes |
| `log_analytics_sku` | Log Analytics workspace SKU. | no |
| `retention_in_days` | Interactive retention for the workspace in days. | no |
| `daily_quota_gb` | Daily ingestion cap in GB. -1 means unlimited. | no |
| `enable_automation_account` | Deploy an Automation account linked to the workspace (e.g. for runbooks). Disabled by default. | no |
| `automation_account_name` | Name of the Automation account. Required when enable_automation_account is true. | no |
| `diagnostic_settings` | Diagnostic settings helper. Map of arbitrary static key => settings that send logs/metrics from `target_resource_id` to the central workspace. - `log_category_groups` defaults to ["allLogs"]; ignored when `log_categories` is set. - `log_categories` explicit categories (required for targets such as subscription activity logs). - `metric_categories` defaults to ["AllMetrics"]; set [] for targets without metrics. - `destination_type` "Dedicated" (resource-specific tables) or "AzureDiagnostics". | no |
| `tags` | Tags applied to all resources. | no |

## Outputs

| Name | Description |
|---|---|
| `resource_group_name` | Name of the management resource group. |
| `log_analytics_workspace_id` | Resource ID of the central Log Analytics workspace. |
| `log_analytics_workspace_name` | Name of the central Log Analytics workspace. |
| `log_analytics_workspace_customer_id` | Workspace (customer) GUID, used by agents and some integrations. |
| `automation_account_id` | Resource ID of the Automation account, or null when disabled. |
| `diagnostic_setting_ids` | Map of diagnostic setting key => resource ID. |
