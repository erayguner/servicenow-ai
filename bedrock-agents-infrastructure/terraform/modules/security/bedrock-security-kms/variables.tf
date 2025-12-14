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
  default     = "eu-west-2"
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for v in values(var.tags) : can(regex("^[\\p{L}\\p{Z}\\p{N}_.:/=+\\-@]*$", v))
    ])
    error_message = "Tag values may only contain letters, numbers, spaces, and the following special characters: _ . : / = + - @"
  }
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
  default     = ""
}

variable "enable_cloudtrail_metrics" {
  description = "Enable CloudWatch metric filters based on CloudTrail log group. Set to false to avoid circular dependencies when CloudTrail depends on this KMS module."
  type        = bool
  default     = true
}

variable "kms_error_threshold" {
  description = "Threshold for KMS API error alarms"
  type        = number
  default     = 10
}
