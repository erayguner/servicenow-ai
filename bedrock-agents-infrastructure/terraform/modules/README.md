# Amazon Bedrock Agents Terraform Modules

Comprehensive Terraform modules for deploying and managing Amazon Bedrock Agents
infrastructure with knowledge bases, action groups, and orchestration
capabilities.

## Overview

This collection provides production-ready Terraform modules for:

- **Bedrock Agents** - Claude 3.5 Sonnet/Haiku agents with full configuration
- **Knowledge Bases** - OpenSearch Serverless with S3 storage and Titan
  Embeddings V2
- **Action Groups** - Lambda-backed custom actions with API schemas
- **Orchestration** - Step Functions workflows for multi-agent coordination
- **AgentCore** - Advanced agent capabilities with Runtime, Gateway, Memory, and
  Code Interpreter

## Modules

### 1. bedrock-agent

Creates a fully configured Bedrock agent with IAM roles, aliases, and
integrations.

**Features:**

- Claude 3.5 Sonnet or Haiku model selection
- Customizable instructions and prompts
- Knowledge base associations
- Action group integrations
- Agent aliases for versioning
- CloudWatch logging
- KMS encryption support
- Guardrail configuration

**Example Usage:**

```hcl
module "customer_support_agent" {
  source = "./modules/bedrock-agent"

  agent_name    = "customer-support-agent"
  description   = "AI agent for customer support inquiries"
  model_id      = "anthropic.claude-3-5-sonnet-20241022-v2:0"

  instruction = <<-EOT
    You are a helpful customer support agent. Analyze customer inquiries and provide
    accurate, friendly responses. Use the knowledge base to find relevant product
    information and troubleshooting steps.
  EOT

  knowledge_bases = [
    {
      knowledge_base_id = module.product_kb.knowledge_base_id
      description       = "Product documentation and FAQs"
    }
  ]

  action_groups = [
    {
      action_group_name = "ticket-management"
      description       = "Create and update support tickets"
      lambda_arn        = module.ticket_actions.lambda_function_arn
      api_schema        = file("${path.module}/schemas/ticket-api.json")
      enabled           = true
    }
  ]

  agent_aliases = {
    production = {
      description = "Production alias"
      tags        = { Environment = "prod" }
    }
    staging = {
      description = "Staging alias"
      tags        = { Environment = "staging" }
    }
  }

  tags = {
    Project     = "CustomerSupport"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}
```

**Key Outputs:**

- `agent_id` - Agent identifier
- `agent_arn` - Agent ARN
- `agent_aliases` - Map of alias names to details
- `agent_role_arn` - IAM role ARN

### 2. bedrock-knowledge-base

Creates an OpenSearch Serverless-backed knowledge base with S3 document storage.

**Features:**

- OpenSearch Serverless collection with encryption
- S3 bucket with versioning and encryption
- Titan Embeddings V2 (256, 512, or 1024 dimensions)
- Configurable chunking strategies
- Data source management
- IAM roles and policies
- VPC configuration support

**Example Usage:**

```hcl
module "product_documentation_kb" {
  source = "./modules/bedrock-knowledge-base"

  knowledge_base_name = "product-documentation"
  description         = "Product documentation and user guides"

  # Embedding configuration
  embedding_model_id  = "amazon.titan-embed-text-v2:0"
  vector_dimension    = 1024
  normalize_embeddings = true

  # OpenSearch configuration
  opensearch_collection_name = "product-docs-collection"
  opensearch_index_name      = "product-docs-index"
  standby_replicas          = "ENABLED"

  # S3 configuration
  create_s3_bucket            = true
  s3_bucket_name              = "product-docs-bucket-${data.aws_caller_identity.current.account_id}"
  s3_bucket_prefix            = "documents/"
  enable_versioning           = true
  enable_server_side_encryption = true

  # Chunking strategy
  chunking_strategy    = "FIXED_SIZE"
  max_tokens          = 300
  overlap_percentage  = 20

  # Data management
  data_deletion_policy = "RETAIN"

  tags = {
    Project     = "ProductDocs"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}
```

**Key Outputs:**

- `knowledge_base_id` - Knowledge base identifier
- `knowledge_base_arn` - Knowledge base ARN
- `opensearch_collection_endpoint` - Collection endpoint
- `s3_bucket_name` - Document storage bucket

### 3. bedrock-action-group

Creates Lambda-backed action groups for custom agent capabilities.

**Features:**

- Lambda function creation with configurable runtime
- Inline or file-based source code
- OpenAPI schema support
- VPC configuration
- CloudWatch Insights integration
- X-Ray tracing
- Environment variables and layers
- Bedrock invoke permissions

**Example Usage:**

```hcl
module "database_actions" {
  source = "./modules/bedrock-action-group"

  action_group_name    = "database-query-actions"
  description          = "Execute database queries for the agent"
  lambda_function_name = "bedrock-db-query-handler"

  # Lambda configuration
  lambda_runtime     = "python3.12"
  lambda_handler     = "handler.lambda_handler"
  lambda_timeout     = 60
  lambda_memory_size = 512

  # Source code (inline example)
  lambda_source_code_inline = <<-PYTHON
    import json
    import boto3

    def lambda_handler(event, context):
        # Parse agent action group request
        action = event.get('actionGroup')
        api_path = event.get('apiPath')
        parameters = event.get('parameters', [])

        # Execute database query
        # ... your database logic here ...

        # Return response in Bedrock format
        return {
            'messageVersion': '1.0',
            'response': {
                'actionGroup': action,
                'apiPath': api_path,
                'httpMethod': 'POST',
                'httpStatusCode': 200,
                'responseBody': {
                    'application/json': {
                        'body': json.dumps({
                            'result': 'Query executed successfully'
                        })
                    }
                }
            }
        }
  PYTHON

  # API Schema
  api_schema = jsonencode({
    openapi = "3.0.0"
    info = {
      title   = "Database Query API"
      version = "1.0.0"
    }
    paths = {
      "/query" = {
        post = {
          summary     = "Execute database query"
          description = "Execute a SQL query and return results"
          operationId = "executeQuery"
          requestBody = {
            required = true
            content = {
              "application/json" = {
                schema = {
                  type = "object"
                  properties = {
                    query = {
                      type        = "string"
                      description = "SQL query to execute"
                    }
                  }
                  required = ["query"]
                }
              }
            }
          }
          responses = {
            "200" = {
              description = "Successful query execution"
              content = {
                "application/json" = {
                  schema = {
                    type = "object"
                    properties = {
                      result = {
                        type        = "string"
                        description = "Query results"
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  })

  # Lambda features
  enable_lambda_insights = true
  enable_xray_tracing   = true

  lambda_environment_variables = {
    DB_HOST     = "database.example.com"
    DB_NAME     = "production"
    LOG_LEVEL   = "INFO"
  }

  tags = {
    Project     = "BedrockAgents"
    Component   = "ActionGroup"
    ManagedBy   = "Terraform"
  }
}
```

**Key Outputs:**

- `lambda_function_arn` - Lambda ARN for agent association
- `lambda_function_name` - Function name
- `api_schema` - OpenAPI schema (sensitive)

### 4. bedrock-orchestration

Creates Step Functions state machines for multi-agent orchestration with
DynamoDB state management.

**Features:**

- Multiple orchestration patterns (sequential, parallel, choice, map)
- DynamoDB state tracking
- EventBridge triggers
- SNS notifications
- CloudWatch logging
- X-Ray tracing
- Configurable error handling
- KMS encryption

**Example Usage:**

```hcl
module "customer_workflow" {
  source = "./modules/bedrock-orchestration"

  orchestration_name = "customer-inquiry-workflow"
  description        = "Multi-agent workflow for customer inquiries"

  # Agent configuration
  agent_arns = [
    module.triage_agent.agent_arn,
    module.support_agent.agent_arn,
    module.escalation_agent.agent_arn
  ]

  agent_aliases = {
    (module.triage_agent.agent_arn)      = module.triage_agent.agent_aliases["production"].agent_alias_id
    (module.support_agent.agent_arn)     = module.support_agent.agent_aliases["production"].agent_alias_id
    (module.escalation_agent.agent_arn)  = module.escalation_agent.agent_aliases["production"].agent_alias_id
  }

  # Orchestration pattern
  orchestration_pattern    = "sequential"  # Options: sequential, parallel, choice, map
  error_handling_strategy  = "retry"       # Options: retry, catch, fail
  max_retry_attempts       = 3
  timeout_seconds         = 300

  # State machine configuration
  state_machine_type = "STANDARD"  # or "EXPRESS"
  use_default_definition = true     # Use built-in pattern template

  # DynamoDB state management
  create_dynamodb_table    = true
  dynamodb_table_name      = "customer-workflow-state"
  dynamodb_billing_mode    = "PAY_PER_REQUEST"
  enable_point_in_time_recovery = true

  # Observability
  enable_logging      = true
  log_level          = "ERROR"
  enable_xray_tracing = true

  # EventBridge trigger
  enable_eventbridge_trigger = true
  eventbridge_schedule_expression = "rate(5 minutes)"

  # SNS notifications
  enable_sns_notifications = true
  sns_topic_name          = "customer-workflow-notifications"
  sns_email_subscriptions = ["team@example.com"]

  tags = {
    Project     = "CustomerSupport"
    Workflow    = "MultiAgent"
    ManagedBy   = "Terraform"
  }
}
```

**Orchestration Patterns:**

1. **Sequential** - Agents execute one after another
2. **Parallel** - All agents execute simultaneously
3. **Choice** - Conditional routing based on input/state
4. **Map** - Batch processing across multiple items

**Key Outputs:**

- `state_machine_arn` - State machine ARN
- `dynamodb_table_name` - State storage table
- `sns_topic_arn` - Notification topic

### 5. bedrock-agentcore

Creates advanced Bedrock AgentCore resources including Runtime, Gateway, Memory,
and Code Interpreter using the AWSCC provider (AWS Cloud Control API).

**Features:**

- AgentCore Runtime (container or code-based artifacts)
- Gateway with MCP (Model Context Protocol) support
- Memory with semantic, summary, user preference, and custom strategies
- Code Interpreter with sandbox or VPC execution modes
- Cognito User Pool for JWT authentication
- Granular IAM permission outputs for external consumers
- CloudWatch logging for all components
- KMS encryption support

**Example Usage:**

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
  gateway_description      = "MCP Gateway for ServiceNow integrations"
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
  create_memory     = true
  memory_name       = "servicenow-memory"
  memory_description = "Conversation memory for ServiceNow context"
  memory_strategies = [
    {
      semantic_memory_strategy = {
        name        = "servicenow_semantic_memory"
        description = "Semantic memory for ServiceNow context"
        namespaces  = ["servicenow"]
        model_id    = "anthropic.claude-3-haiku-20240307-v1:0"
      }
      summary_memory_strategy         = null
      user_preference_memory_strategy = null
      custom_memory_strategy          = null
    }
  ]

  # Code Interpreter Configuration
  create_code_interpreter     = true
  code_interpreter_name       = "servicenow-interpreter"
  code_interpreter_description = "Code interpreter for data analysis"
  code_interpreter_executor    = "SANDBOX"

  # Cognito for JWT Authentication
  create_cognito       = true
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

**Memory Strategies:**

1. **Semantic** - Vector-based semantic search across conversation history
2. **Summary** - Compressed summaries of past interactions
3. **User Preference** - Track and recall user preferences
4. **Custom** - Custom memory strategy with your own implementation

**Code Interpreter Executors:**

1. **SANDBOX** - Isolated sandbox environment (default)
2. **VPC** - Execute within your VPC with network access

**Key Outputs:**

- `runtime_id` - Runtime identifier
- `runtime_arn` - Runtime ARN
- `gateway_id` - Gateway identifier
- `gateway_url` - Gateway endpoint URL
- `memory_id` - Memory identifier
- `memory_arn` - Memory ARN
- `code_interpreter_id` - Code Interpreter identifier
- `cognito_user_pool_id` - Cognito User Pool ID
- `cognito_discovery_url` - OIDC Discovery URL
- `memory_stm_read_policy_json` - IAM policy for STM read access
- `memory_ltm_write_policy_json` - IAM policy for LTM write access

## Requirements

- **Terraform**: >= 1.11.0
- **AWS Provider**: ~> 5.80
- **AWSCC Provider**: >= 1.66.0 (for bedrock-agentcore module)
- **AWS CLI**: Configured with appropriate credentials
- **Permissions**: IAM permissions for Bedrock, Lambda, S3, OpenSearch, Step
  Functions, DynamoDB, EventBridge, SNS, Cognito

## Complete Example

```hcl
# Complete multi-agent system with knowledge base and orchestration

# 1. Knowledge Base
module "kb" {
  source = "./modules/bedrock-knowledge-base"

  knowledge_base_name = "company-knowledge"
  embedding_model_id  = "amazon.titan-embed-text-v2:0"
  vector_dimension    = 1024

  create_s3_bucket = true
  chunking_strategy = "FIXED_SIZE"
  max_tokens       = 300

  tags = var.common_tags
}

# 2. Action Groups
module "api_actions" {
  source = "./modules/bedrock-action-group"

  action_group_name    = "api-actions"
  lambda_function_name = "bedrock-api-handler"
  lambda_runtime       = "python3.12"

  lambda_source_code_path = "${path.module}/lambda/api_handler.zip"
  api_schema             = file("${path.module}/schemas/api.json")

  tags = var.common_tags
}

# 3. Agents
module "agent_1" {
  source = "./modules/bedrock-agent"

  agent_name  = "analysis-agent"
  model_id    = "anthropic.claude-3-5-sonnet-20241022-v2:0"
  instruction = "You analyze customer data..."

  knowledge_bases = [{
    knowledge_base_id = module.kb.knowledge_base_id
    description       = "Company knowledge"
  }]

  agent_aliases = {
    production = { description = "Production" }
  }

  tags = var.common_tags
}

module "agent_2" {
  source = "./modules/bedrock-agent"

  agent_name  = "action-agent"
  model_id    = "anthropic.claude-3-5-haiku-20241022-v1:0"
  instruction = "You execute actions..."

  action_groups = [{
    action_group_name = "api-actions"
    description       = "API actions"
    lambda_arn        = module.api_actions.lambda_function_arn
    api_schema        = module.api_actions.api_schema
    enabled           = true
  }]

  agent_aliases = {
    production = { description = "Production" }
  }

  tags = var.common_tags
}

# 4. Orchestration
module "orchestration" {
  source = "./modules/bedrock-orchestration"

  orchestration_name = "multi-agent-workflow"

  agent_arns = [
    module.agent_1.agent_arn,
    module.agent_2.agent_arn
  ]

  orchestration_pattern   = "sequential"
  create_dynamodb_table   = true
  enable_sns_notifications = true

  tags = var.common_tags
}

# Outputs
output "workflow_arn" {
  value = module.orchestration.state_machine_arn
}

output "agent_ids" {
  value = {
    analysis = module.agent_1.agent_id
    action   = module.agent_2.agent_id
  }
}
```

## Best Practices

### Security

1. **Encryption**

   - Enable KMS encryption for S3 buckets
   - Use customer-managed keys when required
   - Enable encryption for DynamoDB tables

2. **IAM Least Privilege**

   - Use specific resource ARNs in policies
   - Enable source account/ARN conditions
   - Regularly audit permissions

3. **Network Security**
   - Use VPC configuration for Lambda functions
   - Enable VPC endpoints for AWS services
   - Configure security groups appropriately

### Performance

1. **Knowledge Bases**

   - Choose appropriate vector dimensions (1024 recommended)
   - Optimize chunk size for your content
   - Use appropriate overlap percentages

2. **Lambda Functions**

   - Set appropriate memory and timeout values
   - Use Lambda layers for dependencies
   - Enable reserved concurrency for critical actions

3. **Orchestration**
   - Use PAY_PER_REQUEST for variable workloads
   - Enable point-in-time recovery for state tables
   - Set appropriate timeout values

### Cost Optimization

1. **OpenSearch Serverless**

   - Enable standby replicas only when needed
   - Monitor collection capacity units (OCUs)

2. **Step Functions**

   - Use EXPRESS for high-volume, short-duration workflows
   - Use STANDARD for long-running workflows

3. **DynamoDB**
   - Use PAY_PER_REQUEST for unpredictable workloads
   - Enable TTL for automatic data cleanup

### Monitoring

1. **CloudWatch**

   - Enable detailed logging
   - Set up alarms for errors and throttling
   - Monitor Lambda concurrent executions

2. **X-Ray**

   - Enable tracing for Lambda and Step Functions
   - Analyze trace maps for bottlenecks

3. **SNS Notifications**
   - Configure notifications for workflow failures
   - Set up alerts for critical errors

## Troubleshooting

### Common Issues

1. **Agent Creation Fails**

   - Verify model access in Bedrock console
   - Check IAM role permissions
   - Ensure knowledge base IDs are valid

2. **Knowledge Base Ingestion Issues**

   - Verify S3 bucket permissions
   - Check data source configuration
   - Ensure documents are in supported formats

3. **Action Group Errors**

   - Validate OpenAPI schema format
   - Check Lambda function permissions
   - Verify response format matches Bedrock requirements

4. **Orchestration Failures**
   - Check agent ARNs and aliases
   - Verify DynamoDB table access
   - Review state machine logs

5. **AgentCore Issues**
   - Verify AWSCC provider version >= 1.66.0
   - Memory strategy names must match pattern `^[a-zA-Z][a-zA-Z0-9_]{0,47}$` (no hyphens)
   - Gateway targets are not yet supported in AWSCC provider
   - Check Cognito User Pool configuration for JWT auth
   - Verify container image URI format for runtime

## Additional Resources

- [Amazon Bedrock Documentation](https://docs.aws.amazon.com/bedrock/)
- [Bedrock Agents Guide](https://docs.aws.amazon.com/bedrock/latest/userguide/agents.html)
- [Bedrock AgentCore Guide](https://docs.aws.amazon.com/bedrock/latest/userguide/agentcore.html)
- [AWS-IA AgentCore Module](https://github.com/aws-ia/terraform-aws-agentcore)
- [Step Functions Developer Guide](https://docs.aws.amazon.com/step-functions/)
- [OpenSearch Serverless](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/serverless.html)

## License

This module collection is provided as-is for use in AWS infrastructure
deployments.

## Support

For issues or questions:

1. Review the troubleshooting section
2. Check AWS service quotas and limits
3. Verify IAM permissions
4. Review CloudWatch logs for detailed errors
