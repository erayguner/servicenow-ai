# Development Environment Variables

variable "aws_region" {
  description = "AWS region for Bedrock resources"
  type        = string
  default     = "us-east-1"
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

# Note: Knowledge bases and action groups are not currently configured
# in this environment. Add these variables back when implementing:
# - data_source_bucket_arn: For S3 bucket containing knowledge base data
# - action_lambda_arn: For Lambda function ARN for agent actions

variable "alert_email" {
  description = "Email address for alerts (optional in dev)"
  type        = string
  default     = ""
}

# Optional dev-only toggles and metadata
variable "enable_cost_optimization" {
  description = "Enable cost optimization features in dev"
  type        = bool
  default     = false
}

variable "auto_shutdown_enabled" {
  description = "Toggle auto-shutdown behaviour for dev resources"
  type        = bool
  default     = false
}

variable "enable_debug_mode" {
  description = "Enable verbose/debug behaviours in dev"
  type        = bool
  default     = false
}

variable "test_data_enabled" {
  description = "Whether to load or use test data in dev"
  type        = bool
  default     = false
}

variable "dev_team_members" {
  description = "List of dev team member emails for tagging or notifications"
  type = list(string)
  default = []
}

variable "data_source_bucket_arn" {
  description = "Optional S3 bucket ARN for knowledge base or data sources"
  type        = string
  default     = null
}

variable "action_lambda_arn" {
  description = "Optional Lambda ARN for action groups"
  type        = string
  default     = null
}

variable "state_bucket_name" {
  description = "S3 bucket name for Terraform state (informational)"
  type        = string
  default     = null
}

variable "bedrock_agent_endpoints" {
  description = "List of Bedrock agent endpoint URLs for synthetic monitoring"
  type = list(string)
  default = []
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
    condition = var.servicenow_instance_url == "" || can(regex("^https://.*\\.service-now\\.com/?$", var.servicenow_instance_url))
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
