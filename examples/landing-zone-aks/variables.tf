variable "landing_zone_subscription_id" {
  description = "Existing application landing zone subscription."
  type        = string
}

variable "connectivity_subscription_id" {
  description = "Subscription that owns the hub VNet (for the hub-side peering)."
  type        = string
}

variable "management_group_id" {
  description = "Management group to place the subscription in (e.g. the corp landing zone group ID from the platform outputs)."
  type        = string
  default     = null
}

variable "prefix" {
  description = "Organisation prefix used in names."
  type        = string
  default     = "alz"
}

variable "workload" {
  description = "Workload short name."
  type        = string
  default     = "app1"
}

variable "environment" {
  description = "Environment short name (dev, tst, prd)."
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region (must be allowed by policy)."
  type        = string
  default     = "uksouth"
}

variable "spoke_address_space" {
  description = "Spoke VNet CIDR. The first half hosts AKS nodes (CNI Overlay keeps pods off the VNet)."
  type        = string
  default     = "10.1.0.0/22"
}

variable "hub_virtual_network_id" {
  description = "Hub VNet ID (platform output hub_virtual_network_id)."
  type        = string
}

variable "firewall_private_ip" {
  description = "Hub firewall private IP (platform output firewall_private_ip); used as next hop and DNS proxy."
  type        = string
}

variable "aks_private_dns_zone_id" {
  description = "Central privatelink.<region>.azmk8s.io zone ID (platform output private_dns_zone_ids), or \"System\"."
  type        = string
  default     = "System"
}

variable "log_analytics_workspace_id" {
  description = "Central Log Analytics workspace ID (platform output)."
  type        = string
}

variable "owner" {
  description = "Owner tag value."
  type        = string
  default     = "app1-team@example.com"
}

variable "cost_center" {
  description = "Cost-center tag value."
  type        = string
  default     = "CC-0001"
}

variable "monthly_budget" {
  description = "Monthly subscription budget in the billing currency."
  type        = number
  default     = 1000
}

variable "budget_contact_emails" {
  description = "Budget alert recipients."
  type        = list(string)
  default     = ["app1-team@example.com"]
}

variable "app_team_group_object_id" {
  description = "Entra group object ID of the application team (Contributor on the workload resource group)."
  type        = string
}

variable "cluster_admin_group_object_ids" {
  description = "Entra group object IDs with cluster-admin through Azure RBAC."
  type        = list(string)
  default     = []
}
