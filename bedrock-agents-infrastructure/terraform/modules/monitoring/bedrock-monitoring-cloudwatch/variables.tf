variable "project_name" {
  description = "Name of the project for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "bedrock_agent_id" {
  description = "Bedrock agent ID to monitor"
  type        = string
  default     = null
}

variable "bedrock_agent_alias_id" {
  description = "Bedrock agent alias ID to monitor"
  type        = string
  default     = null
}

variable "lambda_function_names" {
  description = "List of Lambda function names to monitor"
  type        = list(string)
  default     = []
}

variable "step_function_state_machine_arns" {
  description = "List of Step Functions state machine ARNs to monitor"
  type        = list(string)
  default     = []
}

variable "api_gateway_ids" {
  description = "List of API Gateway REST API IDs to monitor"
  type        = list(string)
  default     = []
}

variable "alarm_sns_topic_arn" {
  description = "SNS topic ARN for alarm notifications"
  type        = string
  default     = null
}

variable "create_sns_topic" {
  description = "Whether to create an SNS topic for alarms"
  type        = bool
  default     = true
}

variable "sns_email_subscriptions" {
  description = "List of email addresses to subscribe to alarm notifications"
  type        = list(string)
  default     = []
}

variable "enable_anomaly_detection" {
  description = "Enable CloudWatch anomaly detection"
  type        = bool
  default     = true
}

variable "enable_composite_alarms" {
  description = "Enable composite alarms for complex monitoring scenarios"
  type        = bool
  default     = true
}

variable "create_dashboard" {
  description = "Whether to create CloudWatch dashboard"
  type        = bool
  default     = true
}

variable "dashboard_name" {
  description = "Name for the CloudWatch dashboard"
  type        = string
  default     = null
}

# Lambda monitoring thresholds
variable "lambda_error_rate_threshold" {
  description = "Lambda error rate threshold (percentage)"
  type        = number
  default     = 5
}

variable "lambda_duration_threshold" {
  description = "Lambda duration threshold in milliseconds"
  type        = number
  default     = 10000
}

variable "lambda_throttles_threshold" {
  description = "Lambda throttles threshold"
  type        = number
  default     = 5
}

variable "lambda_concurrent_executions_threshold" {
  description = "Lambda concurrent executions threshold"
  type        = number
  default     = 80
}

# Bedrock agent thresholds
variable "bedrock_invocation_latency_threshold" {
  description = "Bedrock agent invocation latency threshold in milliseconds"
  type        = number
  default     = 30000
}

variable "bedrock_error_rate_threshold" {
  description = "Bedrock agent error rate threshold (percentage)"
  type        = number
  default     = 5
}

variable "bedrock_throttle_threshold" {
  description = "Bedrock agent throttle count threshold"
  type        = number
  default     = 10
}

# Step Functions thresholds
variable "step_functions_failed_executions_threshold" {
  description = "Step Functions failed executions threshold"
  type        = number
  default     = 5
}

variable "step_functions_timed_out_executions_threshold" {
  description = "Step Functions timed out executions threshold"
  type        = number
  default     = 3
}

# API Gateway thresholds
variable "api_gateway_5xx_error_threshold" {
  description = "API Gateway 5XX error threshold (percentage)"
  type        = number
  default     = 5
}

variable "api_gateway_latency_threshold" {
  description = "API Gateway latency threshold in milliseconds"
  type        = number
  default     = 5000
}

variable "evaluation_periods" {
  description = "Number of periods to evaluate for alarms"
  type        = number
  default     = 2
}

variable "alarm_actions_enabled" {
  description = "Enable alarm actions"
  type        = bool
  default     = true
}

variable "log_group_names" {
  description = "List of CloudWatch Log Group names to create metric filters for"
  type        = list(string)
  default     = []
}

variable "metric_namespace" {
  description = "Custom CloudWatch metric namespace"
  type        = string
  default     = "BedrockAgents/Custom"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "kms_key_id" {
  description = "KMS key ID for encrypting CloudWatch Logs"
  type        = string
  default     = null
}
