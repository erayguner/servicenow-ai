# Common Terraform Configuration Files

This directory contains shared Terraform configuration files used across all Bedrock infrastructure modules.

## Files

### Version Constraint Files

1. **versions-standard.tf**
   - Standard version constraints for most modules
   - Includes: Terraform >= 1.11.0, AWS provider ~> 5.80
   - Used by: All core bedrock and monitoring modules

2. **versions-with-archive.tf**
   - Includes archive and local providers
   - Used by: bedrock-action-group, monitoring-synthetics

3. **versions-with-extras.tf**
   - Includes random and null providers
   - Used by: bedrock-servicenow

### Configuration Templates

4. **backend-template.tf**
   - Template for S3 backend configuration
   - Customizable for each environment (dev/staging/prod)

## Usage

### For Module Development

When creating a new module, copy the appropriate versions file:

```bash
# For standard modules
cp common/versions-standard.tf modules/your-module/versions.tf

# For modules needing archive/local providers
cp common/versions-with-archive.tf modules/your-module/versions.tf
```

### Maintaining Consistency

All modules should use consistent version constraints. If updating versions:

1. Update the common version files first
2. Propagate changes to all modules
3. Test in dev environment before applying to staging/prod

## Version Standardization

All modules have been standardized to use:
- Terraform: `>= 1.11.0`
- AWS Provider: `~> 5.80` (consistent across all modules)

Previous inconsistencies (some using `>= 5.80.0`) have been resolved.
