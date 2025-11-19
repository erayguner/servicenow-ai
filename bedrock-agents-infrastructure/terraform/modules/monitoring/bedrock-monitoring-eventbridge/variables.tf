variable "project_name" {
  description = "Name of the project for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "enable_eventbridge" {
  description = "Enable EventBridge monitoring"
  type        = bool
  default     = true
}

variable "event_bus_name" {
  description = "Name of the EventBridge event bus (use 'default' for default bus)"
  type        = string
  default     = "default"
}

variable "create_custom_event_bus" {
  description = "Create a custom event bus instead of using default"
  type        = bool
  default     = false
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for event notifications"
  type        = string
  default     = null
}

variable "sqs_queue_arn" {
  description = "SQS queue ARN for event notifications"
  type        = string
  default     = null
}

variable "lambda_function_arns" {
  description = "Map of Lambda function ARNs to trigger on events"
  type        = map(string)
  default     = {}
}

variable "enable_bedrock_state_change_events" {
  description = "Enable Bedrock agent state change events"
  type        = bool
  default     = true
}

variable "enable_bedrock_error_events" {
  description = "Enable Bedrock error events"
  type        = bool
  default     = true
}

variable "enable_lambda_error_events" {
  description = "Enable Lambda error events"
  type        = bool
  default     = true
}

variable "enable_step_functions_events" {
  description = "Enable Step Functions state change events"
  type        = bool
  default     = true
}

variable "enable_api_gateway_events" {
  description = "Enable API Gateway events"
  type        = bool
  default     = false
}

variable "enable_cloudtrail_insights_events" {
  description = "Enable CloudTrail Insights events"
  type        = bool
  default     = true
}

variable "enable_config_compliance_events" {
  description = "Enable AWS Config compliance change events"
  type        = bool
  default     = true
}

variable "enable_health_events" {
  description = "Enable AWS Health events"
  type        = bool
  default     = true
}

variable "custom_event_patterns" {
  description = "Map of custom event patterns"
  type = map(object({
    description   = string
    event_pattern = string
    target_arn    = string
  }))
  default = {}
}

variable "enable_event_archiving" {
  description = "Enable event archiving"
  type        = bool
  default     = true
}

variable "archive_retention_days" {
  description = "Number of days to retain archived events (0 = indefinite)"
  type        = number
  default     = 90
}

variable "enable_dlq" {
  description = "Enable dead-letter queue for failed events"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for encrypting event data"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
