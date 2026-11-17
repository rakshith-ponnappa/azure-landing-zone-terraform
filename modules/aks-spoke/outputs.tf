output "cluster_id" {
  description = "AKS cluster resource ID."
  value       = azurerm_kubernetes_cluster.this.id
}

output "cluster_name" {
  description = "AKS cluster name."
  value       = azurerm_kubernetes_cluster.this.name
}

output "private_fqdn" {
  description = "Private API server FQDN (null for public clusters)."
  value       = azurerm_kubernetes_cluster.this.private_fqdn
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL for workload identity federated credentials."
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "node_resource_group" {
  description = "AKS-managed node resource group."
  value       = azurerm_kubernetes_cluster.this.node_resource_group
}

output "cluster_identity_principal_id" {
  description = "Principal ID of the control-plane user-assigned identity."
  value       = azurerm_user_assigned_identity.cluster.principal_id
}

output "kubelet_identity_object_id" {
  description = "Object ID of the kubelet identity (grant AcrPull to it on your registry)."
  value       = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}

output "user_node_pool_ids" {
  description = "User node pool IDs keyed by pool name."
  value       = { for k, p in azurerm_kubernetes_cluster_node_pool.user : k => p.id }
}
