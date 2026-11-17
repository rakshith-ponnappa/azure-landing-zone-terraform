variable "connectivity_subscription_id" {
  description = "Subscription that hosts management and the hub network in this example."
  type        = string
}

variable "prefix" {
  description = "Short organisation prefix used in names and as the root management group ID."
  type        = string
  default     = "alz"
}

variable "organisation_display_name" {
  description = "Display name of the root management group."
  type        = string
  default     = "Example Organisation"
}

variable "location" {
  description = "Primary Azure region."
  type        = string
  default     = "uksouth"
}

variable "allowed_locations" {
  description = "Regions allowed by policy."
  type        = list(string)
  default     = ["uksouth", "ukwest"]
}

variable "hub_address_space" {
  description = "Hub VNet CIDR. Split into /26-or-larger quarters for firewall, bastion and spare."
  type        = string
  default     = "10.0.0.0/22"
}

variable "spoke_address_spaces" {
  description = "Spoke CIDRs allowed through the firewall's AKS egress rules."
  type        = list(string)
  default     = ["10.1.0.0/22"]
}

variable "owner" {
  description = "Owner tag value."
  type        = string
  default     = "platform-team@example.com"
}

variable "cost_center" {
  description = "Cost-center tag value."
  type        = string
  default     = "CC-0000"
}

variable "github_repository" {
  description = "GitHub repository (owner/name) allowed to deploy through OIDC."
  type        = string
  default     = "your-org/azure-landing-zone-terraform"
}
