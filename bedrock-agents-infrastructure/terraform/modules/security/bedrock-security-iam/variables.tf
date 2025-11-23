# ==============================================================================
# Bedrock Security IAM Module - Variables
# ==============================================================================

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = can(regex("^(dev|staging|prod)$", var.environment))
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}

# ==============================================================================
# IAM Configuration
# ==============================================================================

variable "enable_permission_boundary" {
  description = "Enable permission boundaries for IAM roles"
  type        = bool
  default     = true
}

variable "max_session_duration" {
  description = "Maximum session duration for IAM roles (in seconds)"
  type        = number
  default     = 3600

  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "Session duration must be between 3600 and 43200 seconds."
  }
}

variable "allowed_regions" {
  description = "List of allowed AWS regions for permission boundary"
  type        = list(string)
  default     = ["us-east-1", "us-west-2"]
}

# ==============================================================================
# Bedrock Configuration
# ==============================================================================

variable "allowed_bedrock_models" {
  description = "List of allowed Bedrock model ARNs"
  type        = list(string)
  default = [
    "arn:aws:bedrock:*::foundation-model/anthropic.claude-v2",
    "arn:aws:bedrock:*::foundation-model/anthropic.claude-v2:1",
    "arn:aws:bedrock:*::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0",
    "arn:aws:bedrock:*::foundation-model/anthropic.claude-3-haiku-20240307-v1:0"
  ]
}

variable "knowledge_base_arns" {
  description = "List of Bedrock knowledge base ARNs"
  type        = list(string)
  default     = []
}

# ==============================================================================
# Lambda Configuration
# ==============================================================================

variable "dynamodb_table_arns" {
  description = "List of DynamoDB table ARNs for Lambda access"
  type        = list(string)
  default     = []
}

variable "kms_key_arns" {
  description = "List of KMS key ARNs for encryption/decryption"
  type        = list(string)
  default     = []
}

# ==============================================================================
# Step Functions Configuration
# ==============================================================================

variable "enable_step_functions" {
  description = "Enable Step Functions execution role"
  type        = bool
  default     = false
}

# ==============================================================================
# Cross-Account Access Configuration
# ==============================================================================

variable "enable_cross_account_access" {
  description = "Enable cross-account access role"
  type        = bool
  default     = false
}

variable "trusted_account_ids" {
  description = "List of trusted AWS account IDs for cross-account access"
  type        = list(string)
  default     = []
}

variable "external_id" {
  description = "External ID for cross-account access"
  type        = string
  default     = ""
  sensitive   = true
}

# ==============================================================================
# CloudWatch Configuration
# ==============================================================================

variable "cloudtrail_log_group_name" {
  description = "CloudTrail log group name for metric filters"
  type        = string
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for security alarms"
  type        = string
}

variable "unauthorized_calls_threshold" {
  description = "Threshold for unauthorized API calls alarm"
  type        = number
  default     = 5
}

# ==============================================================================
# ABAC Configuration
# ==============================================================================

variable "enable_abac" {
  description = "Enable Attribute-Based Access Control (ABAC)"
  type        = bool
  default     = true
}
