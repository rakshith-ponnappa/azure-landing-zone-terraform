variable "location" {
  description = "Azure region for the hub network."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group that holds the hub network resources."
  type        = string
}

variable "create_resource_group" {
  description = "Create the resource group. Set to false to deploy into an existing resource group."
  type        = bool
  default     = true
}

variable "virtual_network_name" {
  description = "Name of the hub virtual network."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9_.-]{0,62}[A-Za-z0-9_]$", var.virtual_network_name))
    error_message = "virtual_network_name must be 2-64 characters of letters, digits, '_', '.', '-', start alphanumeric and end alphanumeric or '_'."
  }
}

variable "address_space" {
  description = "Address space(s) of the hub virtual network, e.g. [\"10.0.0.0/22\"]."
  type        = list(string)

  validation {
    condition     = length(var.address_space) > 0 && alltrue([for c in var.address_space : can(cidrhost(c, 0))])
    error_message = "address_space must contain at least one valid CIDR block."
  }
}

variable "dns_servers" {
  description = "Custom DNS servers for the hub virtual network. Empty list keeps Azure-provided DNS (recommended when the firewall acts as DNS proxy)."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for ip in var.dns_servers : can(cidrhost("${ip}/32", 0))])
    error_message = "dns_servers must be IPv4 addresses."
  }
}

variable "ddos_protection_plan_id" {
  description = "Optional resource ID of an existing DDoS Network Protection plan to attach to the hub virtual network."
  type        = string
  default     = null
}

variable "gateway_subnet_address_prefix" {
  description = "Optional CIDR for `GatewaySubnet` (/27 or larger). Reserves space for a VPN/ExpressRoute gateway; the gateway itself is out of scope."
  type        = string
  default     = null

  validation {
    condition     = var.gateway_subnet_address_prefix == null ? true : can(cidrhost(var.gateway_subnet_address_prefix, 0))
    error_message = "gateway_subnet_address_prefix must be a valid CIDR block."
  }
}

variable "subnets" {
  description = "Additional hub subnets keyed by subnet name (e.g. shared private endpoints or DNS resolver). Default outbound access is disabled on these subnets."
  type = map(object({
    address_prefixes                  = list(string)
    service_endpoints                 = optional(list(string), [])
    private_endpoint_network_policies = optional(string, "Enabled")
  }))
  default = {}

  validation {
    condition = alltrue([
      for s in values(var.subnets) : length(s.address_prefixes) > 0 && alltrue([for c in s.address_prefixes : can(cidrhost(c, 0))])
    ])
    error_message = "Every subnet needs at least one valid CIDR in address_prefixes."
  }

  validation {
    condition     = alltrue([for k in keys(var.subnets) : !contains(["AzureFirewallSubnet", "AzureFirewallManagementSubnet", "AzureBastionSubnet", "GatewaySubnet"], k)])
    error_message = "Reserved subnet names are managed by the firewall, bastion and gateway_subnet_address_prefix inputs."
  }

  validation {
    condition     = alltrue([for s in values(var.subnets) : contains(["Disabled", "Enabled", "NetworkSecurityGroupEnabled", "RouteTableEnabled"], s.private_endpoint_network_policies)])
    error_message = "private_endpoint_network_policies must be Disabled, Enabled, NetworkSecurityGroupEnabled or RouteTableEnabled."
  }
}

variable "firewall" {
  description = <<-EOT
    Azure Firewall configuration. Set to null to deploy the hub without a firewall.
    - `subnet_address_prefix` CIDR for `AzureFirewallSubnet` (/26 recommended).
    - `sku_tier` Standard or Premium (Premium enables IDPS in Deny mode on the policy).
    - `aks_egress_source_addresses` when non-empty, adds a rule collection group that allows the
      minimum egress an AKS cluster with Container Insights and the Azure Policy add-on needs.
  EOT
  type = object({
    name                        = string
    policy_name                 = string
    public_ip_name              = string
    subnet_address_prefix       = string
    sku_tier                    = optional(string, "Standard")
    threat_intelligence_mode    = optional(string, "Deny")
    dns_proxy_enabled           = optional(bool, true)
    dns_servers                 = optional(list(string), [])
    zones                       = optional(list(string), ["1", "2", "3"])
    aks_egress_source_addresses = optional(list(string), [])
  })
  default = null

  validation {
    condition     = var.firewall == null ? true : contains(["Standard", "Premium"], var.firewall.sku_tier)
    error_message = "firewall.sku_tier must be Standard or Premium. Basic is not supported because it needs a separate management subnet."
  }

  validation {
    condition     = var.firewall == null ? true : contains(["Off", "Alert", "Deny"], var.firewall.threat_intelligence_mode)
    error_message = "firewall.threat_intelligence_mode must be Off, Alert or Deny."
  }

  validation {
    condition     = var.firewall == null ? true : can(cidrhost(var.firewall.subnet_address_prefix, 0))
    error_message = "firewall.subnet_address_prefix must be a valid CIDR block."
  }

  validation {
    condition     = var.firewall == null ? true : alltrue([for c in var.firewall.aks_egress_source_addresses : can(cidrhost(c, 0))])
    error_message = "firewall.aks_egress_source_addresses must be CIDR blocks."
  }
}

variable "bastion" {
  description = "Azure Bastion configuration. Set to null to skip Bastion. `subnet_address_prefix` is the CIDR for `AzureBastionSubnet` (/26 or larger)."
  type = object({
    name                  = string
    public_ip_name        = string
    subnet_address_prefix = string
    sku                   = optional(string, "Standard")
    tunneling_enabled     = optional(bool, true)
    zones                 = optional(list(string), ["1", "2", "3"])
  })
  default = null

  validation {
    condition     = var.bastion == null ? true : contains(["Basic", "Standard", "Premium"], var.bastion.sku)
    error_message = "bastion.sku must be Basic, Standard or Premium."
  }

  validation {
    condition     = var.bastion == null ? true : can(cidrhost(var.bastion.subnet_address_prefix, 0))
    error_message = "bastion.subnet_address_prefix must be a valid CIDR block."
  }
}

variable "private_dns_zones" {
  description = "Private DNS zones to create and link to the hub virtual network (for Private Link and private AKS API servers)."
  type        = list(string)
  default = [
    "privatelink.azurecr.io",
    "privatelink.blob.core.windows.net",
    "privatelink.file.core.windows.net",
    "privatelink.vaultcore.azure.net",
  ]

  validation {
    condition     = alltrue([for z in var.private_dns_zones : can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$", z))])
    error_message = "private_dns_zones must be lowercase DNS zone names."
  }
}

variable "spoke_peerings" {
  description = "Hub-side peerings to spokes that are NOT vended by the lz-vending module (which creates its own hub-side peering). Keyed by a short spoke name."
  type = map(object({
    remote_virtual_network_id = string
    allow_gateway_transit     = optional(bool, false)
  }))
  default = {}

  validation {
    condition     = alltrue([for p in values(var.spoke_peerings) : can(regex("(?i)^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft.Network/virtualNetworks/[^/]+$", p.remote_virtual_network_id))])
    error_message = "remote_virtual_network_id must be a virtual network resource ID."
  }
}

variable "enable_diagnostics" {
  description = "Send hub VNet, firewall and bastion diagnostics to `log_analytics_workspace_id`."
  type        = bool
  default     = false
}

variable "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics workspace used when enable_diagnostics is true."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
