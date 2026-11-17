locals {
  mandatory_tags = {
    "owner"               = var.owner
    "cost-center"         = var.cost_center
    "environment"         = var.environment
    "data-classification" = var.data_classification
    "managed-by"          = var.managed_by
  }

  tags = merge(var.additional_tags, local.mandatory_tags)
}
