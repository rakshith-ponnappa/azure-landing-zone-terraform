resource "azurerm_resource_group" "this" {
  count = var.create_resource_group ? 1 : 0

  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

data "azurerm_resource_group" "existing" {
  count = var.create_resource_group ? 0 : 1

  name = var.resource_group_name
}

locals {
  resource_group_name = var.create_resource_group ? azurerm_resource_group.this[0].name : data.azurerm_resource_group.existing[0].name
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = var.log_analytics_workspace_name
  location            = var.location
  resource_group_name = local.resource_group_name
  sku                 = var.log_analytics_sku
  retention_in_days   = var.retention_in_days
  daily_quota_gb      = var.daily_quota_gb

  # Force Entra ID auth for ingestion/query; shared keys are disabled.
  local_authentication_enabled = false
  # Users can only see logs for resources they have access to.
  allow_resource_only_permissions = true

  tags = var.tags
}

resource "azurerm_automation_account" "this" {
  count = var.enable_automation_account ? 1 : 0

  name                          = var.automation_account_name
  location                      = var.location
  resource_group_name           = local.resource_group_name
  sku_name                      = "Basic"
  local_authentication_enabled  = false
  public_network_access_enabled = false

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags

  lifecycle {
    precondition {
      condition     = var.automation_account_name != null
      error_message = "automation_account_name must be set when enable_automation_account is true."
    }
  }
}

resource "azurerm_log_analytics_linked_service" "automation" {
  count = var.enable_automation_account ? 1 : 0

  resource_group_name = local.resource_group_name
  workspace_id        = azurerm_log_analytics_workspace.this.id
  read_access_id      = azurerm_automation_account.this[0].id
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  for_each = var.diagnostic_settings

  name                           = each.value.name
  target_resource_id             = each.value.target_resource_id
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.this.id
  log_analytics_destination_type = each.value.destination_type

  dynamic "enabled_log" {
    for_each = each.value.log_categories != null ? toset(each.value.log_categories) : toset([])
    content {
      category = enabled_log.value
    }
  }

  dynamic "enabled_log" {
    for_each = each.value.log_categories == null ? toset(each.value.log_category_groups) : toset([])
    content {
      category_group = enabled_log.value
    }
  }

  dynamic "enabled_metric" {
    for_each = toset(each.value.metric_categories)
    content {
      category = enabled_metric.value
    }
  }
}
