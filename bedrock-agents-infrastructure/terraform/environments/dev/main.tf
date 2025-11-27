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
    Environment    = "dev"
    Project        = "servicenow-ai"
    ManagedBy      = "terraform"
    CostCenter     = "development"
    Owner          = var.owner_email
    AutoShutdown   = "true"
    BackupRequired = "false"
    Compliance     = "none"
  }

  # Minimal configuration for dev
  agent_config = {
    instance_count     = 1
    model_id           = "anthropic.claude-3-sonnet-20240229-v1:0"
    enable_trace       = true
    idle_session_ttl   = 600 # 10 minutes
    enable_provisioned = false
    pricing_model      = "on-demand"
  }

  # Basic knowledge base configuration
  knowledge_base_config = {
    enabled           = true
    storage_type      = "opensearch-serverless"
    embedding_model   = "amazon.titan-embed-text-v1"
    chunking_strategy = "fixed_size"
    chunk_size        = 300
    chunk_overlap     = 20
    max_tokens        = 512
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
  enable_knowledge_base      = local.knowledge_base_config.enabled
  knowledge_base_name        = "${local.project}-kb-${local.environment}"
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
  log_retention_days     = 7 # Short retention for dev

  enable_xray_tracing     = false # Disabled for cost savings
  enable_detailed_metrics = false # Disabled for cost savings

  # Alerting - Minimal
  enable_alerting      = false
  alert_email          = var.alert_email
  throttle_threshold   = 100
  error_rate_threshold = 0.5
  latency_threshold_ms = 5000

  # Cost optimization
  enable_auto_shutdown = true
  shutdown_cron        = "0 20 * * MON-FRI" # Shutdown at 8 PM weekdays
  startup_cron         = "0 8 * * MON-FRI"  # Start at 8 AM weekdays

  # Backup - Disabled for dev
  enable_backup         = false
  backup_retention_days = 1

  # Multi-region - Disabled
  enable_multi_region = false

  # Tags
  tags = local.common_tags
}

# ==============================================================================
# Security Modules - Minimal Configuration for Dev
# ==============================================================================

# KMS Module - Encryption keys
module "security_kms" {
  source = "../../modules/security/bedrock-security-kms"

  project_name = local.project
  environment  = local.environment
  aws_region   = var.aws_region

  # Minimal KMS configuration for dev
  enable_key_rotation     = false # Disabled for cost savings
  enable_multi_region     = false
  deletion_window_in_days = 7 # Short window for dev

  # IAM role ARNs that need KMS access
  iam_role_arns = [
    module.bedrock_agent.agent_role_arn
  ]

  # Key admin ARNs
  key_admin_arns = var.kms_key_admin_arns

  # Grant role ARNs
  grant_role_arns = []

  # CloudTrail log group (will be created by CloudTrail module)
  cloudtrail_log_group_name = "/aws/cloudtrail/${local.project}-${local.environment}"

  # SNS topic for alerts (will use monitoring SNS topic)
  sns_topic_arn = module.monitoring_cloudwatch.sns_topic_arn

  kms_error_threshold = 10

  tags = local.common_tags
}

# IAM Module - Security roles and policies
module "security_iam" {
  source = "../../modules/security/bedrock-security-iam"

  project_name = local.project
  environment  = local.environment
  aws_region   = var.aws_region

  # Permission boundary - disabled for dev
  enable_permission_boundary = false
  max_session_duration       = 3600

  allowed_regions = [var.aws_region]

  # Bedrock models
  allowed_bedrock_models = [
    "arn:aws:bedrock:*::foundation-model/anthropic.claude-*"
  ]

  # Knowledge base ARNs
  knowledge_base_arns = [
    module.bedrock_agent.knowledge_base_arn
  ]

  # DynamoDB and KMS
  dynamodb_table_arns = []
  kms_key_arns = [
    module.security_kms.bedrock_data_key_arn,
    module.security_kms.secrets_key_arn
  ]

  # Step Functions - disabled for dev
  enable_step_functions = false

  # Cross-account access - disabled for dev
  enable_cross_account_access = false

  # CloudTrail log group
  cloudtrail_log_group_name = "/aws/cloudtrail/${local.project}-${local.environment}"

  # SNS topic
  sns_topic_arn = module.monitoring_cloudwatch.sns_topic_arn

  unauthorized_calls_threshold = 10

  tags = local.common_tags
}

# GuardDuty Module - Threat detection (disabled for dev to save costs)
# Uncomment if threat detection is needed in dev
# module "security_guardduty" {
#   source = "../../modules/security/bedrock-security-guardduty"
#
#   project_name = local.project
#   environment  = local.environment
#
#   finding_publishing_frequency = "ONE_HOUR"
#
#   # Minimal protections for dev
#   enable_s3_protection      = false
#   enable_eks_protection     = false
#   enable_lambda_protection  = false
#   enable_rds_protection     = false
#   enable_malware_protection = false
#
#   sns_topic_arn = module.monitoring_cloudwatch.sns_topic_arn
#   kms_key_arn   = module.security_kms.bedrock_data_key_arn
#
#   log_retention_days = 7
#
#   tags = local.common_tags
# }

# Security Hub - Disabled for dev to save costs
# Uncomment if compliance monitoring is needed
# module "security_hub" {
#   source = "../../modules/security/bedrock-security-hub"
#
#   project_name = local.project
#   environment  = local.environment
#
#   enable_cis_standard = false
#   enable_pci_dss      = false
#   enable_aws_foundational = true
#
#   sns_topic_arn = module.monitoring_cloudwatch.sns_topic_arn
#
#   tags = local.common_tags
# }

# WAF Module - Disabled for dev
# Uncomment if API protection is needed
# module "security_waf" {
#   source = "../../modules/security/bedrock-security-waf"
#
#   project_name = local.project
#   environment  = local.environment
#
#   waf_scope  = "REGIONAL"
#   rate_limit = 5000  # Higher limit for dev testing
#
#   enable_waf_logging = false
#   sns_topic_arn      = module.monitoring_cloudwatch.sns_topic_arn
#
#   tags = local.common_tags
# }

# Secrets Manager Module - Basic secrets encryption
module "security_secrets" {
  source = "../../modules/security/bedrock-security-secrets"

  project_name = local.project
  environment  = local.environment

  # KMS key for secrets encryption
  kms_key_id = module.security_kms.secrets_key_id

  # Rotation disabled for dev
  enable_rotation = false
  rotation_days   = 90

  # Recovery window
  recovery_window_in_days = 7

  sns_topic_arn = module.monitoring_cloudwatch.sns_topic_arn

  tags = local.common_tags
}

# ==============================================================================
# Monitoring Modules - Basic Configuration for Dev
# ==============================================================================

# CloudWatch Module - Dashboards and alarms
module "monitoring_cloudwatch" {
  source = "../../modules/monitoring/bedrock-monitoring-cloudwatch"

  project_name = local.project
  environment  = local.environment

  # Bedrock agent monitoring
  bedrock_agent_id       = module.bedrock_agent.agent_id
  bedrock_agent_alias_id = module.bedrock_agent.agent_alias_id

  # Lambda functions (if any)
  lambda_function_names = var.lambda_function_names

  # Step Functions (if any)
  step_function_state_machine_arns = []

  # API Gateway (if any)
  api_gateway_ids = []

  # SNS configuration
  create_sns_topic        = true
  sns_email_subscriptions = var.alert_email != "" ? [var.alert_email] : []

  # Alarms - relaxed thresholds for dev
  bedrock_error_rate_threshold         = 10    # Higher tolerance
  bedrock_invocation_latency_threshold = 60000 # 60 seconds
  bedrock_throttle_threshold           = 20
  lambda_error_rate_threshold          = 10
  lambda_duration_threshold            = 30000
  lambda_throttles_threshold           = 10

  # Anomaly detection - disabled for dev
  enable_anomaly_detection = false
  enable_composite_alarms  = false

  # Dashboard
  create_dashboard = true
  dashboard_name   = "${local.project}-${local.environment}-bedrock"

  # Log groups
  log_group_names = [
    "/aws/bedrock/agents/${local.project}-${local.environment}"
  ]

  # KMS encryption
  kms_key_id = module.security_kms.bedrock_data_key_id

  tags = local.common_tags
}

# X-Ray Module - Disabled for dev to save costs
# Uncomment if distributed tracing is needed
# module "monitoring_xray" {
#   source = "../../modules/monitoring/bedrock-monitoring-xray"
#
#   project_name = local.project
#   environment  = local.environment
#
#   enable_insights       = false
#   enable_sampling_rules = true
#   sampling_rate         = 0.1  # Sample 10% of requests
#
#   tags = local.common_tags
# }

# CloudTrail Module - Basic audit logging
module "monitoring_cloudtrail" {
  source = "../../modules/monitoring/bedrock-monitoring-cloudtrail"

  project_name = local.project
  environment  = local.environment

  # S3 bucket for CloudTrail logs
  create_s3_bucket = true
  s3_bucket_name   = "${local.project}-cloudtrail-${local.environment}"

  # KMS encryption
  kms_key_id = module.security_kms.bedrock_data_key_id

  # CloudWatch Logs integration
  create_cloudwatch_logs_group  = true
  cloudwatch_logs_retention_days = 7

  # Event selectors - basic for dev
  event_selectors = [
    {
      read_write_type           = "All"
      include_management_events = true
      data_resources            = []
    }
  ]

  tags = local.common_tags
}

# Config Module - Disabled for dev
# Uncomment if compliance tracking is needed
# module "monitoring_config" {
#   source = "../../modules/monitoring/bedrock-monitoring-config"
#
#   project_name = local.project
#   environment  = local.environment
#
#   delivery_frequency = "TwentyFour_Hours"
#   s3_bucket_name     = "${local.project}-config-${local.environment}"
#
#   kms_key_id    = module.security_kms.bedrock_data_key_id
#   sns_topic_arn = module.monitoring_cloudwatch.sns_topic_arn
#
#   tags = local.common_tags
# }

# EventBridge Module - Basic event-driven monitoring
module "monitoring_eventbridge" {
  source = "../../modules/monitoring/bedrock-monitoring-eventbridge"

  project_name = local.project
  environment  = local.environment

  # Event patterns for Bedrock
  enable_bedrock_events = true

  # Targets
  sns_topic_arn = module.monitoring_cloudwatch.sns_topic_arn

  # Event bus
  create_custom_event_bus = false

  tags = local.common_tags
}

# Synthetics Module - Disabled for dev
# Uncomment if endpoint testing is needed
# module "monitoring_synthetics" {
#   source = "../../modules/monitoring/bedrock-monitoring-synthetics"
#
#   project_name = local.project
#   environment  = local.environment
#
#   # Canary configuration
#   canary_name     = "${local.project}-agent-canary-${local.environment}"
#   canary_schedule = "rate(30 minutes)"  # Less frequent for dev
#
#   # Endpoints to test
#   endpoints = var.bedrock_agent_endpoints
#
#   sns_topic_arn = module.monitoring_cloudwatch.sns_topic_arn
#
#   tags = local.common_tags
# }

# ==============================================================================
# ServiceNow Integration Module
# ==============================================================================

module "bedrock_servicenow" {
  source = "../../modules/bedrock-servicenow"

  # Environment configuration
  environment = local.environment
  name_prefix = local.project

  # ServiceNow instance configuration
  servicenow_instance_url           = var.servicenow_instance_url
  servicenow_auth_type              = var.servicenow_auth_type
  servicenow_credentials_secret_arn = var.servicenow_credentials_secret_arn

  # Feature flags - basic features only for dev
  enable_incident_automation = true
  enable_ticket_triage       = true
  enable_change_management   = false # Disabled for cost savings
  enable_problem_management  = false # Disabled for cost savings
  enable_knowledge_sync      = false # Disabled for cost savings
  enable_sla_monitoring      = false # Disabled for cost savings

  # Auto-assignment with lower confidence threshold
  auto_assignment_enabled              = true
  auto_assignment_confidence_threshold = 0.75 # Lower threshold for testing

  # Agent configuration
  agent_model_id         = local.agent_config.model_id
  agent_idle_session_ttl = local.agent_config.idle_session_ttl

  # Lambda configuration - cost-optimized
  lambda_runtime     = "python3.12"
  lambda_timeout     = 180 # 3 minutes
  lambda_memory_size = 256 # Lower memory for dev

  # DynamoDB configuration
  dynamodb_billing_mode           = "PAY_PER_REQUEST" # On-demand for dev
  dynamodb_point_in_time_recovery = false             # Disabled for cost savings

  # Monitoring - basic
  enable_enhanced_monitoring = false # Disabled for cost savings
  alarm_notification_emails  = var.alert_email != "" ? [var.alert_email] : []

  # Security - use KMS keys from security module
  kms_key_id                   = module.security_kms.bedrock_data_key_id
  enable_encryption_at_rest    = true
  enable_encryption_in_transit = true
  sns_kms_master_key_id        = module.security_kms.bedrock_data_key_id

  # Networking - no VPC for dev (cost savings)
  vpc_id             = null
  subnet_ids         = []
  security_group_ids = []

  # Knowledge base integration
  knowledge_base_ids = [module.bedrock_agent.knowledge_base_id]

  # Workflow timeouts
  incident_escalation_timeout_minutes = 60  # Longer timeout for dev
  change_approval_timeout_minutes     = 480 # 8 hours

  tags = local.common_tags

  # Dependencies
  depends_on = [
    module.bedrock_agent,
    module.security_kms,
    module.monitoring_cloudwatch
  ]
}

# ==============================================================================
# Outputs
# ==============================================================================

# Bedrock Agent Outputs
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

# Security Outputs
output "kms_bedrock_data_key_arn" {
  description = "ARN of the KMS key for Bedrock data encryption"
  value       = module.security_kms.bedrock_data_key_arn
}

output "kms_secrets_key_arn" {
  description = "ARN of the KMS key for secrets encryption"
  value       = module.security_kms.secrets_key_arn
}

output "bedrock_agent_execution_role_arn" {
  description = "ARN of the Bedrock agent execution role"
  value       = module.security_iam.bedrock_agent_execution_role_arn
}

output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = module.security_iam.lambda_execution_role_arn
}

# Monitoring Outputs
output "monitoring_dashboard_name" {
  description = "Name of the CloudWatch monitoring dashboard"
  value       = module.monitoring_cloudwatch.dashboard_name
}

output "monitoring_sns_topic_arn" {
  description = "ARN of the monitoring SNS topic"
  value       = module.monitoring_cloudwatch.sns_topic_arn
}

output "cloudtrail_log_group" {
  description = "CloudTrail log group name"
  value       = module.monitoring_cloudtrail.log_group_name
}

output "cloudtrail_s3_bucket" {
  description = "S3 bucket for CloudTrail logs"
  value       = module.monitoring_cloudtrail.s3_bucket_name
}

# ServiceNow Module Outputs
output "servicenow_api_endpoint" {
  description = "API Gateway endpoint for ServiceNow integration"
  value       = module.bedrock_servicenow.api_gateway_endpoint
}

output "servicenow_api_id" {
  description = "API Gateway ID for ServiceNow integration"
  value       = module.bedrock_servicenow.api_gateway_id
}

output "servicenow_webhook_url" {
  description = "Webhook URL for ServiceNow callbacks"
  value       = module.bedrock_servicenow.webhook_url
}

output "servicenow_dynamodb_table" {
  description = "DynamoDB table for ServiceNow session tracking"
  value       = module.bedrock_servicenow.dynamodb_table_name
}
