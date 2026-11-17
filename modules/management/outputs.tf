output "resource_group_name" {
  description = "Name of the management resource group."
  value       = local.resource_group_name
}

output "log_analytics_workspace_id" {
  description = "Resource ID of the central Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.this.id
}

output "log_analytics_workspace_name" {
  description = "Name of the central Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.this.name
}

output "log_analytics_workspace_customer_id" {
  description = "Workspace (customer) GUID, used by agents and some integrations."
  value       = azurerm_log_analytics_workspace.this.workspace_id
}

output "automation_account_id" {
  description = "Resource ID of the Automation account, or null when disabled."
  value       = try(azurerm_automation_account.this[0].id, null)
}

output "diagnostic_setting_ids" {
  description = "Map of diagnostic setting key => resource ID."
  value       = { for k, v in azurerm_monitor_diagnostic_setting.this : k => v.id }
}
