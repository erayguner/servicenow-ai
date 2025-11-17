# Staging Environment Variables

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
    You are a ServiceNow AI assistant in staging environment.
    This environment mirrors production for testing and validation.
    Provide production-quality responses while allowing for testing scenarios.
    Support comprehensive testing of all ServiceNow integrations.
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
  description = "Email address for alerts"
  type        = string
}

# State backend variables
variable "state_bucket_name" {
  description = "S3 bucket name for Terraform state"
  type        = string
  default     = "servicenow-ai-terraform-state-staging"
}

variable "state_lock_table_name" {
  description = "DynamoDB table name for state locking"
  type        = string
  default     = "servicenow-ai-terraform-locks-staging"
}

# Testing variables
variable "enable_load_testing" {
  description = "Enable load testing capabilities"
  type        = bool
  default     = true
}

variable "enable_chaos_testing" {
  description = "Enable chaos engineering testing"
  type        = bool
  default     = true
}

variable "enable_ab_testing" {
  description = "Enable A/B testing for agent responses"
  type        = bool
  default     = true
}

# Performance testing
variable "load_test_config" {
  description = "Load testing configuration"
  type = object({
    target_rps           = number
    duration_minutes     = number
    ramp_up_minutes      = number
    concurrent_sessions  = number
  })
  default = {
    target_rps          = 50
    duration_minutes    = 30
    ramp_up_minutes     = 5
    concurrent_sessions = 100
  }
}

# Staging-specific variables
variable "test_scenarios" {
  description = "List of test scenarios to execute"
  type        = list(string)
  default     = [
    "functional-testing",
    "integration-testing",
    "performance-testing",
    "security-testing",
    "regression-testing"
  ]
}

variable "qa_team_members" {
  description = "List of QA team member emails for access"
  type        = list(string)
  default     = []
}

variable "enable_synthetic_monitoring" {
  description = "Enable synthetic monitoring for proactive testing"
  type        = bool
  default     = true
}

variable "sync_with_prod" {
  description = "Enable data synchronization with production"
  type        = bool
  default     = false
}

variable "approval_required" {
  description = "Require approval for infrastructure changes"
  type        = bool
  default     = true
}

# Compliance variables
variable "enable_audit_logging" {
  description = "Enable comprehensive audit logging"
  type        = bool
  default     = true
}

variable "compliance_framework" {
  description = "Compliance framework to adhere to"
  type        = string
  default     = "sox"

  validation {
    condition     = contains(["sox", "pci", "hipaa", "none"], var.compliance_framework)
    error_message = "Compliance framework must be one of: sox, pci, hipaa, none"
  }
}
