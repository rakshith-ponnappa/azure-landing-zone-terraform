variable "role_assignments" {
  description = <<-EOT
    Role assignments for existing principals (groups, service principals), keyed by a static label.
    Set exactly one of `role_definition_name` or `role_definition_id`. Prefer groups over users and
    set `principal_type` to avoid Entra ID replication delays for newly created principals.
  EOT
  type = map(object({
    scope                = string
    principal_id         = string
    role_definition_name = optional(string)
    role_definition_id   = optional(string)
    principal_type       = optional(string)
    description          = optional(string)
    condition            = optional(string)
    condition_version    = optional(string)
  }))
  default = {}

  validation {
    condition     = alltrue([for r in values(var.role_assignments) : (r.role_definition_name == null) != (r.role_definition_id == null)])
    error_message = "Each role assignment must set exactly one of role_definition_name or role_definition_id."
  }

  validation {
    condition     = alltrue([for r in values(var.role_assignments) : r.principal_type == null ? true : contains(["User", "Group", "ServicePrincipal"], r.principal_type)])
    error_message = "principal_type must be User, Group, ServicePrincipal or null."
  }

  validation {
    condition     = alltrue([for r in values(var.role_assignments) : r.condition == null ? r.condition_version == null : r.condition_version == "2.0"])
    error_message = "condition_version must be \"2.0\" when a condition is set and null otherwise."
  }
}

variable "user_assigned_identity" {
  description = "Optional user-assigned managed identity to create (e.g. a deployment identity for GitHub Actions OIDC). Null skips it."
  type = object({
    name                = string
    resource_group_name = string
    location            = string
  })
  default = null

  validation {
    condition     = var.user_assigned_identity == null ? true : can(regex("^[A-Za-z0-9][A-Za-z0-9_-]{2,127}$", var.user_assigned_identity.name))
    error_message = "user_assigned_identity.name must be 3-128 characters of letters, digits, '-' or '_' and start alphanumeric."
  }
}

variable "user_assigned_identity_role_assignments" {
  description = "Role assignments for the user-assigned identity, keyed by a static label. Ignored when user_assigned_identity is null."
  type = map(object({
    scope                = string
    role_definition_name = string
    description          = optional(string)
  }))
  default = {}
}

variable "federated_identity_credentials" {
  description = <<-EOT
    Federated credentials for the user-assigned identity, keyed by credential name. Defaults target
    GitHub Actions OIDC; `subject` examples: `repo:my-org/my-repo:environment:prod`,
    `repo:my-org/my-repo:ref:refs/heads/main`, `repo:my-org/my-repo:pull_request`.
  EOT
  type = map(object({
    subject  = string
    issuer   = optional(string, "https://token.actions.githubusercontent.com")
    audience = optional(list(string), ["api://AzureADTokenExchange"])
  }))
  default = {}

  validation {
    condition     = alltrue([for k in keys(var.federated_identity_credentials) : can(regex("^[A-Za-z0-9][A-Za-z0-9_-]{2,119}$", k))])
    error_message = "Federated credential names (map keys) must be 3-120 characters of letters, digits, '-' or '_' and start alphanumeric."
  }

  validation {
    condition     = alltrue([for c in values(var.federated_identity_credentials) : startswith(c.issuer, "https://")])
    error_message = "issuer must be an https URL."
  }
}

variable "tags" {
  description = "Tags applied to the user-assigned identity."
  type        = map(string)
  default     = {}
}
