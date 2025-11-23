# ServiceNow Configuration
variable "servicenow_instance_url" {
  description = "ServiceNow instance URL (e.g., https://your-instance.service-now.com)"
  type        = string

  validation {
    condition     = can(regex("^https://.*\\.service-now\\.com$", var.servicenow_instance_url))
    error_message = "ServiceNow instance URL must be a valid HTTPS URL ending with .service-now.com"
  }
}

variable "servicenow_auth_type" {
  description = "Authentication type for ServiceNow API (oauth or basic)"
  type        = string
  default     = "oauth"

  validation {
    condition     = contains(["oauth", "basic"], var.servicenow_auth_type)
    error_message = "Authentication type must be either 'oauth' or 'basic'"
  }
}

variable "servicenow_credentials_secret_arn" {
  description = "ARN of existing Secrets Manager secret containing ServiceNow credentials (optional)"
  type        = string
  default     = null
}

# Feature Flags
variable "enable_incident_automation" {
  description = "Enable automated incident management"
  type        = bool
  default     = true
}

variable "enable_ticket_triage" {
  description = "Enable AI-powered ticket triage"
  type        = bool
  default     = true
}

variable "enable_change_management" {
  description = "Enable change management automation"
  type        = bool
  default     = true
}

variable "enable_problem_management" {
  description = "Enable problem management automation"
  type        = bool
  default     = true
}

variable "enable_knowledge_sync" {
  description = "Enable knowledge base synchronization"
  type        = bool
  default     = true
}

variable "enable_sla_monitoring" {
  description = "Enable SLA monitoring and alerting"
  type        = bool
  default     = true
}

# SLA Configuration
variable "sla_breach_threshold" {
  description = "Percentage threshold for SLA breach warnings (0-100)"
  type        = number
  default     = 80

  validation {
    condition     = var.sla_breach_threshold >= 0 && var.sla_breach_threshold <= 100
    error_message = "SLA breach threshold must be between 0 and 100"
  }
}

# Auto-assignment Configuration
variable "auto_assignment_enabled" {
  description = "Enable automatic ticket assignment based on AI analysis"
  type        = bool
  default     = true
}

variable "auto_assignment_confidence_threshold" {
  description = "Minimum confidence score (0-1) required for auto-assignment"
  type        = number
  default     = 0.85

  validation {
    condition     = var.auto_assignment_confidence_threshold >= 0 && var.auto_assignment_confidence_threshold <= 1
    error_message = "Confidence threshold must be between 0 and 1"
  }
}

# Agent Configuration
variable "agent_model_id" {
  description = "Bedrock model ID for agents"
  type        = string
  default     = "anthropic.claude-3-5-sonnet-20241022-v2:0"
}

variable "agent_idle_session_ttl" {
  description = "Idle session timeout for agents in seconds"
  type        = number
  default     = 1800
}

# Lambda Configuration
variable "lambda_runtime" {
  description = "Lambda runtime for ServiceNow integration functions"
  type        = string
  default     = "python3.12"
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 300
}

variable "lambda_memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 512
}

# API Gateway Configuration
variable "api_gateway_stage_name" {
  description = "API Gateway stage name"
  type        = string
  default     = "prod"
}

variable "enable_api_gateway_logging" {
  description = "Enable API Gateway access logging"
  type        = bool
  default     = true
}

# DynamoDB Configuration
variable "dynamodb_billing_mode" {
  description = "DynamoDB billing mode (PROVISIONED or PAY_PER_REQUEST)"
  type        = string
  default     = "PAY_PER_REQUEST"

  validation {
    condition     = contains(["PROVISIONED", "PAY_PER_REQUEST"], var.dynamodb_billing_mode)
    error_message = "Billing mode must be either 'PROVISIONED' or 'PAY_PER_REQUEST'"
  }
}

variable "dynamodb_point_in_time_recovery" {
  description = "Enable DynamoDB point-in-time recovery"
  type        = bool
  default     = true
}

# Step Functions Configuration
variable "step_function_log_level" {
  description = "Step Functions log level (ALL, ERROR, FATAL, OFF)"
  type        = string
  default     = "ERROR"

  validation {
    condition     = contains(["ALL", "ERROR", "FATAL", "OFF"], var.step_function_log_level)
    error_message = "Log level must be ALL, ERROR, FATAL, or OFF"
  }
}

# Monitoring Configuration
variable "enable_enhanced_monitoring" {
  description = "Enable enhanced CloudWatch monitoring"
  type        = bool
  default     = true
}

variable "alarm_notification_emails" {
  description = "List of email addresses for alarm notifications"
  type        = list(string)
  default     = []
}

variable "sns_kms_master_key_id" {
  description = "KMS key ID for SNS topic encryption"
  type        = string
  default     = null
}

# Knowledge Base Configuration
variable "knowledge_base_ids" {
  description = "List of existing knowledge base IDs to associate with agents"
  type        = list(string)
  default     = []
}

variable "knowledge_sync_schedule" {
  description = "Cron expression for knowledge base sync schedule"
  type        = string
  default     = "cron(0 2 * * ? *)" # Daily at 2 AM UTC
}

# Workflow Configuration
variable "incident_escalation_timeout_minutes" {
  description = "Timeout in minutes before escalating unresolved incidents"
  type        = number
  default     = 30
}

variable "change_approval_timeout_minutes" {
  description = "Timeout in minutes for change approval workflows"
  type        = number
  default     = 240
}

# Security Configuration
variable "kms_key_id" {
  description = "KMS key ID for encryption (optional, will create new key if not provided)"
  type        = string
  default     = null
}

variable "enable_encryption_at_rest" {
  description = "Enable encryption at rest for all resources"
  type        = bool
  default     = true
}

variable "allowed_ip_ranges" {
  description = "List of CIDR blocks allowed to access API Gateway webhooks"
  type        = list(string)
  default     = []
}

# Networking Configuration
variable "vpc_id" {
  description = "VPC ID for Lambda functions (optional, for VPC-deployed Lambdas)"
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "Subnet IDs for Lambda functions (required if vpc_id is provided)"
  type        = list(string)
  default     = []
}

variable "security_group_ids" {
  description = "Security group IDs for Lambda functions (optional)"
  type        = list(string)
  default     = []
}

# Tagging
variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod"
  }
}

# Naming
variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "servicenow"
}
