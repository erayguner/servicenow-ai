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

variable "data_source_bucket_arn" {
  description = "ARN of S3 bucket containing knowledge base data"
  type        = string
}

variable "action_lambda_arn" {
  description = "ARN of Lambda function for agent actions"
  type        = string
}

variable "alert_email" {
  description = "Email address for alerts (optional in dev)"
  type        = string
  default     = ""
}

# State backend variables
variable "state_bucket_name" {
  description = "S3 bucket name for Terraform state"
  type        = string
  default     = "servicenow-ai-terraform-state-dev"
}

variable "state_lock_table_name" {
  description = "DynamoDB table name for state locking"
  type        = string
  default     = "servicenow-ai-terraform-locks-dev"
}

# Cost optimization variables
variable "enable_cost_optimization" {
  description = "Enable aggressive cost optimization for dev"
  type        = bool
  default     = true
}

variable "auto_shutdown_enabled" {
  description = "Enable automatic shutdown of resources outside business hours"
  type        = bool
  default     = true
}

# Development-specific variables
variable "dev_team_members" {
  description = "List of development team member emails for access"
  type        = list(string)
  default     = []
}

variable "enable_debug_mode" {
  description = "Enable verbose logging and debugging features"
  type        = bool
  default     = true
}

variable "test_data_enabled" {
  description = "Enable test data generation and seeding"
  type        = bool
  default     = true
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
# Monitoring Module Variables
# ==============================================================================

variable "bedrock_agent_endpoints" {
  description = "List of Bedrock agent endpoints for synthetic monitoring"
  type        = list(string)
  default     = []
}

# ==============================================================================
# ServiceNow Module Variables
# ==============================================================================

variable "servicenow_instance_url" {
  description = "ServiceNow instance URL (e.g., https://your-instance.service-now.com)"
  type        = string
  default     = ""

  validation {
    condition     = var.servicenow_instance_url == "" || can(regex("^https://.*\\.service-now\\.com$", var.servicenow_instance_url))
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
