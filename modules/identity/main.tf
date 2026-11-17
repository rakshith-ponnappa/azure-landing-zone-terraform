resource "azurerm_role_assignment" "this" {
  for_each = var.role_assignments

  scope                = each.value.scope
  principal_id         = each.value.principal_id
  role_definition_name = each.value.role_definition_name
  role_definition_id   = each.value.role_definition_id
  principal_type       = each.value.principal_type
  description          = each.value.description
  condition            = each.value.condition
  condition_version    = each.value.condition_version
}

resource "azurerm_user_assigned_identity" "this" {
  count = var.user_assigned_identity != null ? 1 : 0

  name                = var.user_assigned_identity.name
  resource_group_name = var.user_assigned_identity.resource_group_name
  location            = var.user_assigned_identity.location
  tags                = var.tags
}

resource "azurerm_role_assignment" "user_assigned_identity" {
  for_each = var.user_assigned_identity != null ? var.user_assigned_identity_role_assignments : {}

  scope                = each.value.scope
  role_definition_name = each.value.role_definition_name
  principal_id         = azurerm_user_assigned_identity.this[0].principal_id
  principal_type       = "ServicePrincipal"
  description          = each.value.description
}

resource "azurerm_federated_identity_credential" "this" {
  for_each = var.user_assigned_identity != null ? var.federated_identity_credentials : {}

  name                      = each.key
  user_assigned_identity_id = azurerm_user_assigned_identity.this[0].id
  issuer                    = each.value.issuer
  subject                   = each.value.subject
  audience                  = each.value.audience
}
