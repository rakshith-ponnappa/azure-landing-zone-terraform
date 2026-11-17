variable "location" {
  description = "Azure region for the landing zone resources."
  type        = string
}

variable "subscription_id" {
  description = "GUID of an existing landing zone subscription. Null uses the subscription the default azurerm provider targets. Ignored when subscription_alias_enabled is true."
  type        = string
  default     = null

  validation {
    condition     = var.subscription_id == null ? true : can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.subscription_id))
    error_message = "subscription_id must be a subscription GUID."
  }
}

variable "subscription_alias_enabled" {
  description = "Create a NEW subscription through a subscription alias (requires an EA/MCA billing scope and the matching billing role). Off by default; see the module README for the two-stage workflow."
  type        = bool
  default     = false
}

variable "subscription_alias" {
  description = "Subscription alias settings, required when subscription_alias_enabled is true. `workload` is Production or DevTest."
  type = object({
    name             = string
    display_name     = string
    billing_scope_id = string
    workload         = optional(string, "Production")
  })
  default = null

  validation {
    condition     = var.subscription_alias == null ? true : contains(["Production", "DevTest"], var.subscription_alias.workload)
    error_message = "subscription_alias.workload must be Production or DevTest."
  }

  validation {
    condition     = var.subscription_alias == null ? true : can(regex("^/providers/Microsoft.Billing/billingAccounts/", var.subscription_alias.billing_scope_id))
    error_message = "subscription_alias.billing_scope_id must start with /providers/Microsoft.Billing/billingAccounts/."
  }
}

variable "management_group_id" {
  description = "Resource ID of the management group to place the subscription in (e.g. the corp landing zone group). Null leaves placement unchanged."
  type        = string
  default     = null

  validation {
    condition     = var.management_group_id == null ? true : can(regex("^/providers/Microsoft.Management/managementGroups/[^/]+$", var.management_group_id))
    error_message = "management_group_id must look like /providers/Microsoft.Management/managementGroups/<name>."
  }
}

variable "network_resource_group_name" {
  description = "Name of the resource group for the spoke VNet, NSGs and route table."
  type        = string
}

variable "resource_groups" {
  description = "Additional workload resource groups keyed by a short label (e.g. `aks`, `data`). The key `network` is reserved."
  type = map(object({
    name     = string
    location = optional(string)
    tags     = optional(map(string), {})
  }))
  default = {}

  validation {
    condition     = !contains(keys(var.resource_groups), "network")
    error_message = "The resource_groups key 'network' is reserved for network_resource_group_name."
  }
}

variable "virtual_network" {
  description = <<-EOT
    Spoke virtual network. Subnets are keyed by subnet name.
    - `route_to_firewall` associates the subnet with the route table (when `route_table` is set).
    - `create_network_security_group` creates an empty NSG (platform default rules only) per subnet;
      add rules with `azurerm_network_security_rule` using the `network_security_group_ids` output.
    - `dns_servers` set to the hub firewall private IP when it runs as DNS proxy.
  EOT
  type = object({
    name          = string
    address_space = list(string)
    dns_servers   = optional(list(string), [])
    subnets = map(object({
      address_prefixes                  = list(string)
      route_to_firewall                 = optional(bool, true)
      create_network_security_group     = optional(bool, true)
      service_endpoints                 = optional(list(string), [])
      private_endpoint_network_policies = optional(string, "Enabled")
      delegation = optional(object({
        name         = string
        service_name = string
        actions      = optional(list(string), [])
      }))
    }))
  })

  validation {
    condition     = length(var.virtual_network.address_space) > 0 && alltrue([for c in var.virtual_network.address_space : can(cidrhost(c, 0))])
    error_message = "virtual_network.address_space must contain at least one valid CIDR block."
  }

  validation {
    condition = alltrue([
      for s in values(var.virtual_network.subnets) : length(s.address_prefixes) > 0 && alltrue([for c in s.address_prefixes : can(cidrhost(c, 0))])
    ])
    error_message = "Every subnet needs at least one valid CIDR in address_prefixes."
  }

  validation {
    condition     = alltrue([for ip in var.virtual_network.dns_servers : can(cidrhost("${ip}/32", 0))])
    error_message = "virtual_network.dns_servers must be IPv4 addresses."
  }
}

variable "hub_peering" {
  description = "Peer the spoke with the hub. The hub-side peering is created with the `azurerm.hub` provider when create_hub_side is true. Null disables peering."
  type = object({
    hub_virtual_network_id = string
    create_hub_side        = optional(bool, true)
    use_remote_gateways    = optional(bool, false)
  })
  default = null

  validation {
    condition     = var.hub_peering == null ? true : can(regex("(?i)^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft.Network/virtualNetworks/[^/]+$", var.hub_peering.hub_virtual_network_id))
    error_message = "hub_peering.hub_virtual_network_id must be a virtual network resource ID."
  }
}

variable "route_table" {
  description = "Route table that sends 0.0.0.0/0 to the hub firewall. Null skips the route table."
  type = object({
    name                          = string
    firewall_private_ip           = string
    bgp_route_propagation_enabled = optional(bool, false)
  })
  default = null

  validation {
    condition     = var.route_table == null ? true : can(cidrhost("${var.route_table.firewall_private_ip}/32", 0))
    error_message = "route_table.firewall_private_ip must be an IPv4 address."
  }
}

variable "budget" {
  description = "Monthly subscription budget with e-mail alerts. Null skips the budget. `start_date` defaults to the first day of the current month (RFC 3339)."
  type = object({
    name           = string
    amount         = number
    contact_emails = list(string)
    start_date     = optional(string)
    notifications = optional(list(object({
      threshold      = number
      threshold_type = optional(string, "Actual")
      })), [
      { threshold = 80, threshold_type = "Actual" },
      { threshold = 100, threshold_type = "Actual" },
      { threshold = 100, threshold_type = "Forecasted" },
    ])
  })
  default = null

  validation {
    condition     = var.budget == null ? true : var.budget.amount > 0 && length(var.budget.contact_emails) > 0
    error_message = "budget.amount must be positive and budget.contact_emails must not be empty."
  }

  validation {
    condition = var.budget == null ? true : length(var.budget.notifications) >= 1 && length(var.budget.notifications) <= 5 && alltrue([
      for n in var.budget.notifications : n.threshold > 0 && n.threshold <= 1000 && contains(["Actual", "Forecasted"], n.threshold_type)
    ])
    error_message = "budget.notifications must have 1-5 entries with threshold 0-1000 and threshold_type Actual or Forecasted."
  }

  validation {
    condition     = var.budget == null ? true : var.budget.start_date == null ? true : can(regex("^\\d{4}-\\d{2}-01T00:00:00Z$", var.budget.start_date))
    error_message = "budget.start_date must be the first day of a month, e.g. 2026-01-01T00:00:00Z."
  }
}

variable "app_team_role_assignments" {
  description = <<-EOT
    RBAC for the application team, keyed by a static label. Scope is the subscription unless
    `resource_group_key` names `network` or a key of `resource_groups`. Owner, User Access
    Administrator and Role Based Access Control Administrator are rejected; grant those via the
    identity module with a documented exception.
  EOT
  type = map(object({
    principal_id         = string
    role_definition_name = string
    principal_type       = optional(string, "Group")
    resource_group_key   = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for r in values(var.app_team_role_assignments) : !contains(["Owner", "User Access Administrator", "Role Based Access Control Administrator"], r.role_definition_name)
    ])
    error_message = "Privileged roles are not allowed for app teams in lz-vending."
  }

  validation {
    condition     = alltrue([for r in values(var.app_team_role_assignments) : contains(["User", "Group", "ServicePrincipal"], r.principal_type)])
    error_message = "principal_type must be User, Group or ServicePrincipal."
  }
}

variable "tags" {
  description = "Tags applied to all resources (and the subscription when an alias is created)."
  type        = map(string)
  default     = {}
}
