variable "root_id" {
  description = "Short ID for the intermediate root management group. Child groups are named `<root_id>-<group>`."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,29}$", var.root_id))
    error_message = "root_id must be 2-30 lowercase alphanumeric characters or hyphens and start with a letter."
  }
}

variable "root_display_name" {
  description = "Display name of the intermediate root management group."
  type        = string

  validation {
    condition     = length(trimspace(var.root_display_name)) > 0 && length(var.root_display_name) <= 90
    error_message = "root_display_name must be 1-90 characters."
  }
}

variable "root_parent_management_group_id" {
  description = "Resource ID of the parent for the intermediate root. Null places it under the tenant root group."
  type        = string
  default     = null

  validation {
    condition     = var.root_parent_management_group_id == null ? true : can(regex("^/providers/Microsoft.Management/managementGroups/[^/]+$", var.root_parent_management_group_id))
    error_message = "root_parent_management_group_id must look like /providers/Microsoft.Management/managementGroups/<name>."
  }
}

variable "platform_child_groups" {
  description = "Child management groups created under Platform."
  type        = list(string)
  default     = ["management", "connectivity", "identity"]

  validation {
    condition     = alltrue([for g in var.platform_child_groups : can(regex("^[a-z][a-z0-9-]{1,23}$", g)) && !contains(["root", "platform", "sandbox", "decommissioned"], g)])
    error_message = "Child group names must be 2-24 lowercase alphanumeric/hyphen characters and must not be root, platform, sandbox or decommissioned."
  }
}

variable "landing_zone_child_groups" {
  description = "Child management groups created under Landing Zones (CAF archetypes such as corp and online)."
  type        = list(string)
  default     = ["corp", "online"]

  validation {
    condition     = alltrue([for g in var.landing_zone_child_groups : can(regex("^[a-z][a-z0-9-]{1,23}$", g)) && !contains(["root", "platform", "sandbox", "decommissioned"], g)])
    error_message = "Child group names must be 2-24 lowercase alphanumeric/hyphen characters and must not be root, platform, sandbox or decommissioned."
  }
}

variable "subscription_placement" {
  description = <<-EOT
    Existing subscriptions to move into the hierarchy, keyed by a friendly name.
    `management_group` is a key from the `management_group_ids` output: root, platform, landing_zones,
    sandbox, decommissioned, or any child group name. Do not also place the same subscription with lz-vending.
  EOT
  type = map(object({
    subscription_id  = string
    management_group = string
  }))
  default = {}

  validation {
    condition     = alltrue([for s in values(var.subscription_placement) : can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", s.subscription_id))])
    error_message = "subscription_id must be a subscription GUID."
  }
}

variable "allowed_locations" {
  description = "Regions where resources and resource groups may be deployed. Enforced at the intermediate root."
  type        = list(string)

  validation {
    condition     = length(var.allowed_locations) > 0 && alltrue([for l in var.allowed_locations : can(regex("^[a-z][a-z0-9]+$", l))])
    error_message = "allowed_locations must be a non-empty list of programmatic region names, e.g. eastus."
  }
}

variable "mandatory_tag_names" {
  description = "Tag names that every resource group must carry. Pass the tagging module's `mandatory_tag_names` output."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for t in var.mandatory_tag_names : length(t) > 0 && length(t) <= 512])
    error_message = "Tag names must be 1-512 characters."
  }
}

variable "inherit_tags_from_resource_group" {
  description = "Also assign a Modify policy per mandatory tag so resources inherit the tag from their resource group when missing. Creates a system-assigned identity per assignment with Tag Contributor at the root."
  type        = bool
  default     = true
}

variable "deny_public_ip_management_groups" {
  description = "Management group keys where public IP addresses and NICs with public IPs are denied. Defaults to the corp archetype."
  type        = list(string)
  default     = ["corp"]
}

variable "policy_enforcement_enabled" {
  description = "Set to false to create all assignments with enforcement mode DoNotEnforce (audit-first rollout)."
  type        = bool
  default     = true
}

variable "policy_identity_location" {
  description = "Region for the managed identities of Modify/DeployIfNotExists policy assignments. Required when inherit_tags_from_resource_group is true."
  type        = string
  default     = null
}
