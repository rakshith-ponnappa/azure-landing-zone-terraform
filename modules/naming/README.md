# naming

CAF-style name generator: `<abbr>-<prefix>-<workload>-<env>-<region>-<instance>`, with special handling for storage accounts, container registries and key vaults.

## Usage

```hcl
module "naming" {
  source = "../../modules/naming"

  # see Inputs below
}
```

## Resources

- none (pure computation)

## Inputs

| Name | Description | Required |
|---|---|:---:|
| `prefix` | Optional short organisation or estate prefix (lowercase alphanumeric, max 6 chars). Leave empty to omit it from names. | no |
| `workload` | Workload or application short name, e.g. `hub`, `mgmt`, `payments`. Lowercase alphanumeric, 2-12 chars, must start with a letter. | yes |
| `environment` | Environment short code. | yes |
| `location` | Azure region programmatic name, e.g. `eastus` or `uksouth`. | yes |
| `instance` | Instance number used to disambiguate otherwise identical names. Rendered as three digits (1 => 001). | no |
| `region_abbreviation_overrides` | Optional map of region name => short code that overrides or extends the built-in region abbreviations. | no |

## Outputs

| Name | Description |
|---|---|
| `base_name` | Name stem without a resource-type abbreviation, e.g. `contoso-hub-prod-eus-001`. |
| `region_short` | Short code used for the region. |
| `abbreviations` | Map of resource type => abbreviation used by this module. |
| `names` | Map of resource type => generated name. Storage account, container registry and key vault names respect their stricter length/character rules. |
