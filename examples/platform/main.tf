# Platform example: governance, management and hub connectivity.
# Deploy this first, then one examples/landing-zone-aks stack per application landing zone.

provider "azurerm" {
  features {}
  subscription_id = var.connectivity_subscription_id
}

module "naming_hub" {
  source = "../../modules/naming"

  prefix      = var.prefix
  workload    = "hub"
  environment = "plat"
  location    = var.location
}

module "naming_mgmt" {
  source = "../../modules/naming"

  prefix      = var.prefix
  workload    = "mgmt"
  environment = "plat"
  location    = var.location
}

module "tags" {
  source = "../../modules/tagging"

  owner               = var.owner
  cost_center         = var.cost_center
  environment         = "plat"
  data_classification = "internal"
}

module "governance" {
  source = "../../modules/governance"

  root_id                  = var.prefix
  root_display_name        = var.organisation_display_name
  allowed_locations        = var.allowed_locations
  mandatory_tag_names      = module.tags.mandatory_tag_names
  policy_identity_location = var.location

  subscription_placement = {
    connectivity = {
      subscription_id  = var.connectivity_subscription_id
      management_group = "connectivity"
    }
  }
}

module "management" {
  source = "../../modules/management"

  location                     = var.location
  resource_group_name          = module.naming_mgmt.names.resource_group
  log_analytics_workspace_name = module.naming_mgmt.names.log_analytics_workspace
  retention_in_days            = 90
  tags                         = module.tags.tags
}

module "connectivity" {
  source = "../../modules/connectivity"

  location             = var.location
  resource_group_name  = module.naming_hub.names.resource_group
  virtual_network_name = module.naming_hub.names.virtual_network
  address_space        = [var.hub_address_space]

  firewall = {
    name                        = module.naming_hub.names.firewall
    policy_name                 = module.naming_hub.names.firewall_policy
    public_ip_name              = "${module.naming_hub.names.public_ip}-afw"
    subnet_address_prefix       = cidrsubnet(var.hub_address_space, 2, 0)
    aks_egress_source_addresses = var.spoke_address_spaces
  }

  bastion = {
    name                  = module.naming_hub.names.bastion_host
    public_ip_name        = "${module.naming_hub.names.public_ip}-bas"
    subnet_address_prefix = cidrsubnet(var.hub_address_space, 2, 1)
  }

  private_dns_zones = [
    "privatelink.${var.location}.azmk8s.io",
    "privatelink.vaultcore.azure.net",
    "privatelink.azurecr.io",
    "privatelink.blob.core.windows.net",
  ]

  enable_diagnostics         = true
  log_analytics_workspace_id = module.management.log_analytics_workspace_id
  tags                       = module.tags.tags
}

# GitHub Actions deploys through OIDC: a user-assigned identity with a federated credential,
# so no client secret ever exists.
module "deploy_identity" {
  source = "../../modules/identity"

  user_assigned_identity = {
    name                = "${module.naming_mgmt.names.user_assigned_identity}-deploy"
    resource_group_name = module.management.resource_group_name
    location            = var.location
  }

  user_assigned_identity_role_assignments = {
    connectivity_contributor = {
      scope                = "/subscriptions/${var.connectivity_subscription_id}"
      role_definition_name = "Contributor"
    }
  }

  federated_identity_credentials = {
    github-main = {
      subject = "repo:${var.github_repository}:ref:refs/heads/main"
    }
    github-pr = {
      subject = "repo:${var.github_repository}:pull_request"
    }
  }

  tags = module.tags.tags
}
