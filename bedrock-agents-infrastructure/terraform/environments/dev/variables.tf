# Development Environment Variables

variable "aws_region" {
  description = "AWS region for Bedrock resources"
  type        = string
  default     = "eu-west-2"
}

variable "owner_email" {
  description = "Email of the resource owner"
  type        = string
}

variable "agent_instruction" {
  description = "Instructions for the Bedrock agent"
  type        = string
  default     = <<-EOT
    You are a ServiceNow AI assistant in development mode.
    Help developers test and debug ServiceNow integrations.
    Provide detailed responses for troubleshooting.
    This is a development environment - be verbose and educational.
  EOT
}

variable "alert_email" {
  description = "Email address for alerts (optional in dev)"
  type        = string
  default     = ""
}

# Optional dev-only toggles and metadata
variable "enable_cost_optimization" {
  description = "Enable cost optimization features in dev (reduces KMS rotation, shorter retention, lower Lambda memory)"
  type        = bool
  default     = false
}

variable "auto_shutdown_enabled" {
  description = "Toggle auto-shutdown behaviour for dev resources (sets AutoShutdown tag)"
  type        = bool
  default     = false
}

variable "enable_debug_mode" {
  description = "Enable verbose/debug behaviours in dev (enhanced monitoring, anomaly detection, longer retention)"
  type        = bool
  default     = false
}

# ==============================================================================
# Security Module Variables
# ==============================================================================

variable "kms_key_admin_arns" {
  description = "List of IAM role/user ARNs that can administer KMS keys"
  type        = list(string)
  default     = []
}

variable "lambda_function_names" {
  description = "List of Lambda function names to monitor"
  type        = list(string)
  default     = []
}

# ==============================================================================
# ServiceNow Module Variables
# ==============================================================================

variable "servicenow_instance_url" {
  description = "ServiceNow instance URL (e.g., https://your-instance.service-now.com/)"
  type        = string
  default     = ""

  validation {
    condition     = var.servicenow_instance_url == "" || can(regex("^https://.*\\.service-now\\.com/?$", var.servicenow_instance_url))
    error_message = "ServiceNow instance URL must be a valid HTTPS URL ending with .service-now.com"
  }
}

variable "servicenow_auth_type" {
  description = "Authentication type for ServiceNow API (oauth or basic)"
  type        = string
  default     = "oauth"

  validation {
    condition     = contains(["oauth", "basic"], var.servicenow_auth_type)
    error_message = "Authentication type must be either 'oauth' or 'basic'"
  }
}

variable "servicenow_credentials_secret_arn" {
  description = "ARN of existing Secrets Manager secret containing ServiceNow credentials"
  type        = string
  default     = null
}
