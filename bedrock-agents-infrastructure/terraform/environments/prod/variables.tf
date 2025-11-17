# Production Environment Variables

variable "aws_region" {
  description = "Primary AWS region for Bedrock resources"
  type        = string
  default     = "us-east-1"
}

variable "secondary_region" {
  description = "Secondary AWS region for failover"
  type        = string
  default     = "us-west-2"
}

variable "dr_region" {
  description = "Disaster recovery region"
  type        = string
  default     = "eu-west-1"
}

variable "owner_email" {
  description = "Email of the resource owner"
  type        = string
}

variable "agent_instruction" {
  description = "Instructions for the Bedrock agent"
  type        = string
  default     = <<-EOT
    You are a ServiceNow AI assistant in production environment.
    Provide accurate, reliable, and secure responses for ServiceNow operations.
    Prioritize data integrity, security, and compliance in all interactions.
    Follow enterprise security policies and audit requirements.
    Maintain high availability and performance standards.
  EOT
}

variable "data_source_bucket_arn" {
  description = "ARN of S3 bucket containing knowledge base data (primary)"
  type        = string
}

variable "data_source_bucket_arn_secondary" {
  description = "ARN of S3 bucket containing knowledge base data (secondary)"
  type        = string
}

variable "action_lambda_arn" {
  description = "ARN of Lambda function for agent actions (primary)"
  type        = string
}

variable "action_lambda_arn_secondary" {
  description = "ARN of Lambda function for agent actions (secondary)"
  type        = string
}

variable "alert_email" {
  description = "Primary email address for critical alerts"
  type        = string
}

variable "alert_sns_topic_arn" {
  description = "SNS topic ARN for alerts and notifications"
  type        = string
}

# State backend variables
variable "state_bucket_name" {
  description = "S3 bucket name for Terraform state"
  type        = string
  default     = "servicenow-ai-terraform-state-prod"
}

variable "state_lock_table_name" {
  description = "DynamoDB table name for state locking"
  type        = string
  default     = "servicenow-ai-terraform-locks-prod"
}

# PagerDuty integration
variable "enable_pagerduty" {
  description = "Enable PagerDuty integration for critical alerts"
  type        = bool
  default     = true
}

variable "pagerduty_integration_key" {
  description = "PagerDuty integration key"
  type        = string
  sensitive   = true
  default     = ""
}

# WAF configuration
variable "waf_rules" {
  description = "WAF rules for API protection"
  type = list(object({
    name     = string
    priority = number
    action   = string
  }))
  default = [
    {
      name     = "rate-limit"
      priority = 1
      action   = "block"
    },
    {
      name     = "geo-blocking"
      priority = 2
      action   = "block"
    },
    {
      name     = "sql-injection"
      priority = 3
      action   = "block"
    }
  ]
}

variable "enable_shield_advanced" {
  description = "Enable AWS Shield Advanced for DDoS protection"
  type        = bool
  default     = true
}

# Encryption
variable "kms_key_id" {
  description = "KMS key ID for encryption at rest"
  type        = string
}

# Synthetic monitoring
variable "synthetic_test_scenarios" {
  description = "Synthetic monitoring test scenarios"
  type = list(object({
    name        = string
    description = string
    frequency   = string
  }))
  default = [
    {
      name        = "agent-health-check"
      description = "Basic agent health and availability"
      frequency   = "5min"
    },
    {
      name        = "knowledge-base-query"
      description = "Knowledge base retrieval test"
      frequency   = "10min"
    },
    {
      name        = "action-group-execution"
      description = "Action group functionality test"
      frequency   = "15min"
    }
  ]
}

# Auto-scaling configuration
variable "auto_scaling_config" {
  description = "Auto-scaling configuration"
  type = object({
    min_instances     = number
    max_instances     = number
    desired_instances = number
    scale_up_threshold   = number
    scale_down_threshold = number
  })
  default = {
    min_instances        = 5
    max_instances        = 20
    desired_instances    = 8
    scale_up_threshold   = 70
    scale_down_threshold = 30
  }
}

# Performance configuration
variable "performance_config" {
  description = "Performance and throughput configuration"
  type = object({
    provisioned_units        = number
    cache_ttl_seconds        = number
    max_concurrent_requests  = number
    lambda_provisioned_capacity = number
  })
  default = {
    provisioned_units           = 100
    cache_ttl_seconds           = 3600
    max_concurrent_requests     = 100
    lambda_provisioned_capacity = 10
  }
}

# Backup configuration
variable "backup_config" {
  description = "Backup and recovery configuration"
  type = object({
    retention_days              = number
    schedule                    = string
    enable_point_in_time_recovery = bool
  })
  default = {
    retention_days                = 30
    schedule                      = "cron(0 2 * * ? *)"
    enable_point_in_time_recovery = true
  }
}

# Monitoring thresholds
variable "monitoring_thresholds" {
  description = "CloudWatch monitoring and alerting thresholds"
  type = object({
    error_rate_percent   = number
    latency_ms           = number
    availability_percent = number
    throttle_count       = number
  })
  default = {
    error_rate_percent   = 0.05  # 5%
    latency_ms           = 2000
    availability_percent = 99.9
    throttle_count       = 1000
  }
}

# Compliance configuration
variable "compliance_config" {
  description = "Compliance and regulatory requirements"
  type = object({
    frameworks            = list(string)
    enable_audit_logging  = bool
    log_retention_days    = number
    enable_encryption     = bool
  })
  default = {
    frameworks           = ["sox", "pci", "hipaa"]
    enable_audit_logging = true
    log_retention_days   = 90
    enable_encryption    = true
  }
}

# Business continuity
variable "business_continuity_config" {
  description = "Business continuity and disaster recovery configuration"
  type = object({
    enable_multi_region          = bool
    enable_automatic_failover    = bool
    rpo_minutes                  = number  # Recovery Point Objective
    rto_minutes                  = number  # Recovery Time Objective
  })
  default = {
    enable_multi_region       = true
    enable_automatic_failover = true
    rpo_minutes               = 15
    rto_minutes               = 30
  }
}

# Cost management
variable "cost_allocation_tags" {
  description = "Additional cost allocation tags"
  type        = map(string)
  default = {
    Department     = "Engineering"
    Application    = "ServiceNow-AI"
    CostCenter     = "PROD-OPS"
    BusinessUnit   = "IT-Operations"
  }
}

# Change management
variable "change_window" {
  description = "Approved change window for maintenance"
  type = object({
    day_of_week  = string
    start_hour   = number
    duration_hours = number
  })
  default = {
    day_of_week    = "Sunday"
    start_hour     = 2  # 2 AM
    duration_hours = 4
  }
}

# Security configuration
variable "security_config" {
  description = "Security and access control configuration"
  type = object({
    enable_waf                = bool
    enable_shield_advanced    = bool
    enable_secrets_rotation   = bool
    mfa_required              = bool
    ip_whitelist              = list(string)
  })
  default = {
    enable_waf              = true
    enable_shield_advanced  = true
    enable_secrets_rotation = true
    mfa_required            = true
    ip_whitelist            = []
  }
}

# Operational contacts
variable "operational_contacts" {
  description = "Operational contact information"
  type = object({
    primary_oncall   = string
    secondary_oncall = string
    escalation_email = string
    slack_channel    = string
  })
  default = {
    primary_oncall   = "primary-oncall@example.com"
    secondary_oncall = "secondary-oncall@example.com"
    escalation_email = "engineering-leads@example.com"
    slack_channel    = "#prod-alerts"
  }
}

# ==============================================================================
# Security Module Variables
# ==============================================================================

variable "kms_key_admin_arns" {
  description = "List of IAM role/user ARNs that can administer KMS keys"
  type        = list(string)
  default     = []
}

variable "kms_grant_role_arns" {
  description = "List of IAM role ARNs that can use KMS keys via grants"
  type        = list(string)
  default     = []
}

variable "dynamodb_table_arns" {
  description = "List of DynamoDB table ARNs for Lambda access"
  type        = list(string)
  default     = []
}

variable "enable_cross_account_access" {
  description = "Enable cross-account IAM access"
  type        = bool
  default     = false
}

variable "trusted_account_ids" {
  description = "List of trusted AWS account IDs for cross-account access"
  type        = list(string)
  default     = []
}

variable "cross_account_external_id" {
  description = "External ID for cross-account access"
  type        = string
  default     = ""
  sensitive   = true
}

variable "waf_blocked_ips" {
  description = "List of IP addresses to block in WAF (CIDR notation)"
  type        = list(string)
  default     = []
}

variable "waf_allowed_ips" {
  description = "List of IP addresses to allow in WAF (CIDR notation)"
  type        = list(string)
  default     = []
}

variable "waf_blocked_countries" {
  description = "List of country codes to block (ISO 3166-1 alpha-2)"
  type        = list(string)
  default     = []
}

variable "require_api_key" {
  description = "Require API key header for requests"
  type        = bool
  default     = true
}

variable "api_key_value" {
  description = "Expected value of the API key header"
  type        = string
  default     = ""
  sensitive   = true
}

variable "api_gateway_arn_primary" {
  description = "ARN of the API Gateway to associate with WAF (primary region)"
  type        = string
  default     = ""
}

variable "api_gateway_arn_secondary" {
  description = "ARN of the API Gateway to associate with WAF (secondary region)"
  type        = string
  default     = ""
}

variable "enable_guardduty_org_config" {
  description = "Enable organization-wide GuardDuty configuration"
  type        = bool
  default     = false
}

variable "threat_intel_location" {
  description = "S3 location of custom threat intelligence set"
  type        = string
  default     = ""
}

variable "trusted_ip_set_location" {
  description = "S3 location of trusted IP set"
  type        = string
  default     = ""
}

variable "guardduty_processor_zip_path" {
  description = "Path to Lambda function zip file for GuardDuty findings processor"
  type        = string
  default     = ""
}

variable "critical_alert_sns_topic_arn" {
  description = "SNS topic ARN for critical security alerts"
  type        = string
  default     = ""
}

variable "enable_pci_compliance" {
  description = "Enable PCI-DSS compliance framework in Security Hub"
  type        = bool
  default     = false
}

variable "enable_nist_compliance" {
  description = "Enable NIST framework in Security Hub"
  type        = bool
  default     = false
}

variable "enable_security_hub_org_config" {
  description = "Enable organization-wide Security Hub configuration"
  type        = bool
  default     = false
}

# ==============================================================================
# Monitoring Module Variables
# ==============================================================================

variable "lambda_function_names" {
  description = "List of Lambda function names to monitor"
  type        = list(string)
  default     = []
}

variable "step_function_arns" {
  description = "List of Step Functions state machine ARNs to monitor"
  type        = list(string)
  default     = []
}

variable "api_gateway_ids" {
  description = "List of API Gateway REST API IDs to monitor"
  type        = list(string)
  default     = []
}

variable "alert_email_addresses" {
  description = "List of email addresses for monitoring alerts"
  type        = list(string)
  default     = []
}

variable "bedrock_agent_endpoints_primary" {
  description = "List of Bedrock agent endpoints for synthetic monitoring (primary region)"
  type        = list(string)
  default     = []
}

variable "bedrock_agent_endpoints_secondary" {
  description = "List of Bedrock agent endpoints for synthetic monitoring (secondary region)"
  type        = list(string)
  default     = []
}

variable "enable_mfa_delete" {
  description = "Enable MFA delete for CloudTrail S3 bucket"
  type        = bool
  default     = true
}

variable "enable_organization_trail" {
  description = "Enable organization-wide CloudTrail"
  type        = bool
  default     = false
}

variable "config_custom_rules" {
  description = "List of custom AWS Config rules"
  type        = list(any)
  default     = []
}

variable "enable_config_aggregator" {
  description = "Enable AWS Config aggregator"
  type        = bool
  default     = false
}

variable "config_aggregator_accounts" {
  description = "List of AWS account IDs for Config aggregator"
  type        = list(string)
  default     = []
}

variable "enable_synthetics_vpc" {
  description = "Enable VPC configuration for CloudWatch Synthetics"
  type        = bool
  default     = false
}

variable "synthetics_vpc_id" {
  description = "VPC ID for CloudWatch Synthetics canaries"
  type        = string
  default     = ""
}

variable "synthetics_subnet_ids" {
  description = "List of subnet IDs for CloudWatch Synthetics canaries"
  type        = list(string)
  default     = []
}
