variable "name" {
  description = "AKS cluster name (e.g. the naming module's names.kubernetes_cluster)."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9_-]{0,61}[A-Za-z0-9]$", var.name))
    error_message = "name must be 2-63 characters of letters, digits, '-' or '_' and start and end alphanumeric."
  }
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Existing resource group for the cluster (e.g. a workload group created by lz-vending)."
  type        = string
}

variable "node_resource_group_name" {
  description = "Name of the AKS-managed node resource group. Null lets AKS choose."
  type        = string
  default     = null
}

variable "kubernetes_version" {
  description = "Kubernetes version (minor, e.g. \"1.33\"). Null uses the AKS default. Patch upgrades follow automatic_upgrade_channel."
  type        = string
  default     = null
}

variable "sku_tier" {
  description = "AKS control-plane tier: Free (dev only), Standard (uptime SLA) or Premium (LTS)."
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.sku_tier)
    error_message = "sku_tier must be Free, Standard or Premium."
  }
}

variable "subnet_id" {
  description = "Spoke subnet for the node pools (e.g. lz-vending's subnet_ids[\"snet-aks-nodes\"])."
  type        = string

  validation {
    condition     = can(regex("(?i)^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft.Network/virtualNetworks/[^/]+/subnets/[^/]+$", var.subnet_id))
    error_message = "subnet_id must be a subnet resource ID."
  }
}

variable "private_cluster" {
  description = <<-EOT
    Private API server settings.
    - `enabled` keeps the API server off the internet (private endpoint in the node subnet).
    - `private_dns_zone_id` is "System" (AKS-managed zone), "None", or the ID of a central
      privatelink.<region>.azmk8s.io zone in the hub. A custom zone ID gets the Private DNS Zone
      Contributor role for the cluster identity.
  EOT
  type = object({
    enabled             = optional(bool, true)
    private_dns_zone_id = optional(string, "System")
    public_fqdn_enabled = optional(bool, false)
  })
  default = {}
}

variable "network" {
  description = <<-EOT
    Azure CNI Overlay networking. Pods get addresses from `pod_cidr`, which never touches the VNet,
    so spokes stay small. `outbound_type = "userDefinedRouting"` sends egress through the hub firewall
    via the subnet's route table (the lz-vending route_table input).
  EOT
  type = object({
    pod_cidr           = optional(string, "192.168.0.0/16")
    service_cidr       = optional(string, "172.16.0.0/16")
    dns_service_ip     = optional(string, "172.16.0.10")
    network_data_plane = optional(string, "cilium")
    network_policy     = optional(string, "cilium")
    outbound_type      = optional(string, "userDefinedRouting")
  })
  default = {}

  validation {
    condition     = contains(["loadBalancer", "userDefinedRouting", "managedNATGateway", "userAssignedNATGateway"], var.network.outbound_type)
    error_message = "network.outbound_type must be loadBalancer, userDefinedRouting, managedNATGateway or userAssignedNATGateway."
  }

  validation {
    condition     = contains(["azure", "cilium"], var.network.network_data_plane)
    error_message = "network.network_data_plane must be azure or cilium."
  }

  validation {
    condition     = var.network.network_data_plane != "cilium" || var.network.network_policy == "cilium"
    error_message = "The cilium data plane requires network.network_policy = \"cilium\"."
  }

  validation {
    condition     = can(cidrhost(var.network.pod_cidr, 0)) && can(cidrhost(var.network.service_cidr, 0))
    error_message = "network.pod_cidr and network.service_cidr must be valid CIDR blocks."
  }
}

variable "system_node_pool" {
  description = "System node pool (critical add-ons only). Autoscaling is always on."
  type = object({
    name      = optional(string, "system")
    vm_size   = optional(string, "Standard_D4ds_v5")
    min_count = optional(number, 2)
    max_count = optional(number, 4)
    max_pods  = optional(number, 110)
    zones     = optional(list(string), ["1", "2", "3"])
  })
  default = {}

  validation {
    condition     = var.system_node_pool.min_count >= 1 && var.system_node_pool.max_count >= var.system_node_pool.min_count
    error_message = "system_node_pool needs min_count >= 1 and max_count >= min_count."
  }

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{0,11}$", var.system_node_pool.name))
    error_message = "Node pool names must be 1-12 lowercase letters or digits and start with a letter."
  }
}

variable "user_node_pools" {
  description = "Additional user node pools keyed by pool name (1-12 lowercase alphanumerics)."
  type = map(object({
    vm_size     = string
    min_count   = optional(number, 1)
    max_count   = optional(number, 3)
    max_pods    = optional(number, 110)
    zones       = optional(list(string), ["1", "2", "3"])
    node_labels = optional(map(string), {})
    node_taints = optional(list(string), [])
    os_sku      = optional(string, "AzureLinux")
  }))
  default = {}

  validation {
    condition     = alltrue([for k in keys(var.user_node_pools) : can(regex("^[a-z][a-z0-9]{0,11}$", k))])
    error_message = "user_node_pools keys must be 1-12 lowercase letters or digits and start with a letter."
  }
}

variable "admin_group_object_ids" {
  description = "Microsoft Entra group object IDs granted cluster-admin through Azure RBAC for Kubernetes."
  type        = list(string)
  default     = []
}

variable "automatic_upgrade_channel" {
  description = "Cluster auto-upgrade channel: none, patch, stable, rapid or node-image."
  type        = string
  default     = "patch"

  validation {
    condition     = contains(["none", "patch", "stable", "rapid", "node-image"], var.automatic_upgrade_channel)
    error_message = "automatic_upgrade_channel must be none, patch, stable, rapid or node-image."
  }
}

variable "node_os_upgrade_channel" {
  description = "Node OS upgrade channel: None, Unmanaged, SecurityPatch or NodeImage."
  type        = string
  default     = "NodeImage"

  validation {
    condition     = contains(["None", "Unmanaged", "SecurityPatch", "NodeImage"], var.node_os_upgrade_channel)
    error_message = "node_os_upgrade_channel must be None, Unmanaged, SecurityPatch or NodeImage."
  }
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace for Container Insights and control-plane diagnostics. Null disables both."
  type        = string
  default     = null
}

variable "diagnostic_log_categories" {
  description = "Control-plane log categories sent to Log Analytics. kube-audit-admin avoids the volume of kube-audit."
  type        = list(string)
  default     = ["kube-apiserver", "kube-audit-admin", "kube-controller-manager", "cluster-autoscaler", "guard"]
}

variable "network_role_scope_ids" {
  description = "Extra scopes (e.g. the spoke route table) where the cluster identity gets Network Contributor. The node subnet is always included."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to every resource (use the tagging module output)."
  type        = map(string)
  default     = {}
}
