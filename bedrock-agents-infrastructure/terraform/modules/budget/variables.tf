# ==============================================================================
# Budget Module Variables
# ==============================================================================

# ------------------------------------------------------------------------------
# Required Variables
# ------------------------------------------------------------------------------

variable "project_name" {
  description = "Name of the project for resource naming"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,62}$", var.project_name))
    error_message = "Project name must start with a letter, contain only lowercase letters, numbers, and hyphens, and be at most 63 characters."
  }
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod", "test"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod, test."
  }
}

# ------------------------------------------------------------------------------
# Budget Amount Configuration
# ------------------------------------------------------------------------------

variable "budget_amount" {
  description = "Monthly budget limit in USD"
  type        = number
  default     = 20.0

  validation {
    condition     = var.budget_amount > 0
    error_message = "Budget amount must be greater than 0."
  }
}

variable "bedrock_budget_amount" {
  description = "Monthly budget limit for Bedrock services in USD"
  type        = number
  default     = 15.0

  validation {
    condition     = var.bedrock_budget_amount > 0
    error_message = "Bedrock budget amount must be greater than 0."
  }
}

variable "lambda_budget_amount" {
  description = "Monthly budget limit for Lambda services in USD"
  type        = number
  default     = 5.0

  validation {
    condition     = var.lambda_budget_amount > 0
    error_message = "Lambda budget amount must be greater than 0."
  }
}

variable "dynamodb_budget_amount" {
  description = "Monthly budget limit for DynamoDB services in USD"
  type        = number
  default     = 5.0

  validation {
    condition     = var.dynamodb_budget_amount > 0
    error_message = "DynamoDB budget amount must be greater than 0."
  }
}

variable "daily_budget_amount" {
  description = "Daily budget limit in USD (for anomaly detection)"
  type        = number
  default     = 2.0

  validation {
    condition     = var.daily_budget_amount > 0
    error_message = "Daily budget amount must be greater than 0."
  }
}

# ------------------------------------------------------------------------------
# Notification Configuration
# ------------------------------------------------------------------------------

variable "email_addresses" {
  description = "List of email addresses to receive budget notifications"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for email in var.email_addresses :
      can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", email))
    ])
    error_message = "All email addresses must be valid email format."
  }
}

variable "sns_topic_arns" {
  description = "List of SNS topic ARNs to receive budget notifications"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for arn in var.sns_topic_arns :
      can(regex("^arn:aws:sns:[a-z0-9-]+:[0-9]{12}:.+$", arn))
    ])
    error_message = "All SNS topic ARNs must be valid ARN format."
  }
}

# ------------------------------------------------------------------------------
# Alert Thresholds Configuration
# ------------------------------------------------------------------------------

variable "enable_50_percent_alert" {
  description = "Enable notification at 50% of budget"
  type        = bool
  default     = true
}

variable "enable_80_percent_alert" {
  description = "Enable notification at 80% of budget"
  type        = bool
  default     = true
}

variable "enable_forecast_alert" {
  description = "Enable notification when forecasted to exceed budget"
  type        = bool
  default     = true
}

# ------------------------------------------------------------------------------
# Optional Budget Creation
# ------------------------------------------------------------------------------

variable "create_bedrock_budget" {
  description = "Create a separate budget for Bedrock services"
  type        = bool
  default     = true
}

variable "create_lambda_budget" {
  description = "Create a separate budget for Lambda services"
  type        = bool
  default     = false
}

variable "create_dynamodb_budget" {
  description = "Create a separate budget for DynamoDB services"
  type        = bool
  default     = false
}

variable "create_daily_budget" {
  description = "Create a daily budget for cost anomaly detection"
  type        = bool
  default     = false
}

# ------------------------------------------------------------------------------
# Filtering Configuration
# ------------------------------------------------------------------------------

variable "filter_services" {
  description = "List of AWS services to filter the budget by"
  type        = list(string)
  default     = null
}

variable "filter_tags" {
  description = "Map of tags to filter the budget by"
  type        = map(string)
  default     = null
}

# ------------------------------------------------------------------------------
# Tags
# ------------------------------------------------------------------------------

variable "tags" {
  description = "Additional tags to apply to budget resources"
  type        = map(string)
  default     = {}
}
