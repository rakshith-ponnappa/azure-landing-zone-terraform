locals {
  custom_private_dns_zone = var.private_cluster.enabled && !contains(["System", "None"], var.private_cluster.private_dns_zone_id)
  network_role_scopes     = toset(concat([var.subnet_id], var.network_role_scope_ids))
}

# A user-assigned control-plane identity is required for custom private DNS zones and BYO route
# tables, and lets the role assignments exist before the cluster is created.
resource "azurerm_user_assigned_identity" "cluster" {
  name                = "id-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_role_assignment" "network" {
  for_each = local.network_role_scopes

  scope                = each.value
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.cluster.principal_id
}

resource "azurerm_role_assignment" "private_dns_zone" {
  count = local.custom_private_dns_zone ? 1 : 0

  scope                = var.private_cluster.private_dns_zone_id
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.cluster.principal_id
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  node_resource_group = var.node_resource_group_name
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier

  dns_prefix_private_cluster          = var.private_cluster.enabled ? var.name : null
  dns_prefix                          = var.private_cluster.enabled ? null : var.name
  private_cluster_enabled             = var.private_cluster.enabled
  private_dns_zone_id                 = var.private_cluster.enabled ? var.private_cluster.private_dns_zone_id : null
  private_cluster_public_fqdn_enabled = var.private_cluster.enabled ? var.private_cluster.public_fqdn_enabled : false

  # Identity and access: Entra ID only, no static kubeconfig credentials.
  local_account_disabled            = true
  role_based_access_control_enabled = true
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true
  azure_policy_enabled              = true

  automatic_upgrade_channel = var.automatic_upgrade_channel
  node_os_upgrade_channel   = var.node_os_upgrade_channel

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.cluster.id]
  }

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled     = true
    admin_group_object_ids = var.admin_group_object_ids
  }

  default_node_pool {
    name                         = var.system_node_pool.name
    vm_size                      = var.system_node_pool.vm_size
    vnet_subnet_id               = var.subnet_id
    zones                        = var.system_node_pool.zones
    auto_scaling_enabled         = true
    min_count                    = var.system_node_pool.min_count
    max_count                    = var.system_node_pool.max_count
    max_pods                     = var.system_node_pool.max_pods
    only_critical_addons_enabled = true
    os_sku                       = "AzureLinux"
    temporary_name_for_rotation  = "tmpsystem"
    tags                         = var.tags

    upgrade_settings {
      max_surge = "33%"
    }
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = var.network.network_data_plane
    network_policy      = var.network.network_policy
    pod_cidr            = var.network.pod_cidr
    service_cidr        = var.network.service_cidr
    dns_service_ip      = var.network.dns_service_ip
    outbound_type       = var.network.outbound_type
    load_balancer_sku   = "standard"
  }

  dynamic "oms_agent" {
    for_each = var.log_analytics_workspace_id == null ? [] : [var.log_analytics_workspace_id]
    content {
      log_analytics_workspace_id      = oms_agent.value
      msi_auth_for_monitoring_enabled = true
    }
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [
      # Managed by the cluster autoscaler.
      default_node_pool[0].node_count,
      kubernetes_version,
    ]
  }

  depends_on = [
    azurerm_role_assignment.network,
    azurerm_role_assignment.private_dns_zone,
  ]
}

resource "azurerm_kubernetes_cluster_node_pool" "user" {
  for_each = var.user_node_pools

  name                  = each.key
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  mode                  = "User"
  vm_size               = each.value.vm_size
  vnet_subnet_id        = var.subnet_id
  zones                 = each.value.zones
  auto_scaling_enabled  = true
  min_count             = each.value.min_count
  max_count             = each.value.max_count
  max_pods              = each.value.max_pods
  os_sku                = each.value.os_sku
  node_labels           = each.value.node_labels
  node_taints           = each.value.node_taints
  tags                  = var.tags

  upgrade_settings {
    max_surge = "33%"
  }

  lifecycle {
    ignore_changes = [node_count]
  }
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  count = var.log_analytics_workspace_id == null ? 0 : 1

  name                           = "diag-${var.name}"
  target_resource_id             = azurerm_kubernetes_cluster.this.id
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  log_analytics_destination_type = "Dedicated"

  dynamic "enabled_log" {
    for_each = toset(var.diagnostic_log_categories)
    content {
      category = enabled_log.value
    }
  }
}
