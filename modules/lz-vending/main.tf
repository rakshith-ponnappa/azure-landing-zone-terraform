data "azurerm_subscription" "current" {}

# ---------------------------------------------------------------------------
# Subscription (optional alias) and management group placement
# ---------------------------------------------------------------------------
resource "azurerm_subscription" "this" {
  count = var.subscription_alias_enabled ? 1 : 0

  alias             = try(var.subscription_alias.name, null)
  subscription_name = try(var.subscription_alias.display_name, null)
  billing_scope_id  = try(var.subscription_alias.billing_scope_id, null)
  workload          = try(var.subscription_alias.workload, null)
  tags              = var.tags

  lifecycle {
    precondition {
      condition     = var.subscription_alias != null
      error_message = "subscription_alias must be set when subscription_alias_enabled is true."
    }
  }
}

locals {
  subscription_id = (
    var.subscription_alias_enabled ? azurerm_subscription.this[0].subscription_id :
    coalesce(var.subscription_id, data.azurerm_subscription.current.subscription_id)
  )
  subscription_resource_id = "/subscriptions/${local.subscription_id}"
}

# Resource groups and networking are created through the default provider, which must target the
# landing zone subscription. Surface a warning instead of silently deploying elsewhere.
check "provider_targets_landing_zone_subscription" {
  assert {
    condition     = data.azurerm_subscription.current.subscription_id == local.subscription_id
    error_message = "The default azurerm provider targets ${data.azurerm_subscription.current.subscription_id}, but the landing zone subscription is ${local.subscription_id}. Spoke resources would be created in the wrong subscription."
  }
}

resource "azurerm_management_group_subscription_association" "this" {
  count = var.management_group_id != null ? 1 : 0

  management_group_id = var.management_group_id
  subscription_id     = local.subscription_resource_id
}

# ---------------------------------------------------------------------------
# Resource groups
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "network" {
  name     = var.network_resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_resource_group" "workload" {
  for_each = var.resource_groups

  name     = each.value.name
  location = coalesce(each.value.location, var.location)
  tags     = merge(var.tags, each.value.tags)
}

locals {
  resource_group_ids = merge(
    { network = azurerm_resource_group.network.id },
    { for k, rg in azurerm_resource_group.workload : k => rg.id },
  )
}

# ---------------------------------------------------------------------------
# Spoke network
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "spoke" {
  name                = var.virtual_network.name
  location            = var.location
  resource_group_name = azurerm_resource_group.network.name
  address_space       = var.virtual_network.address_space
  dns_servers         = var.virtual_network.dns_servers
  tags                = var.tags
}

resource "azurerm_subnet" "this" {
  for_each = var.virtual_network.subnets

  name                              = each.key
  resource_group_name               = azurerm_resource_group.network.name
  virtual_network_name              = azurerm_virtual_network.spoke.name
  address_prefixes                  = each.value.address_prefixes
  service_endpoints                 = each.value.service_endpoints
  private_endpoint_network_policies = each.value.private_endpoint_network_policies
  default_outbound_access_enabled   = false

  dynamic "delegation" {
    for_each = each.value.delegation != null ? [each.value.delegation] : []
    content {
      name = delegation.value.name
      service_delegation {
        name    = delegation.value.service_name
        actions = delegation.value.actions
      }
    }
  }
}

resource "azurerm_network_security_group" "this" {
  for_each = { for k, s in var.virtual_network.subnets : k => s if s.create_network_security_group }

  name                = "nsg-${trimprefix(var.virtual_network.name, "vnet-")}-${each.key}"
  location            = var.location
  resource_group_name = azurerm_resource_group.network.name
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = azurerm_network_security_group.this

  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = each.value.id
}

resource "azurerm_route_table" "this" {
  count = var.route_table != null ? 1 : 0

  name                          = var.route_table.name
  location                      = var.location
  resource_group_name           = azurerm_resource_group.network.name
  bgp_route_propagation_enabled = var.route_table.bgp_route_propagation_enabled
  tags                          = var.tags
}

resource "azurerm_route" "default_to_firewall" {
  count = var.route_table != null ? 1 : 0

  name                   = "default-to-hub-firewall"
  resource_group_name    = azurerm_resource_group.network.name
  route_table_name       = azurerm_route_table.this[0].name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = var.route_table.firewall_private_ip
}

resource "azurerm_subnet_route_table_association" "this" {
  for_each = var.route_table != null ? { for k, s in var.virtual_network.subnets : k => s if s.route_to_firewall } : {}

  subnet_id      = azurerm_subnet.this[each.key].id
  route_table_id = azurerm_route_table.this[0].id

  # The default route must exist before workloads (e.g. AKS with userDefinedRouting) use the subnet.
  depends_on = [azurerm_route.default_to_firewall]
}

# ---------------------------------------------------------------------------
# Hub peering (spoke side + optional hub side in the connectivity subscription)
# ---------------------------------------------------------------------------
locals {
  hub_vnet = var.hub_peering == null ? null : {
    id                  = var.hub_peering.hub_virtual_network_id
    resource_group_name = regex("(?i)/resourceGroups/([^/]+)/", var.hub_peering.hub_virtual_network_id)[0]
    name                = regex("(?i)/virtualNetworks/([^/]+)$", var.hub_peering.hub_virtual_network_id)[0]
  }
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  count = var.hub_peering != null ? 1 : 0

  name                         = substr("peer-to-${local.hub_vnet.name}", 0, 80)
  resource_group_name          = azurerm_resource_group.network.name
  virtual_network_name         = azurerm_virtual_network.spoke.name
  remote_virtual_network_id    = local.hub_vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = var.hub_peering.use_remote_gateways
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  provider = azurerm.hub
  count    = var.hub_peering != null ? (var.hub_peering.create_hub_side ? 1 : 0) : 0

  name                         = substr("peer-to-${azurerm_virtual_network.spoke.name}", 0, 80)
  resource_group_name          = local.hub_vnet.resource_group_name
  virtual_network_name         = local.hub_vnet.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = var.hub_peering.use_remote_gateways
}

# ---------------------------------------------------------------------------
# Budget
# ---------------------------------------------------------------------------
resource "azurerm_consumption_budget_subscription" "this" {
  count = var.budget != null ? 1 : 0

  name            = var.budget.name
  subscription_id = local.subscription_resource_id
  amount          = var.budget.amount
  time_grain      = "Monthly"

  time_period {
    start_date = coalesce(var.budget.start_date, formatdate("YYYY-MM-01'T'00:00:00Z", plantimestamp()))
  }

  dynamic "notification" {
    for_each = var.budget.notifications
    content {
      enabled        = true
      threshold      = notification.value.threshold
      threshold_type = notification.value.threshold_type
      operator       = "GreaterThanOrEqualTo"
      contact_emails = var.budget.contact_emails
    }
  }

  lifecycle {
    # The default start date moves every month; only the first value matters.
    ignore_changes = [time_period]
  }
}

# ---------------------------------------------------------------------------
# App team RBAC
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "app_team" {
  for_each = var.app_team_role_assignments

  scope                = each.value.resource_group_key == null ? local.subscription_resource_id : lookup(local.resource_group_ids, each.value.resource_group_key, null)
  role_definition_name = each.value.role_definition_name
  principal_id         = each.value.principal_id
  principal_type       = each.value.principal_type

  lifecycle {
    precondition {
      condition     = each.value.resource_group_key == null ? true : contains(keys(local.resource_group_ids), each.value.resource_group_key)
      error_message = "app_team_role_assignments.${each.key}.resource_group_key must be one of: ${join(", ", keys(local.resource_group_ids))}."
    }
  }
}
