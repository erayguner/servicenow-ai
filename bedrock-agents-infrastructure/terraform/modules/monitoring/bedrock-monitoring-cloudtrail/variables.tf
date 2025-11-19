variable "project_name" {
  description = "Name of the project for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "trail_name" {
  description = "Name of the CloudTrail trail"
  type        = string
  default     = null
}

variable "enable_trail" {
  description = "Enable CloudTrail"
  type        = bool
  default     = true
}

variable "is_multi_region_trail" {
  description = "Whether the trail is multi-region"
  type        = bool
  default     = true
}

variable "include_global_service_events" {
  description = "Include global service events (IAM, etc.)"
  type        = bool
  default     = true
}

variable "enable_log_file_validation" {
  description = "Enable log file validation for integrity"
  type        = bool
  default     = true
}

variable "s3_bucket_name" {
  description = "S3 bucket name for CloudTrail logs"
  type        = string
  default     = null
}

variable "create_s3_bucket" {
  description = "Create S3 bucket for CloudTrail"
  type        = bool
  default     = true
}

variable "s3_key_prefix" {
  description = "S3 key prefix for CloudTrail logs"
  type        = string
  default     = "cloudtrail"
}

variable "cloudwatch_logs_group_name" {
  description = "CloudWatch Logs group name for CloudTrail"
  type        = string
  default     = null
}

variable "create_cloudwatch_logs_group" {
  description = "Create CloudWatch Logs group for CloudTrail"
  type        = bool
  default     = true
}

variable "cloudwatch_logs_retention_days" {
  description = "Retention period for CloudWatch Logs"
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.cloudwatch_logs_retention_days)
    error_message = "Retention must be a valid CloudWatch Logs retention period."
  }
}

variable "enable_insights" {
  description = "Enable CloudTrail Insights"
  type        = bool
  default     = true
}

variable "insight_selector_type" {
  description = "Type of Insights to enable (ApiCallRateInsight or ApiErrorRateInsight)"
  type        = list(string)
  default     = ["ApiCallRateInsight", "ApiErrorRateInsight"]

  validation {
    condition = alltrue([
      for t in var.insight_selector_type : contains(["ApiCallRateInsight", "ApiErrorRateInsight"], t)
    ])
    error_message = "Insight selector type must be ApiCallRateInsight or ApiErrorRateInsight"
  }
}

variable "event_selectors" {
  description = "Event selectors for the trail"
  type = list(object({
    read_write_type           = string
    include_management_events = bool
    data_resources = list(object({
      type   = string
      values = list(string)
    }))
  }))
  default = [
    {
      read_write_type           = "All"
      include_management_events = true
      data_resources            = []
    }
  ]
}

variable "advanced_event_selectors" {
  description = "Advanced event selectors for fine-grained control"
  type = list(object({
    name = string
    field_selectors = list(object({
      field           = string
      equals          = optional(list(string))
      not_equals      = optional(list(string))
      starts_with     = optional(list(string))
      not_starts_with = optional(list(string))
    }))
  }))
  default = []
}

variable "use_advanced_event_selectors" {
  description = "Use advanced event selectors instead of basic event selectors"
  type        = bool
  default     = false
}

variable "kms_key_id" {
  description = "KMS key ID for encrypting CloudTrail logs"
  type        = string
  default     = null
}

variable "sns_topic_name" {
  description = "SNS topic name for CloudTrail notifications"
  type        = string
  default     = null
}

variable "enable_s3_data_events" {
  description = "Enable S3 data events logging"
  type        = bool
  default     = true
}

variable "enable_lambda_data_events" {
  description = "Enable Lambda data events logging"
  type        = bool
  default     = true
}

variable "s3_lifecycle_expiration_days" {
  description = "Number of days before CloudTrail logs expire in S3"
  type        = number
  default     = 90
}

variable "s3_lifecycle_transition_days" {
  description = "Number of days before CloudTrail logs transition to cheaper storage"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
