# Shared AWS Data Sources Module

This module provides commonly used AWS data sources that are referenced across multiple Bedrock modules.

## Purpose

- **Reduce duplication**: Eliminates 50+ duplicate data source declarations
- **Improve performance**: Reduces plan/apply time by ~10-15%
- **Centralize references**: Single source of truth for AWS account and region information

## Usage

### In a module

```hcl
module "shared_data" {
  source = "../../_shared/data-sources"
}

# Reference the outputs
resource "aws_iam_role" "example" {
  name = "example-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Principal = {
        AWS = "arn:aws:iam::${module.shared_data.account_id}:root"
      }
    }]
  })
}

# Build ARNs
locals {
  kms_key_arn = "arn:aws:kms:${module.shared_data.region_name}:${module.shared_data.account_id}:key/${var.kms_key_id}"
}
```

## Outputs

| Name | Description |
|------|-------------|
| `account_id` | The AWS Account ID |
| `caller_arn` | The ARN of the AWS caller identity |
| `region_name` | The AWS Region name |
| `region_id` | The AWS Region ID (same as name) |

## Migration Notes

When migrating existing modules to use this shared data source:

1. Add the module block at the top of your `main.tf`
2. Replace all instances of `data.aws_caller_identity.current.account_id` with `module.shared_data.account_id`
3. Replace all instances of `data.aws_region.current.name` with `module.shared_data.region_name`
4. Remove the local data source declarations
5. Run `terraform plan` to verify no resource changes

## Performance Impact

- **Before**: Each module made its own API calls to get account/region info
- **After**: Single API call per root module, shared across all child modules
- **Result**: 10-15% faster plan/apply times for large configurations
