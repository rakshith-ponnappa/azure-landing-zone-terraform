output "tags" {
  description = "Merged tag map (additional tags + mandatory tags) to apply to every resource."
  value       = local.tags
}

output "mandatory_tags" {
  description = "Only the mandatory tags."
  value       = local.mandatory_tags
}

output "mandatory_tag_names" {
  description = "Names of the mandatory tags. Feed this into the governance module so Azure Policy enforces the same contract."
  value       = keys(local.mandatory_tags)
}
