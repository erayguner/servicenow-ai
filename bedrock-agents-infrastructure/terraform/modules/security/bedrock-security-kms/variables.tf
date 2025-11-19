# ==============================================================================
# Bedrock Security KMS Module - Variables
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
# KMS Key Configuration
# ==============================================================================

variable "deletion_window_in_days" {
  description = "Number of days before KMS key deletion (7-30)"
  type        = number
  default     = 30

  validation {
    condition     = var.deletion_window_in_days >= 7 && var.deletion_window_in_days <= 30
    error_message = "Deletion window must be between 7 and 30 days."
  }
}

variable "enable_key_rotation" {
  description = "Enable automatic key rotation for KMS keys"
  type        = bool
  default     = true
}

variable "enable_multi_region" {
  description = "Enable multi-region KMS keys for disaster recovery"
  type        = bool
  default     = false
}

# ==============================================================================
# IAM Configuration
# ==============================================================================

variable "iam_role_arns" {
  description = "List of IAM role ARNs that can use the KMS keys"
  type        = list(string)
  default     = []
}

variable "key_admin_arns" {
  description = "List of IAM ARNs that can administer the KMS keys"
  type        = list(string)
  default     = []
}

variable "grant_role_arns" {
  description = "List of IAM role ARNs for KMS grants"
  type        = list(string)
  default     = []
}

# ==============================================================================
# CloudWatch Configuration
# ==============================================================================

variable "sns_topic_arn" {
  description = "SNS topic ARN for KMS alarms"
  type        = string
}

variable "cloudtrail_log_group_name" {
  description = "CloudTrail log group name for metric filters"
  type        = string
}

variable "kms_error_threshold" {
  description = "Threshold for KMS API error alarms"
  type        = number
  default     = 10
}

# ==============================================================================
# Key Policy Configuration
# ==============================================================================

variable "allow_bedrock_service" {
  description = "Allow Bedrock service to use KMS keys"
  type        = bool
  default     = true
}

variable "allow_lambda_service" {
  description = "Allow Lambda service to use KMS keys"
  type        = bool
  default     = true
}

variable "allow_cloudwatch_logs" {
  description = "Allow CloudWatch Logs to use KMS keys"
  type        = bool
  default     = true
}

variable "allow_s3_service" {
  description = "Allow S3 service to use KMS keys"
  type        = bool
  default     = true
}

variable "allow_secrets_manager" {
  description = "Allow Secrets Manager to use KMS keys"
  type        = bool
  default     = true
}
