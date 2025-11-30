# Terraform Native Testing Guide for Bedrock Modules

## Overview

This repository now includes comprehensive Terraform native test files
(tftest.hcl) for all 16 modules using Terraform 1.6+ testing framework.

## Test Structure

Each module includes 4 comprehensive test files:

1. **basic.tftest.hcl** - Tests basic functionality and resource creation
2. **advanced.tftest.hcl** - Tests advanced features and configurations
3. **integration.tftest.hcl** - Tests module interactions and integrations
4. **validation.tftest.hcl** - Tests output validation and data integrity

## Modules with Tests (16 total)

### Core Bedrock Modules (4)

- ✅ bedrock-agent (4 test files)
- ✅ bedrock-knowledge-base (4 test files)
- ✅ bedrock-action-group (4 test files)
- ✅ bedrock-orchestration (4 test files)

### Security Modules (6)

- ✅ security/bedrock-security-iam (4 test files)
- ✅ security/bedrock-security-kms (4 test files)
- ✅ security/bedrock-security-guardduty (4 test files)
- ✅ security/bedrock-security-hub (4 test files)
- ✅ security/bedrock-security-waf (4 test files)
- ✅ security/bedrock-security-secrets (4 test files)

### Monitoring Modules (6)

- ✅ monitoring/bedrock-monitoring-cloudwatch (4 test files)
- ✅ monitoring/bedrock-monitoring-cloudtrail (4 test files)
- ✅ monitoring/bedrock-monitoring-config (4 test files)
- ✅ monitoring/bedrock-monitoring-eventbridge (4 test files)
- ✅ monitoring/bedrock-monitoring-synthetics (4 test files)
- ✅ monitoring/bedrock-monitoring-xray (4 test files)

## Total Test Files Created: 64

## Running Tests

### Run all tests for a module

```bash
cd bedrock-agents-infrastructure/terraform/modules/bedrock-agent
terraform test
```

### Run a specific test file

```bash
terraform test -test-directory=tests tests/basic.tftest.hcl
```

### Run tests with verbose output

```bash
terraform test -verbose
```

### Run only plan tests (no apply)

```bash
terraform test -filter="command=plan"
```

## Test Features

### Basic Tests

- Resource creation verification
- Default value validation
- Required resource existence
- Basic IAM permissions
- Tag validation

### Advanced Tests

- Multi-resource scenarios
- Complex configurations
- Encryption settings
- VPC integration
- Custom policies
- Performance settings

### Integration Tests

- Cross-module dependencies
- Service integrations (S3, DynamoDB, SNS, etc.)
- IAM permission chains
- Event routing
- Data flow validation

### Validation Tests

- Output value verification
- ARN format validation
- Resource naming conventions
- Type checking
- Null value handling

## Test Coverage

Each module tests:

- ✅ Resource creation
- ✅ Configuration options
- ✅ IAM permissions
- ✅ Encryption settings
- ✅ Integration points
- ✅ Output values
- ✅ Error handling
- ✅ Dependencies

## Examples

### bedrock-agent Module Tests

**Basic Test Example:**

```hcl
run "verify_agent_creation" {
  command = plan

  assert {
    condition     = aws_bedrockagent_agent.this.agent_name == "test-bedrock-agent"
    error_message = "Agent name does not match expected value"
  }
}
```

**Advanced Test Example:**

```hcl
run "verify_knowledge_base_association" {
  command = plan

  assert {
    condition     = length(aws_bedrockagent_agent_knowledge_base_association.this) == 1
    error_message = "Should create one knowledge base association"
  }
}
```

### Security IAM Module Tests

**Permission Validation:**

```hcl
run "verify_bedrock_permissions" {
  command = plan

  assert {
    condition     = can(regex("bedrock:InvokeModel", data.aws_iam_policy_document.bedrock_agent_base.json))
    error_message = "Should have Bedrock model invocation permissions"
  }
}
```

### Monitoring CloudWatch Module Tests

**Alarm Creation:**

```hcl
run "verify_bedrock_invocation_errors_alarm" {
  command = plan

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.bedrock_invocation_errors) == 1
    error_message = "Bedrock invocation errors alarm should be created"
  }
}
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Terraform Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: '1.6.0'

      - name: Run Terraform Tests
        run: |
          cd bedrock-agents-infrastructure/terraform/modules
          for module in */; do
            echo "Testing $module"
            cd "$module"
            terraform init
            terraform test
            cd ..
          done
```

## Best Practices

1. **Always run plan tests first** - They don't create real resources
2. **Use mock data** - Test files use realistic but fake ARNs and IDs
3. **Test incrementally** - Start with basic tests, then advanced
4. **Validate outputs** - Every module should validate its outputs
5. **Check error messages** - Ensure assertions have clear error messages

## Troubleshooting

### Common Issues

**Issue: Test fails with "resource not found"**

- Solution: Ensure you're using `command = plan` for tests that don't create
  resources

**Issue: Variable validation errors**

- Solution: Check that test variables match module variable definitions

**Issue: Assert condition fails**

- Solution: Use `can()` function for optional attributes

## Next Steps

1. Run tests locally before committing
2. Add tests to CI/CD pipeline
3. Update tests when module changes
4. Add more test scenarios as needed
5. Monitor test coverage metrics

## Resources

- [Terraform Testing Documentation](https://developer.hashicorp.com/terraform/language/tests)
- [Terraform 1.6+ Test Framework](https://developer.hashicorp.com/terraform/language/v1.6.x/tests)
- [Assert Functions](https://developer.hashicorp.com/terraform/language/expressions/function-calls)

## Support

For issues or questions:

1. Check test error messages
2. Review module documentation
3. Validate test variable values
4. Ensure Terraform version >= 1.6.0
