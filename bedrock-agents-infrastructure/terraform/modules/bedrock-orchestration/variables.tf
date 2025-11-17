variable "orchestration_name" {
  description = "Name of the orchestration workflow"
  type        = string
}

variable "description" {
  description = "Description of the orchestration workflow"
  type        = string
  default     = ""
}

variable "agent_arns" {
  description = "List of Bedrock agent ARNs to orchestrate"
  type        = list(string)
  default     = []
}

variable "agent_aliases" {
  description = "Map of agent ARNs to their alias IDs"
  type        = map(string)
  default     = {}
}

variable "state_machine_type" {
  description = "Type of Step Functions state machine (STANDARD or EXPRESS)"
  type        = string
  default     = "STANDARD"

  validation {
    condition     = contains(["STANDARD", "EXPRESS"], var.state_machine_type)
    error_message = "State machine type must be either STANDARD or EXPRESS."
  }
}

variable "state_machine_definition" {
  description = "Step Functions state machine definition (JSON string or template)"
  type        = string
  default     = null
}

variable "use_default_definition" {
  description = "Whether to use the default sequential agent orchestration definition"
  type        = bool
  default     = true
}

variable "enable_logging" {
  description = "Whether to enable CloudWatch Logs for Step Functions"
  type        = bool
  default     = true
}

variable "log_level" {
  description = "Log level for Step Functions (ALL, ERROR, FATAL, OFF)"
  type        = string
  default     = "ERROR"

  validation {
    condition     = contains(["ALL", "ERROR", "FATAL", "OFF"], var.log_level)
    error_message = "Log level must be one of: ALL, ERROR, FATAL, OFF."
  }
}

variable "enable_xray_tracing" {
  description = "Whether to enable AWS X-Ray tracing"
  type        = bool
  default     = true
}

variable "create_dynamodb_table" {
  description = "Whether to create a DynamoDB table for state management"
  type        = bool
  default     = true
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state management"
  type        = string
  default     = null
}

variable "dynamodb_billing_mode" {
  description = "DynamoDB billing mode (PROVISIONED or PAY_PER_REQUEST)"
  type        = string
  default     = "PAY_PER_REQUEST"

  validation {
    condition     = contains(["PROVISIONED", "PAY_PER_REQUEST"], var.dynamodb_billing_mode)
    error_message = "DynamoDB billing mode must be either PROVISIONED or PAY_PER_REQUEST."
  }
}

variable "dynamodb_read_capacity" {
  description = "DynamoDB read capacity units (only for PROVISIONED billing mode)"
  type        = number
  default     = 5
}

variable "dynamodb_write_capacity" {
  description = "DynamoDB write capacity units (only for PROVISIONED billing mode)"
  type        = number
  default     = 5
}

variable "enable_point_in_time_recovery" {
  description = "Whether to enable point-in-time recovery for DynamoDB"
  type        = bool
  default     = true
}

variable "enable_eventbridge_trigger" {
  description = "Whether to create EventBridge rule to trigger the state machine"
  type        = bool
  default     = false
}

variable "eventbridge_schedule_expression" {
  description = "EventBridge schedule expression (e.g., 'rate(5 minutes)', 'cron(0 12 * * ? *)')"
  type        = string
  default     = null
}

variable "eventbridge_event_pattern" {
  description = "EventBridge event pattern (JSON string)"
  type        = string
  default     = null
}

variable "eventbridge_input_transformer" {
  description = "EventBridge input transformer configuration"
  type = object({
    input_paths_map = map(string)
    input_template  = string
  })
  default = null
}

variable "enable_sns_notifications" {
  description = "Whether to create SNS topic for orchestration notifications"
  type        = bool
  default     = false
}

variable "sns_topic_name" {
  description = "Name of the SNS topic for notifications"
  type        = string
  default     = null
}

variable "sns_email_subscriptions" {
  description = "List of email addresses to subscribe to SNS notifications"
  type        = list(string)
  default     = []
}

variable "timeout_seconds" {
  description = "Timeout for the state machine execution in seconds"
  type        = number
  default     = 300

  validation {
    condition     = var.timeout_seconds > 0 && var.timeout_seconds <= 31536000
    error_message = "Timeout must be between 1 and 31536000 seconds (1 year)."
  }
}

variable "max_concurrency" {
  description = "Maximum number of concurrent executions (for EXPRESS state machines)"
  type        = number
  default     = null
}

variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "orchestration_pattern" {
  description = "Orchestration pattern (sequential, parallel, choice, map)"
  type        = string
  default     = "sequential"

  validation {
    condition     = contains(["sequential", "parallel", "choice", "map"], var.orchestration_pattern)
    error_message = "Orchestration pattern must be one of: sequential, parallel, choice, map."
  }
}

variable "error_handling_strategy" {
  description = "Error handling strategy (retry, catch, fail)"
  type        = string
  default     = "retry"

  validation {
    condition     = contains(["retry", "catch", "fail"], var.error_handling_strategy)
    error_message = "Error handling strategy must be one of: retry, catch, fail."
  }
}

variable "max_retry_attempts" {
  description = "Maximum number of retry attempts for failed tasks"
  type        = number
  default     = 3

  validation {
    condition     = var.max_retry_attempts >= 0 && var.max_retry_attempts <= 10
    error_message = "Max retry attempts must be between 0 and 10."
  }
}
