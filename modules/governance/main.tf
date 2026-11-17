locals {
  # Public built-in policy definitions (tenant-agnostic IDs).
  builtin_policy = {
    allowed_locations          = "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c"
    allowed_locations_rg       = "/providers/Microsoft.Authorization/policyDefinitions/e765b5de-1225-4ba3-bd56-1ac6695af988"
    require_tag_on_rg          = "/providers/Microsoft.Authorization/policyDefinitions/96670d01-0a4d-4649-9c89-2d3abc0a5025"
    inherit_tag_from_rg        = "/providers/Microsoft.Authorization/policyDefinitions/ea3f2387-9b95-492a-a190-fcdc54f7b070"
    not_allowed_resource_types = "/providers/Microsoft.Authorization/policyDefinitions/6c112d4e-5bc7-47ae-a041-ea2d9dccd749"
    nic_no_public_ip           = "/providers/Microsoft.Authorization/policyDefinitions/83a86a26-fd1f-447c-b59d-e51f44264114"
  }

  top_level_groups = {
    platform       = { name = "${var.root_id}-platform", display_name = "Platform" }
    landing_zones  = { name = "${var.root_id}-landing-zones", display_name = "Landing Zones" }
    sandbox        = { name = "${var.root_id}-sandbox", display_name = "Sandbox" }
    decommissioned = { name = "${var.root_id}-decommissioned", display_name = "Decommissioned" }
  }

  child_groups = merge(
    { for g in var.platform_child_groups : g => { parent = "platform", name = "${var.root_id}-${g}", display_name = title(replace(g, "-", " ")) } },
    { for g in var.landing_zone_child_groups : g => { parent = "landing_zones", name = "${var.root_id}-${g}", display_name = title(replace(g, "-", " ")) } },
  )
}

# ---------------------------------------------------------------------------
# Management group hierarchy (one resource per level so parents exist first)
# ---------------------------------------------------------------------------
resource "azurerm_management_group" "root" {
  name                       = var.root_id
  display_name               = var.root_display_name
  parent_management_group_id = var.root_parent_management_group_id
}

resource "azurerm_management_group" "top" {
  for_each = local.top_level_groups

  name                       = each.value.name
  display_name               = each.value.display_name
  parent_management_group_id = azurerm_management_group.root.id
}

resource "azurerm_management_group" "child" {
  for_each = local.child_groups

  name                       = each.value.name
  display_name               = each.value.display_name
  parent_management_group_id = azurerm_management_group.top[each.value.parent].id
}

locals {
  management_group_ids = merge(
    { root = azurerm_management_group.root.id },
    { for k, mg in azurerm_management_group.top : k => mg.id },
    { for k, mg in azurerm_management_group.child : k => mg.id },
  )
}

resource "azurerm_management_group_subscription_association" "this" {
  for_each = var.subscription_placement

  management_group_id = lookup(local.management_group_ids, each.value.management_group, null)
  subscription_id     = "/subscriptions/${each.value.subscription_id}"

  lifecycle {
    precondition {
      condition     = contains(keys(local.management_group_ids), each.value.management_group)
      error_message = "subscription_placement.${each.key}.management_group must be one of: ${join(", ", keys(local.management_group_ids))}."
    }
  }
}

# ---------------------------------------------------------------------------
# Policy assignments (built-in definitions only)
# ---------------------------------------------------------------------------
resource "azurerm_management_group_policy_assignment" "allowed_locations" {
  name                 = "allowed-locations"
  display_name         = "Allowed locations for resources"
  description          = "Restricts resource deployment to approved regions."
  management_group_id  = azurerm_management_group.root.id
  policy_definition_id = local.builtin_policy.allowed_locations
  enforce              = var.policy_enforcement_enabled

  parameters = jsonencode({
    listOfAllowedLocations = { value = var.allowed_locations }
  })

  non_compliance_message {
    content = "Resources must be deployed to an approved region: ${join(", ", var.allowed_locations)}."
  }
}

resource "azurerm_management_group_policy_assignment" "allowed_locations_rg" {
  name                 = "allowed-locations-rg"
  display_name         = "Allowed locations for resource groups"
  description          = "Restricts resource group creation to approved regions."
  management_group_id  = azurerm_management_group.root.id
  policy_definition_id = local.builtin_policy.allowed_locations_rg
  enforce              = var.policy_enforcement_enabled

  parameters = jsonencode({
    listOfAllowedLocations = { value = var.allowed_locations }
  })

  non_compliance_message {
    content = "Resource groups must be created in an approved region: ${join(", ", var.allowed_locations)}."
  }
}

# Assignment names are limited to 24 characters, so tag names are hashed into the name.
resource "azurerm_management_group_policy_assignment" "require_rg_tag" {
  for_each = toset(var.mandatory_tag_names)

  name                 = "rg-tag-${substr(sha1(each.key), 0, 10)}"
  display_name         = "Require tag '${each.key}' on resource groups"
  management_group_id  = azurerm_management_group.root.id
  policy_definition_id = local.builtin_policy.require_tag_on_rg
  enforce              = var.policy_enforcement_enabled

  parameters = jsonencode({
    tagName = { value = each.key }
  })

  non_compliance_message {
    content = "Resource groups must have the '${each.key}' tag."
  }
}

resource "azurerm_management_group_policy_assignment" "inherit_rg_tag" {
  for_each = var.inherit_tags_from_resource_group ? toset(var.mandatory_tag_names) : toset([])

  name                 = "inh-tag-${substr(sha1(each.key), 0, 10)}"
  display_name         = "Inherit tag '${each.key}' from the resource group if missing"
  management_group_id  = azurerm_management_group.root.id
  policy_definition_id = local.builtin_policy.inherit_tag_from_rg
  enforce              = var.policy_enforcement_enabled
  location             = var.policy_identity_location

  parameters = jsonencode({
    tagName = { value = each.key }
  })

  identity {
    type = "SystemAssigned"
  }

  lifecycle {
    precondition {
      condition     = var.policy_identity_location != null
      error_message = "policy_identity_location must be set when inherit_tags_from_resource_group is true."
    }
  }
}

# The definition declares Contributor; Tag Contributor is sufficient for tag-only Modify remediation.
resource "azurerm_role_assignment" "inherit_rg_tag" {
  for_each = azurerm_management_group_policy_assignment.inherit_rg_tag

  scope                = azurerm_management_group.root.id
  role_definition_name = "Tag Contributor"
  principal_id         = each.value.identity[0].principal_id
  principal_type       = "ServicePrincipal"
  description          = "Allows policy assignment ${each.value.name} to remediate missing tags."
}

resource "azurerm_management_group_policy_assignment" "deny_public_ip" {
  for_each = toset(var.deny_public_ip_management_groups)

  name                 = "deny-public-ip"
  display_name         = "Deny public IP addresses"
  description          = "Blocks creation of public IP address resources in this scope."
  management_group_id  = lookup(local.management_group_ids, each.key, null)
  policy_definition_id = local.builtin_policy.not_allowed_resource_types
  enforce              = var.policy_enforcement_enabled

  parameters = jsonencode({
    listOfResourceTypesNotAllowed = { value = ["Microsoft.Network/publicIPAddresses"] }
  })

  non_compliance_message {
    content = "Public IP addresses are not allowed here. Publish workloads through the platform ingress path."
  }

  lifecycle {
    precondition {
      condition     = contains(keys(local.management_group_ids), each.key)
      error_message = "deny_public_ip_management_groups entry '${each.key}' is not a management group key: ${join(", ", keys(local.management_group_ids))}."
    }
  }
}

resource "azurerm_management_group_policy_assignment" "deny_nic_public_ip" {
  for_each = toset(var.deny_public_ip_management_groups)

  name                 = "deny-nic-public-ip"
  display_name         = "Network interfaces should not have public IPs"
  management_group_id  = lookup(local.management_group_ids, each.key, null)
  policy_definition_id = local.builtin_policy.nic_no_public_ip
  enforce              = var.policy_enforcement_enabled

  non_compliance_message {
    content = "Network interfaces must not be associated with a public IP address."
  }

  lifecycle {
    precondition {
      condition     = contains(keys(local.management_group_ids), each.key)
      error_message = "deny_public_ip_management_groups entry '${each.key}' is not a management group key: ${join(", ", keys(local.management_group_ids))}."
    }
  }
}
