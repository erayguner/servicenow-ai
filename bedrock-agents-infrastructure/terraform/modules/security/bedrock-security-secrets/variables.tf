# ==============================================================================
# Bedrock Security Secrets Module - Variables
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

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)

  default = {}

  validation {
    condition = alltrue([
      for v in values(var.tags) : can(regex("^[\\p{L}\\p{Z}\\p{N}_.:/=+\\-@]*$", v))
    ])
    error_message = "Tag values may only contain letters, numbers, spaces, and the following special characters: _ . : / = + - @"
  }
}

# ==============================================================================
# Secrets Configuration
# ==============================================================================

variable "recovery_window_in_days" {
  description = "Number of days before secrets are permanently deleted (7-30)"
  type        = number
  default     = 30

  validation {
    condition     = var.recovery_window_in_days >= 7 && var.recovery_window_in_days <= 30
    error_message = "Recovery window must be between 7 and 30 days."
  }
}

variable "kms_key_id" {
  description = "KMS key ID for encrypting secrets"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for encrypting secrets"
  type        = string
}

# ==============================================================================
# Cross-Region Replication
# ==============================================================================

variable "enable_cross_region_replication" {
  description = "Enable cross-region replication for secrets"
  type        = bool
  default     = false
}

variable "replica_regions" {
  description = "List of regions to replicate secrets to"
  type        = list(string)
  default     = []
}

variable "replica_kms_key_ids" {
  description = "Map of region to KMS key ID for replica encryption"
  type        = map(string)
  default     = {}
}

# ==============================================================================
# Bedrock API Keys
# ==============================================================================

variable "bedrock_api_keys" {
  description = "Map of Bedrock API keys"
  type        = map(string)
  default     = {}
  sensitive   = true
}

# ==============================================================================
# Database Secrets
# ==============================================================================

variable "enable_database_secrets" {
  description = "Enable database credentials secret"
  type        = bool
  default     = false
}

variable "database_username" {
  description = "Database username"
  type        = string
  default     = ""
  sensitive   = true
}

variable "database_password" {
  description = "Database password"
  type        = string
  default     = ""
  sensitive   = true
}

variable "database_host" {
  description = "Database host"
  type        = string
  default     = ""
}

variable "database_port" {
  description = "Database port"
  type        = number
  default     = 5432
}

variable "database_name" {
  description = "Database name"
  type        = string
  default     = ""
}

# ==============================================================================
# Third-Party API Keys
# ==============================================================================

variable "third_party_api_keys" {
  description = "Map of third-party API keys"
  type        = map(string)
  default     = {}
  sensitive   = true
}

# ==============================================================================
# Secrets Rotation
# ==============================================================================

variable "enable_rotation" {
  description = "Enable automatic secrets rotation"
  type        = bool
  default     = true
}

variable "rotation_days" {
  description = "Number of days between automatic rotations"
  type        = number
  default     = 30

  validation {
    condition     = var.rotation_days >= 1 && var.rotation_days <= 365
    error_message = "Rotation days must be between 1 and 365."
  }
}

variable "rotation_lambda_zip_path" {
  description = "Path to Lambda function zip file for secrets rotation"
  type        = string
  default     = ""
}

variable "lambda_subnet_ids" {
  description = "List of subnet IDs for Lambda function (if VPC access needed)"
  type        = list(string)
  default     = []
}

variable "lambda_security_group_ids" {
  description = "List of security group IDs for Lambda function"
  type        = list(string)
  default     = []
}

# ==============================================================================
# IAM Configuration
# ==============================================================================

variable "iam_role_arns" {
  description = "List of IAM role ARNs that can access secrets"
  type        = list(string)
  default     = []
}

# ==============================================================================
# CloudWatch Configuration
# ==============================================================================

variable "sns_topic_arn" {
  description = "SNS topic ARN for secrets alarms and notifications"
  type        = string
}

variable "cloudtrail_log_group_name" {
  description = "CloudTrail log group name for metric filters"
  type        = string
  default     = ""
}

variable "enable_cloudtrail_metrics" {
  description = "Enable CloudWatch metric filters based on CloudTrail log group. Set to false to avoid circular dependencies when CloudTrail depends on this secrets module."
  type        = bool
  default     = true
}

variable "secrets_access_threshold" {
  description = "Threshold for secrets access alarm"
  type        = number
  default     = 100
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-2"
}
