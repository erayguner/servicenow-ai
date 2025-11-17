# Staging Environment - Medium Configuration
# Multiple agent instances, full knowledge bases, all action groups, testing orchestration

terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }

  # Backend configuration for state management
  backend "s3" {
    bucket         = "servicenow-ai-terraform-state-staging"
    key            = "bedrock-agents/staging/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "servicenow-ai-terraform-locks-staging"

    # Enable state locking and consistency checking
    kms_key_id = "alias/terraform-state-key-staging"
  }
}

# Local variables for environment configuration
locals {
  environment = "staging"
  project     = "servicenow-ai"

  # Staging tags
  common_tags = {
    Environment     = "staging"
    Project         = "servicenow-ai"
    ManagedBy       = "terraform"
    CostCenter      = "qa-testing"
    Owner           = var.owner_email
    AutoShutdown    = "false"
    BackupRequired  = "true"
    Compliance      = "sox-compliant"
    DataClassification = "confidential"
  }

  # Medium configuration for staging
  agent_config = {
    instance_count          = 3
    model_id                = "anthropic.claude-3-sonnet-20240229-v1:0"
    enable_trace            = true
    idle_session_ttl        = 1800  # 30 minutes
    enable_provisioned      = false
    pricing_model           = "on-demand"
  }

  # Full knowledge base configuration
  knowledge_base_config = {
    enabled             = true
    storage_type        = "opensearch-serverless"
    embedding_model     = "amazon.titan-embed-text-v2"
    chunking_strategy   = "hierarchical"
    chunk_size          = 512
    chunk_overlap       = 50
    max_tokens          = 1024
  }

  # All action groups for staging
  action_groups = {
    enabled = true
    groups  = [
      "servicenow-read",
      "servicenow-write",
      "servicenow-query",
      "analytics-actions",
      "notification-actions",
      "workflow-actions"
    ]
  }

  # Orchestration configuration
  orchestration_config = {
    enabled                = true
    max_concurrent_invocations = 10
    prompt_override_enabled    = true
    enable_code_interpretation = true
  }
}

# Bedrock Agent Module
module "bedrock_agent" {
  source = "../../modules/bedrock-agent"

  # Environment configuration
  environment = local.environment
  project     = local.project

  # Agent configuration
  agent_name               = "${local.project}-agent-${local.environment}"
  agent_description        = "Staging Bedrock agent for ServiceNow AI testing"
  foundation_model         = local.agent_config.model_id
  instruction              = var.agent_instruction
  idle_session_ttl_seconds = local.agent_config.idle_session_ttl

  # Multiple instances for staging
  agent_instance_count = local.agent_config.instance_count

  # On-demand pricing (can test provisioned)
  enable_provisioned_throughput = local.agent_config.enable_provisioned

  # Enable tracing for testing
  enable_trace_logging = local.agent_config.enable_trace

  # Knowledge Base configuration
  enable_knowledge_base     = local.knowledge_base_config.enabled
  knowledge_base_name       = "${local.project}-kb-${local.environment}"
  knowledge_base_description = "Staging knowledge base for ServiceNow AI"

  # Storage configuration
  knowledge_base_storage_type = local.knowledge_base_config.storage_type
  embedding_model_arn         = "arn:aws:bedrock:${var.aws_region}::foundation-model/${local.knowledge_base_config.embedding_model}"

  # Advanced chunking strategy
  chunking_strategy = local.knowledge_base_config.chunking_strategy
  chunk_size        = local.knowledge_base_config.chunk_size
  chunk_overlap     = local.knowledge_base_config.chunk_overlap
  max_tokens        = local.knowledge_base_config.max_tokens

  # S3 data source
  data_source_bucket_arn = var.data_source_bucket_arn
  data_source_prefix     = "staging/"

  # Action Groups - All enabled
  enable_action_groups = local.action_groups.enabled
  action_groups        = local.action_groups.groups

  # Lambda function for actions
  action_lambda_arn = var.action_lambda_arn

  # Orchestration configuration
  enable_orchestration           = local.orchestration_config.enabled
  max_concurrent_invocations     = local.orchestration_config.max_concurrent_invocations
  enable_prompt_override         = local.orchestration_config.prompt_override_enabled
  enable_code_interpretation     = local.orchestration_config.enable_code_interpretation

  # IAM roles
  agent_role_name = "${local.project}-bedrock-agent-role-${local.environment}"

  # Monitoring - Enhanced CloudWatch
  enable_cloudwatch_logs = true
  log_retention_days     = 30  # 30 days for staging

  enable_xray_tracing     = true
  enable_detailed_metrics = true

  # Alerting - Enabled
  enable_alerting             = true
  alert_email                 = var.alert_email
  throttle_threshold          = 500
  error_rate_threshold        = 0.1
  latency_threshold_ms        = 3000

  # Cost optimization - Moderate
  enable_auto_shutdown = false  # No auto-shutdown in staging

  # Backup - Enabled
  enable_backup         = true
  backup_retention_days = 7

  # Multi-region - Disabled (can test)
  enable_multi_region = false

  # Performance testing
  enable_load_testing = var.enable_load_testing

  # Tags
  tags = local.common_tags
}

# Additional module for testing orchestration
module "agent_orchestrator" {
  source = "../../modules/agent-orchestrator"

  environment = local.environment
  project     = local.project

  # Primary agent
  primary_agent_id = module.bedrock_agent.agent_id

  # Orchestration configuration
  max_agents            = 5
  enable_auto_scaling   = true
  min_agents            = 2
  max_agents_limit      = 10

  # Testing configuration
  enable_chaos_testing  = var.enable_chaos_testing
  enable_ab_testing     = var.enable_ab_testing

  tags = local.common_tags
}

# Outputs
output "agent_id" {
  description = "Bedrock agent ID"
  value       = module.bedrock_agent.agent_id
}

output "agent_arn" {
  description = "Bedrock agent ARN"
  value       = module.bedrock_agent.agent_arn
}

output "agent_alias_id" {
  description = "Bedrock agent alias ID"
  value       = module.bedrock_agent.agent_alias_id
}

output "knowledge_base_id" {
  description = "Knowledge base ID"
  value       = module.bedrock_agent.knowledge_base_id
}

output "orchestrator_endpoint" {
  description = "Orchestrator API endpoint"
  value       = module.agent_orchestrator.api_endpoint
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group name"
  value       = module.bedrock_agent.cloudwatch_log_group
}

output "xray_trace_group" {
  description = "X-Ray trace group name"
  value       = module.bedrock_agent.xray_trace_group
}
