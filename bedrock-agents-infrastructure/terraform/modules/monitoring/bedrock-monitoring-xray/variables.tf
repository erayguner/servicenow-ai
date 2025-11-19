variable "project_name" {
  description = "Name of the project for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "enable_xray_tracing" {
  description = "Enable X-Ray tracing"
  type        = bool
  default     = true
}

variable "enable_insights" {
  description = "Enable X-Ray Insights"
  type        = bool
  default     = true
}

variable "insights_notifications_enabled" {
  description = "Enable notifications for X-Ray Insights"
  type        = bool
  default     = true
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for X-Ray Insights notifications"
  type        = string
  default     = null
}

variable "sampling_rule_priority" {
  description = "Priority of the sampling rule (lower number = higher priority)"
  type        = number
  default     = 1000
}

variable "sampling_fixed_rate" {
  description = "Fixed rate of requests to sample (0.0 to 1.0)"
  type        = number
  default     = 0.05

  validation {
    condition     = var.sampling_fixed_rate >= 0 && var.sampling_fixed_rate <= 1
    error_message = "Sampling fixed rate must be between 0.0 and 1.0"
  }
}

variable "sampling_reservoir_size" {
  description = "Number of requests to sample per second before applying fixed rate"
  type        = number
  default     = 1
}

variable "bedrock_sampling_rate" {
  description = "Sampling rate specifically for Bedrock agent invocations"
  type        = number
  default     = 0.1

  validation {
    condition     = var.bedrock_sampling_rate >= 0 && var.bedrock_sampling_rate <= 1
    error_message = "Bedrock sampling rate must be between 0.0 and 1.0"
  }
}

variable "lambda_sampling_rate" {
  description = "Sampling rate for Lambda functions"
  type        = number
  default     = 0.05

  validation {
    condition     = var.lambda_sampling_rate >= 0 && var.lambda_sampling_rate <= 1
    error_message = "Lambda sampling rate must be between 0.0 and 1.0"
  }
}

variable "api_gateway_sampling_rate" {
  description = "Sampling rate for API Gateway requests"
  type        = number
  default     = 0.1

  validation {
    condition     = var.api_gateway_sampling_rate >= 0 && var.api_gateway_sampling_rate <= 1
    error_message = "API Gateway sampling rate must be between 0.0 and 1.0"
  }
}

variable "create_groups" {
  description = "Whether to create X-Ray groups"
  type        = bool
  default     = true
}

variable "group_definitions" {
  description = "Map of X-Ray group definitions"
  type = map(object({
    filter_expression = string
  }))
  default = {}
}

variable "kms_key_id" {
  description = "KMS key ID for encrypting X-Ray data"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
