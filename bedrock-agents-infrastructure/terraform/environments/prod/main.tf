# Production Environment - Full HA Configuration
# Auto-scaling agents, provisioned throughput, complete monitoring, multi-region support

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
    bucket         = "servicenow-ai-terraform-state-prod"
    key            = "bedrock-agents/prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "servicenow-ai-terraform-locks-prod"

    # Enable state locking and consistency checking
    kms_key_id = "alias/terraform-state-key-prod"

    # Workspace support for blue/green deployments
    workspace_key_prefix = "workspaces"
  }
}

# Local variables for environment configuration
locals {
  environment = "prod"
  project     = "servicenow-ai"

  # Production tags
  common_tags = {
    Environment        = "prod"
    Project            = "servicenow-ai"
    ManagedBy          = "terraform"
    CostCenter         = "production-operations"
    Owner              = var.owner_email
    AutoShutdown       = "false"
    BackupRequired     = "true"
    Compliance         = "sox-pci-hipaa"
    DataClassification = "highly-confidential"
    DisasterRecovery   = "enabled"
    BusinessCriticality = "tier-1"
  }

  # Full HA configuration for production
  agent_config = {
    min_instances           = 5
    max_instances           = 20
    desired_instances       = 8
    model_id                = "anthropic.claude-3-5-sonnet-20241022-v2:0"
    enable_trace            = true
    idle_session_ttl        = 3600  # 1 hour
    enable_provisioned      = true
    provisioned_units       = 100
    pricing_model           = "provisioned"
  }

  # Enterprise knowledge base configuration
  knowledge_base_config = {
    enabled             = true
    storage_type        = "opensearch-provisioned"
    embedding_model     = "cohere.embed-english-v3"
    chunking_strategy   = "semantic"
    chunk_size          = 1024
    chunk_overlap       = 100
    max_tokens          = 2048
    enable_reranking    = true
  }

  # All action groups for production
  action_groups = {
    enabled = true
    groups  = [
      "servicenow-read",
      "servicenow-write",
      "servicenow-query",
      "servicenow-admin",
      "analytics-actions",
      "notification-actions",
      "workflow-actions",
      "integration-actions",
      "security-actions",
      "compliance-actions"
    ]
  }

  # Advanced orchestration configuration
  orchestration_config = {
    enabled                    = true
    max_concurrent_invocations = 100
    prompt_override_enabled    = true
    enable_code_interpretation = true
    enable_memory_optimization = true
    enable_caching             = true
  }

  # Multi-region configuration
  regions = {
    primary   = "us-east-1"
    secondary = "us-west-2"
    dr        = "eu-west-1"
  }
}

# Primary Region Bedrock Agent Module
module "bedrock_agent_primary" {
  source = "../../modules/bedrock-agent"

  providers = {
    aws = aws
  }

  # Environment configuration
  environment = local.environment
  project     = local.project
  region      = local.regions.primary

  # Agent configuration
  agent_name               = "${local.project}-agent-${local.environment}-primary"
  agent_description        = "Production Bedrock agent for ServiceNow AI (Primary Region)"
  foundation_model         = local.agent_config.model_id
  instruction              = var.agent_instruction
  idle_session_ttl_seconds = local.agent_config.idle_session_ttl

  # Auto-scaling configuration
  enable_auto_scaling     = true
  min_agent_instances     = local.agent_config.min_instances
  max_agent_instances     = local.agent_config.max_instances
  desired_agent_instances = local.agent_config.desired_instances

  # Scaling policies
  scale_up_threshold   = 70   # CPU/Memory percentage
  scale_down_threshold = 30
  scale_up_cooldown    = 60   # seconds
  scale_down_cooldown  = 300

  # Provisioned throughput for consistent performance
  enable_provisioned_throughput = local.agent_config.enable_provisioned
  provisioned_model_units       = local.agent_config.provisioned_units

  # Enable comprehensive tracing
  enable_trace_logging = local.agent_config.enable_trace

  # Knowledge Base configuration
  enable_knowledge_base      = local.knowledge_base_config.enabled
  knowledge_base_name        = "${local.project}-kb-${local.environment}-primary"
  knowledge_base_description = "Production knowledge base for ServiceNow AI (Primary)"

  # Provisioned OpenSearch for production performance
  knowledge_base_storage_type = local.knowledge_base_config.storage_type
  embedding_model_arn         = "arn:aws:bedrock:${local.regions.primary}::foundation-model/${local.knowledge_base_config.embedding_model}"

  # Advanced chunking and retrieval
  chunking_strategy   = local.knowledge_base_config.chunking_strategy
  chunk_size          = local.knowledge_base_config.chunk_size
  chunk_overlap       = local.knowledge_base_config.chunk_overlap
  max_tokens          = local.knowledge_base_config.max_tokens
  enable_reranking    = local.knowledge_base_config.enable_reranking
  reranking_model_arn = "arn:aws:bedrock:${local.regions.primary}::foundation-model/cohere.rerank-v3:0"

  # S3 data source with versioning
  data_source_bucket_arn = var.data_source_bucket_arn
  data_source_prefix     = "prod/"
  enable_versioning      = true

  # Action Groups - All enabled
  enable_action_groups = local.action_groups.enabled
  action_groups        = local.action_groups.groups

  # Lambda function for actions (HA configuration)
  action_lambda_arn           = var.action_lambda_arn
  enable_lambda_provisioned   = true
  lambda_provisioned_capacity = 10

  # Advanced orchestration
  enable_orchestration           = local.orchestration_config.enabled
  max_concurrent_invocations     = local.orchestration_config.max_concurrent_invocations
  enable_prompt_override         = local.orchestration_config.prompt_override_enabled
  enable_code_interpretation     = local.orchestration_config.enable_code_interpretation
  enable_memory_optimization     = local.orchestration_config.enable_memory_optimization
  enable_caching                 = local.orchestration_config.enable_caching
  cache_ttl_seconds              = 3600

  # IAM roles
  agent_role_name = "${local.project}-bedrock-agent-role-${local.environment}-primary"

  # Monitoring - Full observability
  enable_cloudwatch_logs  = true
  log_retention_days      = 90  # 90 days for production
  enable_log_insights     = true

  enable_xray_tracing     = true
  enable_detailed_metrics = true
  enable_custom_metrics   = true

  # CloudWatch dashboards
  enable_dashboard        = true
  dashboard_name          = "${local.project}-${local.environment}-primary"

  # Alerting - Comprehensive
  enable_alerting              = true
  alert_email                  = var.alert_email
  alert_sns_topic_arn          = var.alert_sns_topic_arn
  throttle_threshold           = 1000
  error_rate_threshold         = 0.05  # 5% error rate
  latency_threshold_ms         = 2000
  availability_threshold       = 99.9

  # PagerDuty integration
  enable_pagerduty            = var.enable_pagerduty
  pagerduty_integration_key   = var.pagerduty_integration_key

  # Backup - Production grade
  enable_backup         = true
  backup_retention_days = 30
  backup_schedule       = "cron(0 2 * * ? *)"  # Daily at 2 AM
  enable_point_in_time_recovery = true

  # High availability
  enable_multi_az = true
  availability_zones = [
    "${local.regions.primary}a",
    "${local.regions.primary}b",
    "${local.regions.primary}c"
  ]

  # WAF protection
  enable_waf              = true
  waf_rules               = var.waf_rules
  enable_rate_limiting    = true
  rate_limit_requests     = 10000  # per 5 minutes

  # DDoS protection
  enable_shield_advanced = var.enable_shield_advanced

  # Encryption
  enable_encryption_at_rest    = true
  kms_key_id                   = var.kms_key_id
  enable_encryption_in_transit = true

  # Compliance
  enable_compliance_logging = true
  compliance_frameworks     = ["sox", "pci", "hipaa"]

  # Tags
  tags = local.common_tags
}

# Secondary Region Bedrock Agent Module (Failover)
module "bedrock_agent_secondary" {
  source = "../../modules/bedrock-agent"

  providers = {
    aws = aws.secondary
  }

  # Same configuration as primary
  environment = local.environment
  project     = local.project
  region      = local.regions.secondary

  agent_name               = "${local.project}-agent-${local.environment}-secondary"
  agent_description        = "Production Bedrock agent for ServiceNow AI (Secondary Region)"
  foundation_model         = local.agent_config.model_id
  instruction              = var.agent_instruction
  idle_session_ttl_seconds = local.agent_config.idle_session_ttl

  # Same scaling configuration
  enable_auto_scaling     = true
  min_agent_instances     = local.agent_config.min_instances
  max_agent_instances     = local.agent_config.max_instances
  desired_agent_instances = local.agent_config.desired_instances

  # Same performance settings
  enable_provisioned_throughput = local.agent_config.enable_provisioned
  provisioned_model_units       = local.agent_config.provisioned_units

  # Knowledge base replication
  enable_knowledge_base       = local.knowledge_base_config.enabled
  knowledge_base_name         = "${local.project}-kb-${local.environment}-secondary"
  knowledge_base_storage_type = local.knowledge_base_config.storage_type
  enable_cross_region_replication = true
  replication_source_kb_id    = module.bedrock_agent_primary.knowledge_base_id

  # Other settings match primary
  enable_action_groups = local.action_groups.enabled
  action_groups        = local.action_groups.groups
  action_lambda_arn    = var.action_lambda_arn_secondary

  tags = merge(local.common_tags, { Region = "secondary" })
}

# Global Traffic Manager for multi-region routing
module "global_traffic_manager" {
  source = "../../modules/traffic-manager"

  environment = local.environment
  project     = local.project

  # Primary and secondary endpoints
  primary_agent_id   = module.bedrock_agent_primary.agent_id
  secondary_agent_id = module.bedrock_agent_secondary.agent_id

  primary_region   = local.regions.primary
  secondary_region = local.regions.secondary

  # Health check configuration
  health_check_enabled      = true
  health_check_interval     = 30
  health_check_path         = "/health"
  health_check_timeout      = 10
  health_check_threshold    = 3

  # Routing policy
  routing_policy = "latency"  # or "failover", "geolocation"

  # Failover configuration
  enable_automatic_failover = true
  failover_threshold        = 5  # failures before failover

  tags = local.common_tags
}

# CloudWatch Synthetics for continuous monitoring
module "synthetic_monitoring" {
  source = "../../modules/synthetic-monitoring"

  environment = local.environment
  project     = local.project

  # Canary configuration
  canary_name     = "${local.project}-agent-canary-${local.environment}"
  canary_schedule = "rate(5 minutes)"

  # Endpoints to monitor
  endpoints = [
    module.bedrock_agent_primary.agent_endpoint,
    module.bedrock_agent_secondary.agent_endpoint
  ]

  # Test scenarios
  test_scenarios = var.synthetic_test_scenarios

  # Alerting
  alert_sns_topic_arn = var.alert_sns_topic_arn

  tags = local.common_tags
}

# Outputs
output "primary_agent_id" {
  description = "Primary Bedrock agent ID"
  value       = module.bedrock_agent_primary.agent_id
}

output "secondary_agent_id" {
  description = "Secondary Bedrock agent ID"
  value       = module.bedrock_agent_secondary.agent_id
}

output "global_endpoint" {
  description = "Global traffic manager endpoint"
  value       = module.global_traffic_manager.endpoint
}

output "primary_agent_endpoint" {
  description = "Primary agent endpoint"
  value       = module.bedrock_agent_primary.agent_endpoint
}

output "secondary_agent_endpoint" {
  description = "Secondary agent endpoint"
  value       = module.bedrock_agent_secondary.agent_endpoint
}
