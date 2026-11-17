resource "azurerm_resource_group" "this" {
  count = var.create_resource_group ? 1 : 0

  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

locals {
  resource_group_name = var.create_resource_group ? azurerm_resource_group.this[0].name : var.resource_group_name
  firewall_enabled    = var.firewall != null
  bastion_enabled     = var.bastion != null
  aks_egress_enabled  = local.firewall_enabled ? length(var.firewall.aks_egress_source_addresses) > 0 : false
}

resource "azurerm_virtual_network" "hub" {
  name                = var.virtual_network_name
  location            = var.location
  resource_group_name = local.resource_group_name
  address_space       = var.address_space
  dns_servers         = var.dns_servers

  dynamic "ddos_protection_plan" {
    for_each = var.ddos_protection_plan_id != null ? [var.ddos_protection_plan_id] : []
    content {
      id     = ddos_protection_plan.value
      enable = true
    }
  }

  tags = var.tags
}

# Platform subnets use the fixed names Azure requires.
resource "azurerm_subnet" "firewall" {
  count = local.firewall_enabled ? 1 : 0

  name                 = "AzureFirewallSubnet"
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.firewall.subnet_address_prefix]
}

resource "azurerm_subnet" "bastion" {
  count = local.bastion_enabled ? 1 : 0

  name                 = "AzureBastionSubnet"
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.bastion.subnet_address_prefix]
}

resource "azurerm_subnet" "gateway" {
  count = var.gateway_subnet_address_prefix != null ? 1 : 0

  name                 = "GatewaySubnet"
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.gateway_subnet_address_prefix]
}

resource "azurerm_subnet" "additional" {
  for_each = var.subnets

  name                              = each.key
  resource_group_name               = local.resource_group_name
  virtual_network_name              = azurerm_virtual_network.hub.name
  address_prefixes                  = each.value.address_prefixes
  service_endpoints                 = each.value.service_endpoints
  private_endpoint_network_policies = each.value.private_endpoint_network_policies
  default_outbound_access_enabled   = false
}

# ---------------------------------------------------------------------------
# Azure Firewall
# ---------------------------------------------------------------------------
resource "azurerm_public_ip" "firewall" {
  count = local.firewall_enabled ? 1 : 0

  name                = var.firewall.public_ip_name
  location            = var.location
  resource_group_name = local.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.firewall.zones
  tags                = var.tags
}

resource "azurerm_firewall_policy" "this" {
  count = local.firewall_enabled ? 1 : 0

  name                     = var.firewall.policy_name
  location                 = var.location
  resource_group_name      = local.resource_group_name
  sku                      = var.firewall.sku_tier
  threat_intelligence_mode = var.firewall.threat_intelligence_mode

  dns {
    proxy_enabled = var.firewall.dns_proxy_enabled
    servers       = length(var.firewall.dns_servers) > 0 ? var.firewall.dns_servers : null
  }

  dynamic "intrusion_detection" {
    for_each = var.firewall.sku_tier == "Premium" ? [1] : []
    content {
      mode = "Deny"
    }
  }

  tags = var.tags
}

resource "azurerm_firewall" "this" {
  count = local.firewall_enabled ? 1 : 0

  name                = var.firewall.name
  location            = var.location
  resource_group_name = local.resource_group_name
  sku_name            = "AZFW_VNet"
  sku_tier            = var.firewall.sku_tier
  firewall_policy_id  = azurerm_firewall_policy.this[0].id
  zones               = var.firewall.zones

  ip_configuration {
    name                 = "ipconfig-primary"
    subnet_id            = azurerm_subnet.firewall[0].id
    public_ip_address_id = azurerm_public_ip.firewall[0].id
  }

  tags = var.tags
}

# Minimum egress for a private AKS cluster that routes 0.0.0.0/0 through the firewall.
# Review against the current "Outbound network and FQDN rules for AKS clusters" documentation.
resource "azurerm_firewall_policy_rule_collection_group" "aks_egress" {
  count = local.aks_egress_enabled ? 1 : 0

  name               = "rcg-aks-egress"
  firewall_policy_id = azurerm_firewall_policy.this[0].id
  priority           = 500

  network_rule_collection {
    name     = "aks-network"
    priority = 100
    action   = "Allow"

    rule {
      name                  = "ntp"
      protocols             = ["UDP"]
      source_addresses      = var.firewall.aks_egress_source_addresses
      destination_addresses = ["*"]
      destination_ports     = ["123"]
    }

    rule {
      name                  = "azure-monitor"
      protocols             = ["TCP"]
      source_addresses      = var.firewall.aks_egress_source_addresses
      destination_addresses = ["AzureMonitor"]
      destination_ports     = ["443"]
    }
  }

  application_rule_collection {
    name     = "aks-application"
    priority = 200
    action   = "Allow"

    rule {
      name                  = "aks-fqdn-tag"
      source_addresses      = var.firewall.aks_egress_source_addresses
      destination_fqdn_tags = ["AzureKubernetesService"]

      protocols {
        type = "Https"
        port = 443
      }
      protocols {
        type = "Http"
        port = 80
      }
    }

    rule {
      name             = "aks-addons"
      source_addresses = var.firewall.aks_egress_source_addresses
      destination_fqdns = [
        "data.policy.core.windows.net",
        "store.policy.core.windows.net",
        "dc.services.visualstudio.com",
        "*.ods.opinsights.azure.com",
        "*.oms.opinsights.azure.com",
        "*.monitoring.azure.com",
        "*.handler.control.monitor.azure.com",
        "*.ingest.monitor.azure.com",
      ]

      protocols {
        type = "Https"
        port = 443
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Azure Bastion
# ---------------------------------------------------------------------------
resource "azurerm_public_ip" "bastion" {
  count = local.bastion_enabled ? 1 : 0

  name                = var.bastion.public_ip_name
  location            = var.location
  resource_group_name = local.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.bastion.zones
  tags                = var.tags
}

resource "azurerm_bastion_host" "this" {
  count = local.bastion_enabled ? 1 : 0

  name                   = var.bastion.name
  location               = var.location
  resource_group_name    = local.resource_group_name
  sku                    = var.bastion.sku
  tunneling_enabled      = var.bastion.sku == "Basic" ? false : var.bastion.tunneling_enabled
  shareable_link_enabled = false

  ip_configuration {
    name                 = "ipconfig-primary"
    subnet_id            = azurerm_subnet.bastion[0].id
    public_ip_address_id = azurerm_public_ip.bastion[0].id
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Private DNS
# ---------------------------------------------------------------------------
resource "azurerm_private_dns_zone" "this" {
  for_each = toset(var.private_dns_zones)

  name                = each.value
  resource_group_name = local.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "hub" {
  for_each = azurerm_private_dns_zone.this

  name                  = "link-${azurerm_virtual_network.hub.name}"
  resource_group_name   = local.resource_group_name
  private_dns_zone_name = each.value.name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = false
  tags                  = var.tags
}

# ---------------------------------------------------------------------------
# Hub-side peerings for externally managed spokes
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  for_each = var.spoke_peerings

  name                         = substr("peer-hub-to-${each.key}", 0, 80)
  resource_group_name          = local.resource_group_name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = each.value.remote_virtual_network_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = each.value.allow_gateway_transit
  use_remote_gateways          = false
}

# ---------------------------------------------------------------------------
# Diagnostics
# ---------------------------------------------------------------------------
locals {
  diagnostic_targets = merge(
    { vnet = { id = azurerm_virtual_network.hub.id, destination_type = null } },
    local.firewall_enabled ? { firewall = { id = azurerm_firewall.this[0].id, destination_type = "Dedicated" } } : {},
    local.bastion_enabled ? { bastion = { id = azurerm_bastion_host.this[0].id, destination_type = null } } : {},
  )
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  for_each = var.enable_diagnostics ? local.diagnostic_targets : {}

  name                           = "send-to-law"
  target_resource_id             = each.value.id
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  log_analytics_destination_type = each.value.destination_type

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }

  lifecycle {
    precondition {
      condition     = var.log_analytics_workspace_id != null
      error_message = "log_analytics_workspace_id must be set when enable_diagnostics is true."
    }
  }
}
