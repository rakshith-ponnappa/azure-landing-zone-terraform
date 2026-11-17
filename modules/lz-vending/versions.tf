terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.65"
      # azurerm      => the landing zone (spoke) subscription
      # azurerm.hub  => the connectivity subscription that owns the hub VNet
      configuration_aliases = [azurerm.hub]
    }
  }
}
