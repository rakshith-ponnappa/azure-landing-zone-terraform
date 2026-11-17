output "spoke_virtual_network_id" {
  description = "Spoke VNet ID."
  value       = module.landing_zone.virtual_network_id
}

output "aks_cluster_name" {
  description = "AKS cluster name."
  value       = module.aks.cluster_name
}

output "aks_private_fqdn" {
  description = "Private API server FQDN (reach it from the hub via Bastion or a self-hosted runner)."
  value       = module.aks.private_fqdn
}

output "aks_oidc_issuer_url" {
  description = "OIDC issuer for workload identity federated credentials."
  value       = module.aks.oidc_issuer_url
}
