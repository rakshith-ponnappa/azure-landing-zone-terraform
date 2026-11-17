# tagging

Builds the mandatory tag set (owner, cost-center, environment, data-classification, managed-by) and merges optional extra tags. Pair it with the governance module's require-tag policies.

## Usage

```hcl
module "tagging" {
  source = "../../modules/tagging"

  # see Inputs below
}
```

## Resources

- none (pure computation)

## Inputs

| Name | Description | Required |
|---|---|:---:|
| `owner` | Accountable owner of the resources. Use a team mailbox or distribution list, not an individual. | yes |
| `cost_center` | Cost centre or charge code used for showback/chargeback. | yes |
| `environment` | Environment the resources belong to. | yes |
| `data_classification` | Highest classification of data stored or processed by the resources. | yes |
| `managed_by` | Tool or process that manages the resources. Changing this away from `terraform` is a signal that drift is expected. | no |
| `additional_tags` | Optional extra tags. Mandatory tags always win if a key collides. | no |

## Outputs

| Name | Description |
|---|---|
| `tags` | Merged tag map (additional tags + mandatory tags) to apply to every resource. |
| `mandatory_tags` | Only the mandatory tags. |
| `mandatory_tag_names` | Names of the mandatory tags. Feed this into the governance module so Azure Policy enforces the same contract. |
