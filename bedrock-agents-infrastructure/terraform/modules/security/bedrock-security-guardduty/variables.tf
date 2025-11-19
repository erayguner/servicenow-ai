# ==============================================================================
# Bedrock Security GuardDuty Module - Variables
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
  default     = {}
}

# ==============================================================================
# GuardDuty Configuration
# ==============================================================================

variable "finding_publishing_frequency" {
  description = "Frequency of publishing findings to CloudWatch (FIFTEEN_MINUTES, ONE_HOUR, SIX_HOURS)"
  type        = string
  default     = "FIFTEEN_MINUTES"

  validation {
    condition     = can(regex("^(FIFTEEN_MINUTES|ONE_HOUR|SIX_HOURS)$", var.finding_publishing_frequency))
    error_message = "Finding publishing frequency must be FIFTEEN_MINUTES, ONE_HOUR, or SIX_HOURS."
  }
}

variable "enable_s3_protection" {
  description = "Enable S3 protection in GuardDuty"
  type        = bool
  default     = true
}

variable "enable_eks_protection" {
  description = "Enable EKS/Kubernetes audit logs protection"
  type        = bool
  default     = true
}

variable "enable_lambda_protection" {
  description = "Enable Lambda network logs protection"
  type        = bool
  default     = true
}

variable "enable_rds_protection" {
  description = "Enable RDS login events protection"
  type        = bool
  default     = true
}

variable "enable_malware_protection" {
  description = "Enable malware protection for EBS volumes"
  type        = bool
  default     = true
}

variable "enable_organization_configuration" {
  description = "Enable organization-wide GuardDuty configuration"
  type        = bool
  default     = false
}

# ==============================================================================
# Threat Detection Configuration
# ==============================================================================

variable "enable_crypto_mining_detection" {
  description = "Enable cryptocurrency mining detection"
  type        = bool
  default     = true
}

variable "custom_threat_intel_set_location" {
  description = "S3 location of custom threat intelligence set"
  type        = string
  default     = ""
}

variable "trusted_ip_set_location" {
  description = "S3 location of trusted IP set"
  type        = string
  default     = ""
}

# ==============================================================================
# Findings Processor Configuration
# ==============================================================================

variable "enable_findings_processor" {
  description = "Enable Lambda function for processing GuardDuty findings"
  type        = bool
  default     = false
}

variable "findings_processor_zip_path" {
  description = "Path to Lambda function zip file for findings processor"
  type        = string
  default     = ""
}

# ==============================================================================
# SNS Configuration
# ==============================================================================

variable "sns_topic_arn" {
  description = "SNS topic ARN for GuardDuty notifications"
  type        = string
}

variable "high_severity_sns_topic_arn" {
  description = "SNS topic ARN for high severity findings (uses default if empty)"
  type        = string
  default     = ""
}

# ==============================================================================
# CloudWatch Configuration
# ==============================================================================

variable "log_retention_days" {
  description = "Number of days to retain GuardDuty logs"
  type        = number
  default     = 90
}

variable "kms_key_arn" {
  description = "KMS key ARN for encrypting CloudWatch logs"
  type        = string
  default     = ""
}

variable "findings_count_threshold" {
  description = "Threshold for GuardDuty findings count alarm"
  type        = number
  default     = 10
}

# ==============================================================================
# Alarm Configuration
# ==============================================================================

variable "alarm_evaluation_periods" {
  description = "Number of periods to evaluate for alarms"
  type        = number
  default     = 1
}

variable "alarm_period" {
  description = "Period in seconds for alarm evaluation"
  type        = number
  default     = 300
}
