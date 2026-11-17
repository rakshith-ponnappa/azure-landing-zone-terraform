variable "location" {
  description = "Azure region for the management resources."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group that holds the management resources."
  type        = string
}

variable "create_resource_group" {
  description = "Create the resource group. Set to false to deploy into an existing resource group."
  type        = bool
  default     = true
}

variable "log_analytics_workspace_name" {
  description = "Name of the central Log Analytics workspace."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9-]{2,61}[A-Za-z0-9]$", var.log_analytics_workspace_name))
    error_message = "Workspace name must be 4-63 characters of letters, digits and hyphens, starting and ending alphanumeric."
  }
}

variable "log_analytics_sku" {
  description = "Log Analytics workspace SKU."
  type        = string
  default     = "PerGB2018"

  validation {
    condition     = contains(["PerGB2018", "CapacityReservation"], var.log_analytics_sku)
    error_message = "log_analytics_sku must be PerGB2018 or CapacityReservation."
  }
}

variable "retention_in_days" {
  description = "Interactive retention for the workspace in days."
  type        = number
  default     = 90

  validation {
    condition     = var.retention_in_days >= 30 && var.retention_in_days <= 730
    error_message = "retention_in_days must be between 30 and 730."
  }
}

variable "daily_quota_gb" {
  description = "Daily ingestion cap in GB. -1 means unlimited."
  type        = number
  default     = -1

  validation {
    condition     = var.daily_quota_gb == -1 || var.daily_quota_gb > 0
    error_message = "daily_quota_gb must be -1 (unlimited) or a positive number."
  }
}

variable "enable_automation_account" {
  description = "Deploy an Automation account linked to the workspace (e.g. for runbooks). Disabled by default."
  type        = bool
  default     = false
}

variable "automation_account_name" {
  description = "Name of the Automation account. Required when enable_automation_account is true."
  type        = string
  default     = null
}

variable "diagnostic_settings" {
  description = <<-EOT
    Diagnostic settings helper. Map of arbitrary static key => settings that send logs/metrics from
    `target_resource_id` to the central workspace.
    - `log_category_groups` defaults to ["allLogs"]; ignored when `log_categories` is set.
    - `log_categories` explicit categories (required for targets such as subscription activity logs).
    - `metric_categories` defaults to ["AllMetrics"]; set [] for targets without metrics.
    - `destination_type` "Dedicated" (resource-specific tables) or "AzureDiagnostics".
  EOT
  type = map(object({
    target_resource_id  = string
    name                = optional(string, "send-to-law")
    log_categories      = optional(list(string))
    log_category_groups = optional(list(string), ["allLogs"])
    metric_categories   = optional(list(string), ["AllMetrics"])
    destination_type    = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for d in values(var.diagnostic_settings) : d.destination_type == null ? true : contains(["Dedicated", "AzureDiagnostics"], d.destination_type)
    ])
    error_message = "destination_type must be Dedicated, AzureDiagnostics or null."
  }
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
