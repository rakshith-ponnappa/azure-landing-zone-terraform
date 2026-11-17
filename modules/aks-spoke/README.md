# aks-spoke

Private AKS cluster for a spoke: Azure CNI Overlay with Cilium, user-defined routing through the hub firewall, Entra ID-only access with Azure RBAC, workload identity, the Azure Policy add-on, Container Insights and control-plane diagnostics.

## Usage

```hcl
module "aks_spoke" {
  source = "../../modules/aks-spoke"

  # see Inputs below
}
```

## Resources

- `azurerm_kubernetes_cluster`
- `azurerm_kubernetes_cluster_node_pool`
- `azurerm_monitor_diagnostic_setting`
- `azurerm_role_assignment`
- `azurerm_user_assigned_identity`

## Inputs

| Name | Description | Required |
|---|---|:---:|
| `name` | AKS cluster name (e.g. the naming module's names.kubernetes_cluster). | yes |
| `location` | Azure region. | yes |
| `resource_group_name` | Existing resource group for the cluster (e.g. a workload group created by lz-vending). | yes |
| `node_resource_group_name` | Name of the AKS-managed node resource group. Null lets AKS choose. | no |
| `kubernetes_version` | Kubernetes version (minor, e.g. "1.33"). Null uses the AKS default. Patch upgrades follow automatic_upgrade_channel. | no |
| `sku_tier` | AKS control-plane tier: Free (dev only), Standard (uptime SLA) or Premium (LTS). | no |
| `subnet_id` | Spoke subnet for the node pools (e.g. lz-vending's subnet_ids["snet-aks-nodes"]). | yes |
| `private_cluster` | Private API server settings. - `enabled` keeps the API server off the internet (private endpoint in the node subnet). - `private_dns_zone_id` is "System" (AKS-managed zone), "None", or the ID of a central privatelink.<region>.azmk8s.io zone in the hub. A custom zone ID gets the Private DNS Zone Contributor role for the cluster identity. | no |
| `network` | Azure CNI Overlay networking. Pods get addresses from `pod_cidr`, which never touches the VNet, so spokes stay small. `outbound_type = "userDefinedRouting"` sends egress through the hub firewall via the subnet's route table (the lz-vending route_table input). | no |
| `system_node_pool` | System node pool (critical add-ons only). Autoscaling is always on. | no |
| `user_node_pools` | Additional user node pools keyed by pool name (1-12 lowercase alphanumerics). | no |
| `admin_group_object_ids` | Microsoft Entra group object IDs granted cluster-admin through Azure RBAC for Kubernetes. | no |
| `automatic_upgrade_channel` | Cluster auto-upgrade channel: none, patch, stable, rapid or node-image. | no |
| `node_os_upgrade_channel` | Node OS upgrade channel: None, Unmanaged, SecurityPatch or NodeImage. | no |
| `log_analytics_workspace_id` | Log Analytics workspace for Container Insights and control-plane diagnostics. Null disables both. | no |
| `diagnostic_log_categories` | Control-plane log categories sent to Log Analytics. kube-audit-admin avoids the volume of kube-audit. | no |
| `network_role_scope_ids` | Extra scopes (e.g. the spoke route table) where the cluster identity gets Network Contributor. The node subnet is always included. | no |
| `tags` | Tags applied to every resource (use the tagging module output). | no |

## Outputs

| Name | Description |
|---|---|
| `cluster_id` | AKS cluster resource ID. |
| `cluster_name` | AKS cluster name. |
| `private_fqdn` | Private API server FQDN (null for public clusters). |
| `oidc_issuer_url` | OIDC issuer URL for workload identity federated credentials. |
| `node_resource_group` | AKS-managed node resource group. |
| `cluster_identity_principal_id` | Principal ID of the control-plane user-assigned identity. |
| `kubelet_identity_object_id` | Object ID of the kubelet identity (grant AcrPull to it on your registry). |
| `user_node_pool_ids` | User node pool IDs keyed by pool name. |
