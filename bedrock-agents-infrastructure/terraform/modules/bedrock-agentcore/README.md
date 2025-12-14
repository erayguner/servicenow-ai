# Bedrock AgentCore Module

Terraform module for deploying AWS Bedrock AgentCore resources including
Runtime, Gateway, Memory, and Code Interpreter using the AWSCC provider (AWS
Cloud Control API).

## Overview

This module provides advanced agent capabilities based on patterns from the
[AWS-IA AgentCore Module](https://github.com/aws-ia/terraform-aws-agentcore):

- **Runtime** - Container or code-based agent runtime execution
- **Gateway** - MCP (Model Context Protocol) gateway with JWT/IAM authorization
- **Memory** - Short-term and long-term memory with multiple strategies
- **Code Interpreter** - Sandbox or VPC-based code execution environment

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.11.0 |
| aws | ~> 5.80 |
| awscc | >= 1.66.0 |
| random | >= 3.0 |
| time | >= 0.9 |

## Providers

| Name | Version |
|------|---------|
| aws | ~> 5.80 |
| awscc | >= 1.66.0 |
| random | >= 3.0 |
| time | >= 0.9 |

## Features

### Runtime

- Container-based runtime using ECR images
- Code-based runtime using S3 artifacts
- Configurable network modes (PUBLIC, VPC)
- CloudWatch logging integration

### Gateway

- MCP protocol support with semantic/keyword search
- CUSTOM_JWT or AWS_IAM authorization
- Lambda function target integration
- Cognito User Pool integration for JWT auth

### Memory

- **Semantic Memory** - Vector-based semantic search
- **Summary Memory** - Compressed conversation summaries
- **User Preference Memory** - Track and recall user preferences
- **Custom Memory** - Custom memory strategy implementation

### Code Interpreter

- SANDBOX execution mode (isolated environment)
- VPC execution mode (network access)
- S3 bucket integration for file storage
- CloudWatch logging

## Usage

### Basic Example

```hcl
module "agentcore" {
  source = "./modules/bedrock-agentcore"

  project_name = "my-project"
  environment  = "dev"

  # Enable components
  create_runtime          = false
  create_gateway          = true
  create_memory           = true
  create_code_interpreter = false

  # Gateway Configuration
  gateway_name            = "my-gateway"
  gateway_protocol_type   = "MCP"
  gateway_authorizer_type = "AWS_IAM"

  # Memory Configuration
  memory_name = "my-memory"
  memory_strategies = [
    {
      semantic_memory_strategy = {
        name        = "semantic_memory"
        description = "Semantic memory strategy"
        namespaces  = ["default"]
        model_id    = "anthropic.claude-3-haiku-20240307-v1:0"
      }
      summary_memory_strategy         = null
      user_preference_memory_strategy = null
      custom_memory_strategy          = null
    }
  ]

  tags = {
    Project     = "MyProject"
    Environment = "dev"
  }
}
```

### Full Example with All Components

```hcl
module "agentcore" {
  source = "./modules/bedrock-agentcore"

  project_name = "servicenow-ai"
  environment  = "dev"

  # Runtime Configuration
  create_runtime        = true
  runtime_name          = "servicenow-runtime"
  runtime_description   = "ServiceNow AI agent runtime"
  runtime_artifact_type = "container"
  runtime_container_uri = "123456789012.dkr.ecr.eu-west-2.amazonaws.com/agent:latest"
  runtime_network_mode  = "PUBLIC"

  # Gateway Configuration
  create_gateway           = true
  gateway_name             = "servicenow-gateway"
  gateway_description      = "MCP Gateway for ServiceNow"
  gateway_protocol_type    = "MCP"
  gateway_authorizer_type  = "CUSTOM_JWT"
  gateway_mcp_configuration = {
    instructions       = "Process ServiceNow API requests"
    search_type        = "SEMANTIC"
    supported_versions = ["2024-11-05"]
  }
  gateway_lambda_function_arns = [
    module.servicenow_lambda.function_arn
  ]

  # Memory Configuration
  create_memory      = true
  memory_name        = "servicenow-memory"
  memory_description = "Conversation memory for ServiceNow"
  memory_strategies = [
    {
      semantic_memory_strategy = {
        name        = "servicenow_semantic"
        description = "Semantic memory for ServiceNow"
        namespaces  = ["servicenow"]
        model_id    = "anthropic.claude-3-haiku-20240307-v1:0"
      }
      summary_memory_strategy         = null
      user_preference_memory_strategy = null
      custom_memory_strategy          = null
    }
  ]

  # Code Interpreter Configuration
  create_code_interpreter      = true
  code_interpreter_name        = "servicenow-interpreter"
  code_interpreter_description = "Code interpreter for data analysis"
  code_interpreter_executor    = "SANDBOX"

  # Cognito for JWT Authentication
  create_cognito        = true
  cognito_domain_prefix = "servicenow-ai-dev"

  # Logging
  log_retention_days = 30

  tags = {
    Project     = "ServiceNowAI"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}
```

## Inputs

### General

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_name | Project name for resource naming | `string` | n/a | yes |
| environment | Environment name (dev, staging, prod) | `string` | n/a | yes |
| tags | Additional tags for resources | `map(string)` | `{}` | no |
| log_retention_days | CloudWatch log retention in days | `number` | `30` | no |

### Runtime

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| create_runtime | Create AgentCore Runtime | `bool` | `false` | no |
| runtime_name | Name of the runtime | `string` | `"agentcore-runtime"` | no |
| runtime_description | Description of the runtime | `string` | `""` | no |
| runtime_artifact_type | Artifact type (container or code) | `string` | `"container"` | no |
| runtime_container_uri | Container image URI (required for container type) | `string` | `""` | no |
| runtime_network_mode | Network mode (PUBLIC or VPC) | `string` | `"PUBLIC"` | no |
| runtime_role_arn | Existing IAM role ARN (optional) | `string` | `null` | no |

### Gateway

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| create_gateway | Create AgentCore Gateway | `bool` | `false` | no |
| gateway_name | Name of the gateway | `string` | `"agentcore-gateway"` | no |
| gateway_description | Description of the gateway | `string` | `""` | no |
| gateway_protocol_type | Protocol type (MCP) | `string` | `"MCP"` | no |
| gateway_authorizer_type | Authorizer type (CUSTOM_JWT or AWS_IAM) | `string` | `"AWS_IAM"` | no |
| gateway_mcp_configuration | MCP protocol configuration | `object` | See variables.tf | no |
| gateway_lambda_function_arns | Lambda ARNs for gateway targets | `list(string)` | `[]` | no |
| gateway_kms_key_arn | KMS key ARN for encryption | `string` | `null` | no |
| gateway_role_arn | Existing IAM role ARN (optional) | `string` | `null` | no |

### Memory

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| create_memory | Create AgentCore Memory | `bool` | `false` | no |
| memory_name | Name of the memory | `string` | `"agentcore-memory"` | no |
| memory_description | Description of the memory | `string` | `""` | no |
| memory_strategies | List of memory strategy configurations | `list(object)` | `[]` | no |
| memory_kms_key_arn | KMS key ARN for encryption | `string` | `null` | no |
| memory_role_arn | Existing IAM role ARN (optional) | `string` | `null` | no |

### Code Interpreter

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| create_code_interpreter | Create Code Interpreter | `bool` | `false` | no |
| code_interpreter_name | Name of the code interpreter | `string` | `"agentcore-interpreter"` | no |
| code_interpreter_description | Description | `string` | `""` | no |
| code_interpreter_executor | Executor type (SANDBOX or VPC) | `string` | `"SANDBOX"` | no |
| code_interpreter_role_arn | Existing IAM role ARN (optional) | `string` | `null` | no |

### Cognito

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| create_cognito | Create Cognito User Pool | `bool` | `false` | no |
| cognito_domain_prefix | Cognito domain prefix | `string` | `""` | no |
| cognito_user_pool_discovery_url | External Cognito discovery URL | `string` | `null` | no |
| jwt_allowed_audiences | Allowed JWT audiences | `list(string)` | `[]` | no |
| jwt_allowed_clients | Allowed JWT clients | `list(string)` | `[]` | no |

## Outputs

### Runtime

| Name | Description |
|------|-------------|
| runtime_id | ID of the AgentCore Runtime |
| runtime_arn | ARN of the AgentCore Runtime |
| runtime_role_arn | ARN of the Runtime IAM role |
| runtime_log_group_name | CloudWatch Log Group name |

### Gateway

| Name | Description |
|------|-------------|
| gateway_id | ID of the AgentCore Gateway |
| gateway_arn | ARN of the AgentCore Gateway |
| gateway_url | URL of the AgentCore Gateway |
| gateway_role_arn | ARN of the Gateway IAM role |
| gateway_log_group_name | CloudWatch Log Group name |

### Memory

| Name | Description |
|------|-------------|
| memory_id | ID of the AgentCore Memory |
| memory_arn | ARN of the AgentCore Memory |
| memory_role_arn | ARN of the Memory IAM role |
| memory_log_group_name | CloudWatch Log Group name |

### Code Interpreter

| Name | Description |
|------|-------------|
| code_interpreter_id | ID of the Code Interpreter |
| code_interpreter_arn | ARN of the Code Interpreter |
| code_interpreter_role_arn | ARN of the Code Interpreter IAM role |
| code_interpreter_log_group_name | CloudWatch Log Group name |

### Cognito

| Name | Description |
|------|-------------|
| cognito_user_pool_id | ID of the Cognito User Pool |
| cognito_user_pool_arn | ARN of the Cognito User Pool |
| cognito_user_pool_client_id | ID of the Cognito User Pool Client |
| cognito_discovery_url | OIDC Discovery URL |

### IAM Policy Documents

| Name | Description |
|------|-------------|
| memory_stm_read_policy_json | IAM policy for STM read access |
| memory_stm_write_policy_json | IAM policy for STM write access |
| memory_ltm_read_policy_json | IAM policy for LTM read access |
| memory_ltm_write_policy_json | IAM policy for LTM write access |
| memory_full_access_policy_json | IAM policy for full Memory access |
| code_interpreter_invoke_policy_json | IAM policy for Code Interpreter invoke |

## Known Limitations

1. **Gateway Targets**: The `awscc_bedrockagentcore_gateway_target` resource is
   not yet available in AWSCC provider v1.66.0. Lambda permissions are created
   but targets must be configured manually or via CLI.

2. **Memory Strategy Naming**: Strategy names must match the pattern
   `^[a-zA-Z][a-zA-Z0-9_]{0,47}$`. Hyphens are not allowed.

3. **IAM Role Propagation**: A 20-second delay is added after IAM role creation
   to ensure roles are propagated before dependent resources are created.

## License

This module is provided as-is for use in AWS infrastructure deployments.
