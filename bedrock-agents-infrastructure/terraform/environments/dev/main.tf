# Development Environment - Minimal Cost Configuration
# Single agent instances, basic knowledge base, on-demand pricing

terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 1.29.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.12.0"
    }
  }

  # Backend configuration for state management
  # Temporarily commented out - S3 bucket needs to be created first
  # backend "s3" {
  #   bucket       = "servicenow-ai-terraform-state-dev"
  #   key          = "bedrock-agents/dev/terraform.tfstate"
  #   region       = "eu-west-2"
  #   encrypt      = true
  #   use_lockfile = true
  # }
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
    AutoShutdown   = var.auto_shutdown_enabled ? "true" : "false"
    BackupRequired = "false"
    Compliance     = "none"
    DebugMode      = var.enable_debug_mode ? "enabled" : "disabled"
  }

  # Minimal configuration for dev
  agent_config = {
    model_id         = "anthropic.claude-3-sonnet-20240229-v1:0"
    idle_session_ttl = 600 # 10 minutes
  }
}

# Bedrock Agent Module
module "bedrock_agent" {
  source = "../../modules/bedrock-agent"

  # Agent configuration
  agent_name                  = "${local.project}-agent-${local.environment}"
  description                 = "Development Bedrock agent for ServiceNow AI"
  foundation_model            = local.agent_config.model_id
  model_id                    = local.agent_config.model_id
  instruction                 = var.agent_instruction
  idle_session_ttl_in_seconds = local.agent_config.idle_session_ttl

  # KMS encryption
  customer_encryption_key_arn = module.security_kms.bedrock_data_key_arn
  kms_key_id                  = module.security_kms.bedrock_data_key_id

  # Prepare agent after creation
  prepare_agent = true

  # Knowledge bases will be associated after creation
  knowledge_bases = []

  # Action groups will be configured separately
  action_groups = []

  # Agent aliases
  agent_aliases = {
    live = {
      description = "Live alias for production traffic"
      tags        = {}
    }
  }

  # Tags
  tags = local.common_tags

  # Explicit dependency to ensure KMS key exists before creating log groups
  depends_on = [module.security_kms]
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
  enable_key_rotation     = var.enable_cost_optimization ? false : true # Disabled when optimizing costs
  enable_multi_region     = false
  deletion_window_in_days = var.enable_cost_optimization ? 7 : 30 # Short window when optimizing costs

  # IAM role ARNs that need KMS access
  iam_role_arns = []

  # Key admin ARNs
  key_admin_arns = var.kms_key_admin_arns

  # Grant role ARNs
  grant_role_arns = []

  # CloudTrail metrics disabled to avoid circular dependency (CloudTrail depends on KMS)
  enable_cloudtrail_metrics = false
  cloudtrail_log_group_name = ""

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

  # Knowledge base ARNs (knowledge bases not created by bedrock_agent module)
  knowledge_base_arns = []

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

  # CloudTrail metrics disabled to avoid circular dependency (CloudTrail depends on KMS which depends on IAM outputs)
  enable_cloudtrail_metrics = false
  cloudtrail_log_group_name = ""

  # SNS topic
  sns_topic_arn = module.monitoring_cloudwatch.sns_topic_arn

  unauthorized_calls_threshold = 10

  # AgentCore IAM roles and policies
  enable_agentcore = var.enable_agentcore

  # AgentCore resource ARNs (populated after agentcore module creates resources)
  # These are set to empty since we're using count-based module instantiation
  # The actual ARNs can be passed in a second apply or via data sources
  agentcore_runtime_arns          = []
  agentcore_gateway_arns          = []
  agentcore_memory_arns           = []
  agentcore_code_interpreter_arns = []
  agentcore_lambda_function_arns  = var.agentcore_gateway_lambda_arns

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
  kms_key_id  = module.security_kms.secrets_key_id
  kms_key_arn = module.security_kms.secrets_key_arn

  # Rotation disabled for dev
  enable_rotation = var.enable_cost_optimization ? false : true
  rotation_days   = 90

  # Recovery window
  recovery_window_in_days = var.enable_cost_optimization ? 7 : 30

  # CloudWatch configuration
  sns_topic_arn = module.monitoring_cloudwatch.sns_topic_arn

  # CloudTrail metrics disabled to avoid circular dependency (CloudTrail depends on KMS)
  enable_cloudtrail_metrics = false
  cloudtrail_log_group_name = ""

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
  bedrock_agent_alias_id = try(module.bedrock_agent.agent_aliases["live"].agent_alias_id, null)

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

  # Anomaly detection - controlled by debug mode
  enable_anomaly_detection = var.enable_debug_mode
  enable_composite_alarms  = var.enable_debug_mode

  # Dashboard
  create_dashboard = true
  dashboard_name   = "${local.project}-${local.environment}-bedrock"

  # Log groups
  log_group_names = [
    module.bedrock_agent.log_group_name
  ]

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
  create_cloudwatch_logs_group   = true
  cloudwatch_logs_retention_days = var.enable_debug_mode ? 14 : (var.enable_cost_optimization ? 3 : 7)

  # Event selectors - basic for dev
  event_selectors = [
    {
      read_write_type           = "All"
      include_management_events = true
      data_resources            = []
    }
  ]

  tags = local.common_tags

  # Explicit dependency to ensure KMS key exists before creating log groups
  depends_on = [module.security_kms]
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
  enable_bedrock_state_change_events = true
  enable_bedrock_error_events        = true

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
  lambda_runtime = "python3.12"
  # 5 minutes when debugging, 3 minutes otherwise
  lambda_timeout = var.enable_debug_mode ? 300 : 180
  # Adjust based on cost optimization and debug mode
  lambda_memory_size = var.enable_cost_optimization ? 128 : (var.enable_debug_mode ? 512 : 256)

  # DynamoDB configuration
  dynamodb_billing_mode = "PAY_PER_REQUEST" # On-demand for dev
  # Enable if not cost-optimizing
  dynamodb_point_in_time_recovery = var.enable_cost_optimization ? false : true

  # Monitoring - basic
  enable_enhanced_monitoring = var.enable_debug_mode # Enable when debugging
  alarm_notification_emails  = var.alert_email != "" ? [var.alert_email] : []

  # Security - use KMS keys from security module
  kms_key_id                = module.security_kms.bedrock_data_key_id
  enable_encryption_at_rest = true
  sns_kms_master_key_id     = module.security_kms.bedrock_data_key_id

  # Networking - no VPC for dev (cost savings)
  vpc_id             = null
  subnet_ids         = []
  security_group_ids = []

  # Knowledge base integration (knowledge bases not created by bedrock_agent module)
  knowledge_base_ids = []

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
# AgentCore Module - Advanced AI Agent Capabilities
# ==============================================================================
# Provides MCP gateway, memory (STM/LTM), and code interpreter support
# following AWS AgentCore patterns from terraform-aws-agentcore

module "bedrock_agentcore" {
  source = "../../modules/bedrock-agentcore"
  count  = var.enable_agentcore ? 1 : 0

  # Environment configuration
  project_name = local.project
  environment  = local.environment

  # Component toggles (module uses create_* not enable_*)
  create_runtime          = var.enable_agentcore_runtime
  create_gateway          = var.enable_agentcore_gateway
  create_memory           = var.enable_agentcore_memory
  create_code_interpreter = var.enable_agentcore_code_interpreter

  # Runtime configuration (container-based)
  runtime_name          = "servicenow-ai-runtime"
  runtime_description   = "AgentCore Runtime for ServiceNow AI agents"
  runtime_artifact_type = "container"
  runtime_container_uri = var.agentcore_runtime_container_uri
  runtime_network_mode  = "PUBLIC"
  runtime_allowed_model_arns = [
    "arn:aws:bedrock:${var.aws_region}::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0",
    "arn:aws:bedrock:${var.aws_region}::foundation-model/anthropic.claude-3-haiku-20240307-v1:0"
  ]

  # Gateway configuration (MCP protocol)
  gateway_name                 = "servicenow-mcp-gateway"
  gateway_description          = "MCP Gateway for ServiceNow AI tools and integrations"
  gateway_protocol_type        = "MCP"
  gateway_authorizer_type      = "AWS_IAM" # Use IAM for dev, CUSTOM_JWT for prod
  gateway_lambda_function_arns = var.agentcore_gateway_lambda_arns
  gateway_mcp_configuration = {
    instructions       = "ServiceNow AI MCP Gateway for development. Provides tools for incident management, ticket triage, and ServiceNow API integration."
    search_type        = "SEMANTIC"
    supported_versions = ["2024-11-05"]
  }

  # Memory configuration (semantic strategy for dev)
  memory_name                  = "servicenow-ai-memory"
  memory_description           = "Memory store for ServiceNow AI agent context and user preferences"
  memory_event_expiry_duration = 7 # 7 days for dev (module expects days, not seconds)
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

  # Code Interpreter configuration (SANDBOX for dev)
  code_interpreter_name         = "servicenow-code-interpreter"
  code_interpreter_description  = "Code interpreter for data analysis and scripting tasks"
  code_interpreter_network_mode = "SANDBOX"

  # Encryption (use KMS key from security module)
  runtime_kms_key_arn          = module.security_kms.bedrock_data_key_arn
  gateway_kms_key_arn          = module.security_kms.bedrock_data_key_arn
  memory_kms_key_arn           = module.security_kms.bedrock_data_key_arn
  code_interpreter_kms_key_arn = module.security_kms.bedrock_data_key_arn

  # Cognito - disabled for dev (using IAM auth)
  create_cognito = false

  # Logging
  log_retention_days = var.enable_debug_mode ? 14 : (var.enable_cost_optimization ? 3 : 7)

  tags = local.common_tags

  # Dependencies
  depends_on = [
    module.security_kms,
    module.security_iam
  ]
}

# ==============================================================================
# Outputs
# ==============================================================================

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
  value       = module.monitoring_cloudtrail.cloudwatch_log_group_name
}

output "cloudtrail_s3_bucket" {
  description = "S3 bucket for CloudTrail logs"
  value       = module.monitoring_cloudtrail.s3_bucket_name
}

# ServiceNow Module Outputs
output "servicenow_api_endpoint" {
  description = "API Gateway endpoint for ServiceNow integration"
  value       = module.bedrock_servicenow.api_gateway_url
}

output "servicenow_api_id" {
  description = "API Gateway ID for ServiceNow integration"
  value       = module.bedrock_servicenow.api_gateway_id
}

output "servicenow_webhook_url" {
  description = "Webhook URLs for ServiceNow callbacks"
  value       = module.bedrock_servicenow.webhook_endpoints
}

output "servicenow_dynamodb_table" {
  description = "DynamoDB table for ServiceNow session tracking"
  value       = module.bedrock_servicenow.state_table_name
}

# AgentCore Module Outputs
output "agentcore_enabled" {
  description = "Whether AgentCore module is enabled"
  value       = var.enable_agentcore
}

output "agentcore_runtime_arn" {
  description = "ARN of the AgentCore Runtime"
  value       = var.enable_agentcore ? try(module.bedrock_agentcore[0].runtime_arn, null) : null
}

output "agentcore_gateway_arn" {
  description = "ARN of the AgentCore Gateway"
  value       = var.enable_agentcore ? try(module.bedrock_agentcore[0].gateway_arn, null) : null
}

output "agentcore_gateway_endpoint" {
  description = "Endpoint URL of the AgentCore Gateway"
  value       = var.enable_agentcore ? try(module.bedrock_agentcore[0].gateway_endpoint, null) : null
}

output "agentcore_memory_arn" {
  description = "ARN of the AgentCore Memory"
  value       = var.enable_agentcore ? try(module.bedrock_agentcore[0].memory_arn, null) : null
}

output "agentcore_code_interpreter_arn" {
  description = "ARN of the AgentCore Code Interpreter"
  value       = var.enable_agentcore ? try(module.bedrock_agentcore[0].code_interpreter_arn, null) : null
}

output "agentcore_memory_policy_json" {
  description = "JSON policy for AgentCore memory full access (for downstream consumers)"
  value       = var.enable_agentcore ? try(module.bedrock_agentcore[0].memory_full_access_policy_json, null) : null
  sensitive   = false
}
