variable "project_name" {
  description = "Name of the project for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "enable_synthetics" {
  description = "Enable CloudWatch Synthetics canaries"
  type        = bool
  default     = true
}

variable "canaries" {
  description = "Map of canary configurations"
  type = map(object({
    endpoint_url        = string
    method              = optional(string, "GET")
    expected_status     = optional(number, 200)
    timeout_seconds     = optional(number, 60)
    schedule_expression = optional(string, "rate(5 minutes)")
    headers             = optional(map(string), {})
    body                = optional(string, null)
    runtime_version     = optional(string, "syn-nodejs-puppeteer-9.1")
    handler             = optional(string, "apiCanaryBlueprint.handler")
  }))
  default = {}
}

variable "bedrock_agent_endpoints" {
  description = "List of Bedrock agent API endpoints to monitor"
  type = list(object({
    name         = string
    endpoint_url = string
    headers      = optional(map(string), {})
  }))
  default = []
}

variable "s3_bucket_name" {
  description = "S3 bucket name for storing canary artifacts"
  type        = string
  default     = null
}

variable "create_s3_bucket" {
  description = "Create S3 bucket for canary artifacts"
  type        = bool
  default     = true
}

variable "s3_lifecycle_expiration_days" {
  description = "Number of days before canary artifacts expire"
  type        = number
  default     = 30
}

variable "alarm_sns_topic_arn" {
  description = "SNS topic ARN for canary alarms"
  type        = string
  default     = null
}

variable "failure_retention_period" {
  description = "Number of days to retain failed canary runs"
  type        = number
  default     = 31

  validation {
    condition     = var.failure_retention_period >= 1 && var.failure_retention_period <= 455
    error_message = "Failure retention period must be between 1 and 455 days"
  }
}

variable "success_retention_period" {
  description = "Number of days to retain successful canary runs"
  type        = number
  default     = 31

  validation {
    condition     = var.success_retention_period >= 1 && var.success_retention_period <= 455
    error_message = "Success retention period must be between 1 and 455 days"
  }
}

variable "vpc_config" {
  description = "VPC configuration for canaries"
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null
}

variable "enable_active_tracing" {
  description = "Enable X-Ray active tracing for canaries"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for encrypting canary artifacts"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
