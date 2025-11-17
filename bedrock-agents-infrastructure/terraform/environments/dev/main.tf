# Development Environment - Minimal Cost Configuration
# Single agent instances, basic knowledge base, on-demand pricing

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
    bucket         = "servicenow-ai-terraform-state-dev"
    key            = "bedrock-agents/dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "servicenow-ai-terraform-locks-dev"

    # Enable state locking and consistency checking
    kms_key_id = "alias/terraform-state-key-dev"
  }
}

# Local variables for environment configuration
locals {
  environment = "dev"
  project     = "servicenow-ai"

  # Cost optimization tags
  common_tags = {
    Environment     = "dev"
    Project         = "servicenow-ai"
    ManagedBy       = "terraform"
    CostCenter      = "development"
    Owner           = var.owner_email
    AutoShutdown    = "true"
    BackupRequired  = "false"
    Compliance      = "none"
  }

  # Minimal configuration for dev
  agent_config = {
    instance_count          = 1
    model_id                = "anthropic.claude-3-sonnet-20240229-v1:0"
    enable_trace            = true
    idle_session_ttl        = 600  # 10 minutes
    enable_provisioned      = false
    pricing_model           = "on-demand"
  }

  # Basic knowledge base configuration
  knowledge_base_config = {
    enabled             = true
    storage_type        = "opensearch-serverless"
    embedding_model     = "amazon.titan-embed-text-v1"
    chunking_strategy   = "fixed_size"
    chunk_size          = 300
    chunk_overlap       = 20
    max_tokens          = 512
  }

  # Limited action groups for dev
  action_groups = {
    enabled = true
    groups  = ["basic-actions"]
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
  agent_description        = "Development Bedrock agent for ServiceNow AI"
  foundation_model         = local.agent_config.model_id
  instruction              = var.agent_instruction
  idle_session_ttl_seconds = local.agent_config.idle_session_ttl

  # Single instance for dev
  agent_instance_count = local.agent_config.instance_count

  # On-demand pricing
  enable_provisioned_throughput = local.agent_config.enable_provisioned

  # Enable tracing for debugging
  enable_trace_logging = local.agent_config.enable_trace

  # Knowledge Base configuration
  enable_knowledge_base     = local.knowledge_base_config.enabled
  knowledge_base_name       = "${local.project}-kb-${local.environment}"
  knowledge_base_description = "Development knowledge base for ServiceNow AI"

  # Storage configuration (OpenSearch Serverless for cost efficiency)
  knowledge_base_storage_type = local.knowledge_base_config.storage_type
  embedding_model_arn         = "arn:aws:bedrock:${var.aws_region}::foundation-model/${local.knowledge_base_config.embedding_model}"

  # Chunking strategy
  chunking_strategy = local.knowledge_base_config.chunking_strategy
  chunk_size        = local.knowledge_base_config.chunk_size
  chunk_overlap     = local.knowledge_base_config.chunk_overlap
  max_tokens        = local.knowledge_base_config.max_tokens

  # S3 data source
  data_source_bucket_arn = var.data_source_bucket_arn
  data_source_prefix     = "dev/"

  # Action Groups - Basic only
  enable_action_groups = local.action_groups.enabled
  action_groups        = local.action_groups.groups

  # Lambda function for actions
  action_lambda_arn = var.action_lambda_arn

  # IAM roles
  agent_role_name = "${local.project}-bedrock-agent-role-${local.environment}"

  # Monitoring - Basic CloudWatch
  enable_cloudwatch_logs = true
  log_retention_days     = 7  # Short retention for dev

  enable_xray_tracing    = false  # Disabled for cost savings
  enable_detailed_metrics = false # Disabled for cost savings

  # Alerting - Minimal
  enable_alerting             = false
  alert_email                 = var.alert_email
  throttle_threshold          = 100
  error_rate_threshold        = 0.5
  latency_threshold_ms        = 5000

  # Cost optimization
  enable_auto_shutdown = true
  shutdown_cron        = "0 20 * * MON-FRI"  # Shutdown at 8 PM weekdays
  startup_cron         = "0 8 * * MON-FRI"   # Start at 8 AM weekdays

  # Backup - Disabled for dev
  enable_backup        = false
  backup_retention_days = 1

  # Multi-region - Disabled
  enable_multi_region = false

  # Tags
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

output "cloudwatch_log_group" {
  description = "CloudWatch log group name"
  value       = module.bedrock_agent.cloudwatch_log_group
}
