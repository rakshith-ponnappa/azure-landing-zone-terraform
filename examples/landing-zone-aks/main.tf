# Application landing zone with a private AKS cluster, peered to the platform hub.
# Inputs come from the platform example's outputs (pass them in tfvars or via remote state).

provider "azurerm" {
  features {}
  subscription_id = var.landing_zone_subscription_id
}

provider "azurerm" {
  alias = "hub"
  features {}
  subscription_id = var.connectivity_subscription_id
}

module "naming" {
  source = "../../modules/naming"

  prefix      = var.prefix
  workload    = var.workload
  environment = var.environment
  location    = var.location
}

module "tags" {
  source = "../../modules/tagging"

  owner               = var.owner
  cost_center         = var.cost_center
  environment         = var.environment
  data_classification = "confidential"
  additional_tags     = { workload = var.workload }
}

module "landing_zone" {
  source = "../../modules/lz-vending"

  providers = {
    azurerm     = azurerm
    azurerm.hub = azurerm.hub
  }

  location                    = var.location
  subscription_id             = var.landing_zone_subscription_id
  management_group_id         = var.management_group_id
  network_resource_group_name = "${module.naming.names.resource_group}-network"

  resource_groups = {
    workload = { name = module.naming.names.resource_group }
  }

  virtual_network = {
    name          = module.naming.names.virtual_network
    address_space = [var.spoke_address_space]
    dns_servers   = [var.firewall_private_ip]
    subnets = {
      snet-aks-nodes = { address_prefixes = [cidrsubnet(var.spoke_address_space, 1, 0)] }
      snet-private-endpoints = {
        address_prefixes                  = [cidrsubnet(var.spoke_address_space, 3, 4)]
        private_endpoint_network_policies = "NetworkSecurityGroupEnabled"
      }
    }
  }

  hub_peering = {
    hub_virtual_network_id = var.hub_virtual_network_id
  }

  route_table = {
    name                = module.naming.names.route_table
    firewall_private_ip = var.firewall_private_ip
  }

  budget = {
    name           = module.naming.names.budget
    amount         = var.monthly_budget
    contact_emails = var.budget_contact_emails
  }

  app_team_role_assignments = {
    app-team-contributor = {
      principal_id         = var.app_team_group_object_id
      role_definition_name = "Contributor"
      resource_group_key   = "workload"
    }
  }

  tags = module.tags.tags
}

module "aks" {
  source = "../../modules/aks-spoke"

  name                     = module.naming.names.kubernetes_cluster
  location                 = var.location
  resource_group_name      = module.landing_zone.resource_group_names["workload"]
  node_resource_group_name = module.naming.names.node_resource_group
  subnet_id                = module.landing_zone.subnet_ids["snet-aks-nodes"]
  network_role_scope_ids   = [module.landing_zone.route_table_id]

  private_cluster = {
    private_dns_zone_id = var.aks_private_dns_zone_id
  }

  network = {
    outbound_type = "userDefinedRouting"
  }

  user_node_pools = {
    apps = { vm_size = "Standard_D4ds_v5", min_count = 1, max_count = 5 }
  }

  admin_group_object_ids     = var.cluster_admin_group_object_ids
  log_analytics_workspace_id = var.log_analytics_workspace_id
  tags                       = module.tags.tags
}
