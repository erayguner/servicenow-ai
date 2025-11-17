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

# ==============================================================================
# Security Modules - Standard Configuration for Staging
# ==============================================================================

# KMS Module - Encryption keys with rotation
module "security_kms" {
  source = "../../modules/security/bedrock-security-kms"

  project_name = local.project
  environment  = local.environment
  aws_region   = var.aws_region

  # Standard KMS configuration for staging
  enable_key_rotation      = true   # Enabled for staging
  enable_multi_region      = false
  deletion_window_in_days  = 14

  # IAM role ARNs that need KMS access
  iam_role_arns = [
    module.bedrock_agent.agent_role_arn
  ]

  # Key admin ARNs
  key_admin_arns = var.kms_key_admin_arns

  # Grant role ARNs
  grant_role_arns = []

  # CloudTrail log group
  cloudtrail_log_group_name = "/aws/cloudtrail/${local.project}-${local.environment}"

  # SNS topic for alerts
  sns_topic_arn = module.monitoring_cloudwatch.sns_topic_arn

  kms_error_threshold = 10

  tags = local.common_tags
}

# IAM Module - Security roles and policies with ABAC
module "security_iam" {
  source = "../../modules/security/bedrock-security-iam"

  project_name = local.project
  environment  = local.environment
  aws_region   = var.aws_region

  # Permission boundary - enabled for staging
  enable_permission_boundary = true
  max_session_duration       = 7200  # 2 hours

  allowed_regions = [var.aws_region, "us-west-2"]

  # Bedrock models
  allowed_bedrock_models = [
    "arn:aws:bedrock:*::foundation-model/anthropic.claude-*"
  ]

  # Knowledge base ARNs
  knowledge_base_arns = [
    module.bedrock_agent.knowledge_base_arn
  ]

  # DynamoDB and KMS
  dynamodb_table_arns = var.dynamodb_table_arns
  kms_key_arns = [
    module.security_kms.bedrock_data_key_arn,
    module.security_kms.secrets_key_arn,
    module.security_kms.s3_key_arn
  ]

  # Step Functions - enabled for staging
  enable_step_functions = true

  # Cross-account access - disabled for staging
  enable_cross_account_access = false

  # CloudTrail log group
  cloudtrail_log_group_name = "/aws/cloudtrail/${local.project}-${local.environment}"

  # SNS topic
  sns_topic_arn = module.monitoring_cloudwatch.sns_topic_arn

  unauthorized_calls_threshold = 5

  tags = local.common_tags
}

# GuardDuty Module - Threat detection with standard protections
module "security_guardduty" {
  source = "../../modules/security/bedrock-security-guardduty"

  project_name = local.project
  environment  = local.environment

  finding_publishing_frequency = "FIFTEEN_MINUTES"

  # Standard protections for staging
  enable_s3_protection      = true
  enable_eks_protection     = false  # Enable if using EKS
  enable_lambda_protection  = true
  enable_rds_protection     = false  # Enable if using RDS
  enable_malware_protection = true

  # Threat detection
  enable_crypto_mining_detection = true

  sns_topic_arn = module.monitoring_cloudwatch.sns_topic_arn
  kms_key_arn   = module.security_kms.bedrock_data_key_arn

  log_retention_days = 30

  findings_count_threshold = 5

  tags = local.common_tags
}

# Security Hub - Compliance monitoring
module "security_hub" {
  source = "../../modules/security/bedrock-security-hub"

  project_name = local.project
  environment  = local.environment

  # Enable compliance standards
  enable_cis_standard         = true
  enable_pci_dss              = false
  enable_aws_foundational     = true

  # Findings configuration
  critical_findings_threshold = 1
  high_findings_threshold     = 5

  sns_topic_arn = module.monitoring_cloudwatch.sns_topic_arn

  log_retention_days = 30

  tags = local.common_tags
}

# WAF Module - API protection
module "security_waf" {
  source = "../../modules/security/bedrock-security-waf"

  project_name = local.project
  environment  = local.environment

  waf_scope  = "REGIONAL"
  rate_limit = 2000

  # AWS Managed Rules
  enable_core_rule_exceptions = false
  enable_anonymous_ip_list    = true

  # IP filtering
  blocked_ip_addresses = var.waf_blocked_ips
  allowed_ip_addresses = var.waf_allowed_ips

  # Geo-blocking
  blocked_countries = var.waf_blocked_countries

  # Logging
  enable_waf_logging = true
  log_retention_days = 30
  kms_key_arn        = module.security_kms.bedrock_data_key_arn

  # API Gateway association
  api_gateway_arn = var.api_gateway_arn

  # Alarms
  sns_topic_arn                = module.monitoring_cloudwatch.sns_topic_arn
  blocked_requests_threshold   = 500
  rate_limit_alarm_threshold   = 300

  tags = local.common_tags
}

# Secrets Manager Module - Secrets encryption with rotation
module "security_secrets" {
  source = "../../modules/security/bedrock-security-secrets"

  project_name = local.project
  environment  = local.environment

  # KMS key for secrets encryption
  kms_key_id = module.security_kms.secrets_key_id

  # Rotation enabled for staging
  enable_rotation    = true
  rotation_days      = 30

  # Recovery window
  recovery_window_in_days = 14

  sns_topic_arn = module.monitoring_cloudwatch.sns_topic_arn

  tags = local.common_tags
}

# ==============================================================================
# Monitoring Modules - Enhanced Configuration for Staging
# ==============================================================================

# CloudWatch Module - Dashboards and alarms with anomaly detection
module "monitoring_cloudwatch" {
  source = "../../modules/monitoring/bedrock-monitoring-cloudwatch"

  project_name = local.project
  environment  = local.environment

  # Bedrock agent monitoring
  bedrock_agent_id       = module.bedrock_agent.agent_id
  bedrock_agent_alias_id = module.bedrock_agent.agent_alias_id

  # Lambda functions
  lambda_function_names = var.lambda_function_names

  # Step Functions
  step_function_state_machine_arns = var.step_function_arns

  # API Gateway
  api_gateway_ids = var.api_gateway_ids

  # SNS configuration
  create_sns_topic        = true
  sns_email_subscriptions = [var.alert_email]

  # Alarms - standard thresholds for staging
  bedrock_error_rate_threshold           = 5
  bedrock_invocation_latency_threshold   = 30000  # 30 seconds
  bedrock_throttle_threshold             = 10
  lambda_error_rate_threshold            = 5
  lambda_duration_threshold              = 10000
  lambda_throttles_threshold             = 5
  step_functions_failed_executions_threshold = 5
  step_functions_timed_out_executions_threshold = 3
  api_gateway_5xx_error_threshold        = 5
  api_gateway_latency_threshold          = 5000

  # Anomaly detection - enabled for staging
  enable_anomaly_detection = true
  enable_composite_alarms  = true

  # Dashboard
  create_dashboard = true
  dashboard_name   = "${local.project}-${local.environment}-bedrock"

  # Log groups
  log_group_names = [
    "/aws/bedrock/agents/${local.project}-${local.environment}",
    "/aws/lambda/${local.project}-*"
  ]

  # KMS encryption
  kms_key_id = module.security_kms.bedrock_data_key_id

  tags = local.common_tags
}

# X-Ray Module - Distributed tracing
module "monitoring_xray" {
  source = "../../modules/monitoring/bedrock-monitoring-xray"

  project_name = local.project
  environment  = local.environment

  # X-Ray configuration
  enable_insights       = true
  enable_sampling_rules = true
  sampling_rate         = 0.2  # Sample 20% of requests

  # Tracing configuration
  enable_active_tracing = true

  # KMS encryption
  kms_key_arn = module.security_kms.bedrock_data_key_arn

  # SNS notifications
  sns_topic_arn = module.monitoring_cloudwatch.sns_topic_arn

  tags = local.common_tags
}

# CloudTrail Module - Full audit logging
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
  enable_cloudwatch_logs = true
  log_retention_days     = 30

  # Event selectors - comprehensive for staging
  enable_management_events = true
  enable_data_events       = true
  enable_insights_events   = true

  # Multi-region trail
  is_multi_region_trail = true

  # Log file validation
  enable_log_file_validation = true

  sns_topic_arn = module.monitoring_cloudwatch.sns_topic_arn

  tags = local.common_tags
}

# Config Module - Compliance tracking
module "monitoring_config" {
  source = "../../modules/monitoring/bedrock-monitoring-config"

  project_name = local.project
  environment  = local.environment

  # Configuration recorder
  enable_config_recorder = true
  delivery_frequency     = "Six_Hours"

  # S3 bucket for Config
  create_s3_bucket = true
  s3_bucket_name   = "${local.project}-config-${local.environment}"

  # Config rules
  enable_managed_rules = true

  # KMS encryption
  kms_key_id    = module.security_kms.bedrock_data_key_id
  sns_topic_arn = module.monitoring_cloudwatch.sns_topic_arn

  tags = local.common_tags
}

# EventBridge Module - Event-driven monitoring
module "monitoring_eventbridge" {
  source = "../../modules/monitoring/bedrock-monitoring-eventbridge"

  project_name = local.project
  environment  = local.environment

  # Event patterns
  enable_bedrock_events = true
  enable_lambda_events  = true
  enable_security_events = true

  # Targets
  sns_topic_arn = module.monitoring_cloudwatch.sns_topic_arn

  # Event bus
  create_custom_event_bus = true
  event_bus_name          = "${local.project}-${local.environment}-events"

  # Archive
  enable_event_archive = true
  archive_retention_days = 30

  tags = local.common_tags
}

# Synthetics Module - Endpoint testing
module "monitoring_synthetics" {
  source = "../../modules/monitoring/bedrock-monitoring-synthetics"

  project_name = local.project
  environment  = local.environment

  # Canary configuration
  canary_name     = "${local.project}-agent-canary-${local.environment}"
  canary_schedule = "rate(15 minutes)"

  # Endpoints to test
  endpoints = var.bedrock_agent_endpoints

  # Runtime configuration
  canary_runtime_version = "syn-nodejs-puppeteer-9.0"

  # S3 bucket for artifacts
  create_s3_bucket = true
  s3_bucket_name   = "${local.project}-synthetics-${local.environment}"

  # Alarms
  success_rate_threshold = 90
  duration_threshold     = 10000

  sns_topic_arn = module.monitoring_cloudwatch.sns_topic_arn

  tags = local.common_tags
}

# ==============================================================================
# ServiceNow Integration Module
# ==============================================================================

module "bedrock_servicenow" {
  source = "../../modules/bedrock-servicenow"

  # Environment configuration
  environment = local.environment
  name_prefix = local.project

  # ServiceNow instance configuration
  servicenow_instance_url              = var.servicenow_instance_url
  servicenow_auth_type                 = var.servicenow_auth_type
  servicenow_credentials_secret_arn    = var.servicenow_credentials_secret_arn

  # Feature flags - all features enabled for staging testing
  enable_incident_automation  = true
  enable_ticket_triage        = true
  enable_change_management    = true
  enable_problem_management   = true
  enable_knowledge_sync       = true
  enable_sla_monitoring       = true

  # SLA configuration
  sla_breach_threshold = 80  # 80% threshold for warnings

  # Auto-assignment with standard confidence threshold
  auto_assignment_enabled              = true
  auto_assignment_confidence_threshold = 0.85  # Standard threshold

  # Agent configuration
  agent_model_id         = local.agent_config.model_id
  agent_idle_session_ttl = local.agent_config.idle_session_ttl

  # Lambda configuration - standard
  lambda_runtime     = "python3.12"
  lambda_timeout     = 300  # 5 minutes
  lambda_memory_size = 512  # Standard memory

  # API Gateway configuration
  api_gateway_stage_name     = "staging"
  enable_api_gateway_logging = true

  # DynamoDB configuration
  dynamodb_billing_mode          = "PAY_PER_REQUEST"
  dynamodb_point_in_time_recovery = true

  # Step Functions configuration
  step_function_log_level = "ERROR"

  # Monitoring - enhanced
  enable_enhanced_monitoring = true
  alarm_notification_emails  = [var.alert_email]

  # Security - use KMS keys from security module
  kms_key_id                  = module.security_kms.bedrock_data_key_id
  enable_encryption_at_rest   = true
  enable_encryption_in_transit = true
  sns_kms_master_key_id       = module.security_kms.bedrock_data_key_id

  # Networking - use VPC if available
  vpc_id             = var.servicenow_vpc_id
  subnet_ids         = var.servicenow_subnet_ids
  security_group_ids = var.servicenow_security_group_ids

  # Knowledge base integration
  knowledge_base_ids = [module.bedrock_agent.knowledge_base_id]

  # Knowledge sync schedule (daily at 2 AM)
  knowledge_sync_schedule = "cron(0 2 * * ? *)"

  # Workflow timeouts
  incident_escalation_timeout_minutes = 30
  change_approval_timeout_minutes     = 240  # 4 hours

  # IP restrictions (if applicable)
  allowed_ip_ranges = var.servicenow_allowed_ip_ranges

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

# Security Outputs
output "kms_bedrock_data_key_arn" {
  description = "ARN of the KMS key for Bedrock data encryption"
  value       = module.security_kms.bedrock_data_key_arn
}

output "kms_secrets_key_arn" {
  description = "ARN of the KMS key for secrets encryption"
  value       = module.security_kms.secrets_key_arn
}

output "kms_s3_key_arn" {
  description = "ARN of the KMS key for S3 encryption"
  value       = module.security_kms.s3_key_arn
}

output "bedrock_agent_execution_role_arn" {
  description = "ARN of the Bedrock agent execution role"
  value       = module.security_iam.bedrock_agent_execution_role_arn
}

output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = module.security_iam.lambda_execution_role_arn
}

output "guardduty_detector_id" {
  description = "ID of the GuardDuty detector"
  value       = module.security_guardduty.detector_id
}

output "security_hub_arn" {
  description = "ARN of the Security Hub"
  value       = module.security_hub.security_hub_arn
}

output "waf_web_acl_arn" {
  description = "ARN of the WAF Web ACL"
  value       = module.security_waf.web_acl_arn
}

# Monitoring Outputs
output "monitoring_dashboard_name" {
  description = "Name of the CloudWatch monitoring dashboard"
  value       = module.monitoring_cloudwatch.dashboard_name
}

output "monitoring_dashboard_url" {
  description = "URL of the CloudWatch monitoring dashboard"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${module.monitoring_cloudwatch.dashboard_name}"
}

output "monitoring_sns_topic_arn" {
  description = "ARN of the monitoring SNS topic"
  value       = module.monitoring_cloudwatch.sns_topic_arn
}

output "xray_group_name" {
  description = "Name of the X-Ray group"
  value       = module.monitoring_xray.group_name
}

output "cloudtrail_log_group" {
  description = "CloudTrail log group name"
  value       = module.monitoring_cloudtrail.log_group_name
}

output "cloudtrail_s3_bucket" {
  description = "S3 bucket for CloudTrail logs"
  value       = module.monitoring_cloudtrail.s3_bucket_name
}

output "config_recorder_name" {
  description = "Name of the AWS Config recorder"
  value       = module.monitoring_config.recorder_name
}

output "synthetics_canary_name" {
  description = "Name of the CloudWatch Synthetics canary"
  value       = module.monitoring_synthetics.canary_name
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

output "servicenow_incident_workflow_arn" {
  description = "Step Functions ARN for incident workflow"
  value       = module.bedrock_servicenow.incident_workflow_arn
}

output "servicenow_change_workflow_arn" {
  description = "Step Functions ARN for change workflow"
  value       = module.bedrock_servicenow.change_workflow_arn
}
