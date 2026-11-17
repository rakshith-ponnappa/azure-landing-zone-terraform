variable "prefix" {
  description = "Optional short organisation or estate prefix (lowercase alphanumeric, max 6 chars). Leave empty to omit it from names."
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^[a-z0-9]{0,6}$", var.prefix))
    error_message = "prefix must be 0-6 lowercase alphanumeric characters."
  }
}

variable "workload" {
  description = "Workload or application short name, e.g. `hub`, `mgmt`, `payments`. Lowercase alphanumeric, 2-12 chars, must start with a letter."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,11}$", var.workload))
    error_message = "workload must be 2-12 lowercase alphanumeric characters and start with a letter."
  }
}

variable "environment" {
  description = "Environment short code."
  type        = string

  validation {
    condition     = contains(["dev", "test", "qa", "uat", "stg", "prod", "sbx", "plat"], var.environment)
    error_message = "environment must be one of: dev, test, qa, uat, stg, prod, sbx, plat."
  }
}

variable "location" {
  description = "Azure region programmatic name, e.g. `eastus` or `uksouth`."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9]+$", var.location))
    error_message = "location must be the programmatic region name (lowercase, no spaces), e.g. eastus."
  }
}

variable "instance" {
  description = "Instance number used to disambiguate otherwise identical names. Rendered as three digits (1 => 001)."
  type        = number
  default     = 1

  validation {
    condition     = var.instance >= 1 && var.instance <= 999 && floor(var.instance) == var.instance
    error_message = "instance must be a whole number between 1 and 999."
  }
}

variable "region_abbreviation_overrides" {
  description = "Optional map of region name => short code that overrides or extends the built-in region abbreviations."
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for v in values(var.region_abbreviation_overrides) : can(regex("^[a-z0-9]{2,5}$", v))])
    error_message = "Region abbreviations must be 2-5 lowercase alphanumeric characters."
  }
}
