variable "action_group_name" {
  description = "Name of the action group"
  type        = string
}

variable "description" {
  description = "Description of the action group"
  type        = string
  default     = ""
}

variable "lambda_function_name" {
  description = "Name of the Lambda function to create"
  type        = string
}

variable "lambda_handler" {
  description = "Lambda function handler"
  type        = string
  default     = "index.handler"
}

variable "lambda_runtime" {
  description = "Lambda function runtime"
  type        = string
  default     = "python3.12"

  validation {
    condition     = contains(["python3.12", "python3.11", "nodejs20.x", "nodejs18.x"], var.lambda_runtime)
    error_message = "Lambda runtime must be a supported version."
  }
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30

  validation {
    condition     = var.lambda_timeout >= 3 && var.lambda_timeout <= 900
    error_message = "Lambda timeout must be between 3 and 900 seconds."
  }
}

variable "lambda_memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 256

  validation {
    condition     = var.lambda_memory_size >= 128 && var.lambda_memory_size <= 10240
    error_message = "Lambda memory size must be between 128 and 10240 MB."
  }
}

variable "lambda_source_code_path" {
  description = "Path to Lambda function source code (zip file or directory)"
  type        = string
  default     = null
}

variable "lambda_source_code_inline" {
  description = "Inline Lambda function source code"
  type        = string
  default     = null
}

variable "lambda_environment_variables" {
  description = "Environment variables for Lambda function"
  type        = map(string)
  default     = {}
}

variable "lambda_layers" {
  description = "List of Lambda layer ARNs"
  type        = list(string)
  default     = []
}

variable "api_schema" {
  description = "OpenAPI schema for the action group (JSON string or file path)"
  type        = string
}

variable "api_schema_is_file" {
  description = "Whether api_schema is a file path"
  type        = bool
  default     = false
}

variable "parent_action_group_signature" {
  description = "Parent action group signature (for built-in action groups)"
  type        = string
  default     = null

  validation {
    condition     = var.parent_action_group_signature == null || contains(["AMAZON.UserInput"], var.parent_action_group_signature)
    error_message = "Parent action group signature must be a valid built-in action group."
  }
}

variable "enable_lambda_vpc" {
  description = "Whether to enable VPC configuration for Lambda"
  type        = bool
  default     = false
}

variable "vpc_subnet_ids" {
  description = "List of VPC subnet IDs for Lambda"
  type        = list(string)
  default     = []
}

variable "vpc_security_group_ids" {
  description = "List of VPC security group IDs for Lambda"
  type        = list(string)
  default     = []
}

variable "enable_lambda_insights" {
  description = "Whether to enable CloudWatch Lambda Insights"
  type        = bool
  default     = true
}

variable "enable_xray_tracing" {
  description = "Whether to enable AWS X-Ray tracing for Lambda"
  type        = bool
  default     = true
}

variable "reserved_concurrent_executions" {
  description = "Reserved concurrent executions for Lambda function"
  type        = number
  default     = -1
}

variable "lambda_role_arn" {
  description = "ARN of existing IAM role for Lambda (if not provided, a new role will be created)"
  type        = string
  default     = null
}

variable "additional_lambda_policies" {
  description = "Additional IAM policy ARNs to attach to Lambda role"
  type        = list(string)
  default     = []
}

variable "kms_key_id" {
  description = "KMS key ID for Lambda environment variable encryption"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "create_lambda_function" {
  description = "Whether to create a Lambda function (false if using existing function)"
  type        = bool
  default     = true
}

variable "existing_lambda_arn" {
  description = "ARN of existing Lambda function (if create_lambda_function is false)"
  type        = string
  default     = null
}

variable "cloudwatch_logs_retention_days" {
  description = "CloudWatch Logs retention in days for Lambda function"
  type        = number
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.cloudwatch_logs_retention_days)
    error_message = "CloudWatch Logs retention must be a valid value."
  }
}
