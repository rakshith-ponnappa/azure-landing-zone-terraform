variable "owner" {
  description = "Accountable owner of the resources. Use a team mailbox or distribution list, not an individual."
  type        = string

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.owner))
    error_message = "owner must be an email address, e.g. platform-team@example.com."
  }
}

variable "cost_center" {
  description = "Cost centre or charge code used for showback/chargeback."
  type        = string

  validation {
    condition     = length(trimspace(var.cost_center)) > 0 && length(var.cost_center) <= 64
    error_message = "cost_center must be a non-empty string of at most 64 characters."
  }
}

variable "environment" {
  description = "Environment the resources belong to."
  type        = string

  validation {
    condition     = contains(["dev", "test", "qa", "uat", "stg", "prod", "sbx", "plat"], var.environment)
    error_message = "environment must be one of: dev, test, qa, uat, stg, prod, sbx, plat."
  }
}

variable "data_classification" {
  description = "Highest classification of data stored or processed by the resources."
  type        = string

  validation {
    condition     = contains(["public", "internal", "confidential", "restricted"], var.data_classification)
    error_message = "data_classification must be one of: public, internal, confidential, restricted."
  }
}

variable "managed_by" {
  description = "Tool or process that manages the resources. Changing this away from `terraform` is a signal that drift is expected."
  type        = string
  default     = "terraform"
}

variable "additional_tags" {
  description = "Optional extra tags. Mandatory tags always win if a key collides."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for k, v in var.additional_tags : length(k) <= 512 && length(v) <= 256 && !can(regex("[<>%&\\\\?/]", k))
    ])
    error_message = "Tag keys must be <= 512 chars without <>%&\\?/ and values must be <= 256 chars."
  }
}
