output "base_name" {
  description = "Name stem without a resource-type abbreviation, e.g. `contoso-hub-prod-eus-001`."
  value       = local.base_name
}

output "region_short" {
  description = "Short code used for the region."
  value       = local.region_short
}

output "abbreviations" {
  description = "Map of resource type => abbreviation used by this module."
  value       = local.abbreviations
}

output "names" {
  description = "Map of resource type => generated name. Storage account, container registry and key vault names respect their stricter length/character rules."
  value       = local.names
}
