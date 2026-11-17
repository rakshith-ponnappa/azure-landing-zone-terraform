locals {
  # Resource-type abbreviations based on the Cloud Adoption Framework recommendations.
  abbreviations = {
    action_group            = "ag"
    automation_account      = "aa"
    bastion_host            = "bas"
    budget                  = "budget"
    container_registry      = "cr"
    diagnostic_setting      = "diag"
    firewall                = "afw"
    firewall_policy         = "afwp"
    key_vault               = "kv"
    kubernetes_cluster      = "aks"
    log_analytics_workspace = "log"
    management_group        = "mg"
    network_interface       = "nic"
    network_security_group  = "nsg"
    node_resource_group     = "rg"
    private_endpoint        = "pep"
    public_ip               = "pip"
    resource_group          = "rg"
    route_table             = "rt"
    storage_account         = "st"
    subnet                  = "snet"
    user_assigned_identity  = "id"
    virtual_machine         = "vm"
    virtual_network         = "vnet"
    virtual_network_peering = "peer"
  }

  default_region_abbreviations = {
    australiaeast      = "aue"
    brazilsouth        = "brs"
    canadacentral      = "cac"
    centralindia       = "inc"
    centralus          = "cus"
    eastasia           = "ea"
    eastus             = "eus"
    eastus2            = "eus2"
    francecentral      = "frc"
    germanywestcentral = "gwc"
    japaneast          = "jpe"
    northcentralus     = "ncus"
    northeurope        = "neu"
    norwayeast         = "nwe"
    southcentralus     = "scus"
    southeastasia      = "sea"
    swedencentral      = "sdc"
    switzerlandnorth   = "chn"
    uksouth            = "uks"
    ukwest             = "ukw"
    westeurope         = "weu"
    westus             = "wus"
    westus2            = "wus2"
    westus3            = "wus3"
  }

  region_abbreviations = merge(local.default_region_abbreviations, var.region_abbreviation_overrides)
  region_short         = lookup(local.region_abbreviations, var.location, var.location)
  instance             = format("%03d", var.instance)

  # <prefix>-<workload>-<env>-<region>-<instance>; the prefix is dropped when empty.
  base_parts = compact([var.prefix, var.workload, var.environment, local.region_short, local.instance])
  base_name  = join("-", local.base_parts)

  standard_names = {
    for type, abbr in local.abbreviations : type => "${abbr}-${local.base_name}"
  }

  # Resources with tighter naming rules.
  storage_account_name    = substr(replace("st${join("", local.base_parts)}", "/[^a-z0-9]/", ""), 0, 24)
  container_registry_name = substr(replace("cr${join("", local.base_parts)}", "/[^a-z0-9]/", ""), 0, 50)
  key_vault_name          = trim(substr("kv-${local.base_name}", 0, 24), "-")
  node_resource_group     = "rg-${local.base_name}-aksnodes"

  names = merge(local.standard_names, {
    container_registry  = local.container_registry_name
    key_vault           = local.key_vault_name
    node_resource_group = local.node_resource_group
    storage_account     = local.storage_account_name
  })
}
