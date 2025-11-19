# ==============================================================================
# Bedrock Security Hub Module - Variables
# ==============================================================================

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = can(regex("^(dev|staging|prod)$", var.environment))
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}

# ==============================================================================
# Security Hub Configuration
# ==============================================================================

variable "enable_default_standards" {
  description = "Enable default security standards"
  type        = bool
  default     = true
}

variable "control_finding_generator" {
  description = "Control finding generator (SECURITY_CONTROL or STANDARD_CONTROL)"
  type        = string
  default     = "SECURITY_CONTROL"

  validation {
    condition     = can(regex("^(SECURITY_CONTROL|STANDARD_CONTROL)$", var.control_finding_generator))
    error_message = "Control finding generator must be SECURITY_CONTROL or STANDARD_CONTROL."
  }
}

variable "auto_enable_controls" {
  description = "Automatically enable new controls"
  type        = bool
  default     = true
}

# ==============================================================================
# Security Standards
# ==============================================================================

variable "enable_aws_foundational_standard" {
  description = "Enable AWS Foundational Security Best Practices standard"
  type        = bool
  default     = true
}

variable "enable_cis_aws_foundations" {
  description = "Enable CIS AWS Foundations Benchmark"
  type        = bool
  default     = true
}

variable "enable_pci_dss" {
  description = "Enable PCI-DSS standard"
  type        = bool
  default     = false
}

variable "enable_nist" {
  description = "Enable NIST 800-53 standard"
  type        = bool
  default     = false
}

# ==============================================================================
# Product Integrations
# ==============================================================================

variable "enable_guardduty_integration" {
  description = "Enable GuardDuty integration"
  type        = bool
  default     = true
}

variable "enable_config_integration" {
  description = "Enable AWS Config integration"
  type        = bool
  default     = true
}

variable "enable_inspector_integration" {
  description = "Enable AWS Inspector integration"
  type        = bool
  default     = true
}

variable "enable_access_analyzer_integration" {
  description = "Enable IAM Access Analyzer integration"
  type        = bool
  default     = true
}

# ==============================================================================
# Automated Remediation
# ==============================================================================

variable "enable_auto_remediation" {
  description = "Enable automated remediation for findings"
  type        = bool
  default     = false
}

variable "auto_remediation_zip_path" {
  description = "Path to Lambda function zip file for auto-remediation"
  type        = string
  default     = ""
}

variable "remediation_dry_run" {
  description = "Run remediation in dry-run mode (no actual changes)"
  type        = bool
  default     = true
}

# ==============================================================================
# SNS Configuration
# ==============================================================================

variable "sns_topic_arn" {
  description = "SNS topic ARN for Security Hub notifications"
  type        = string
}

variable "high_severity_sns_topic_arn" {
  description = "SNS topic ARN for high severity findings (uses default if empty)"
  type        = string
  default     = ""
}

# ==============================================================================
# CloudWatch Configuration
# ==============================================================================

variable "failed_compliance_threshold" {
  description = "Threshold for failed compliance checks alarm"
  type        = number
  default     = 5
}

variable "alarm_evaluation_periods" {
  description = "Number of periods to evaluate for alarms"
  type        = number
  default     = 1
}

variable "alarm_period" {
  description = "Period in seconds for alarm evaluation"
  type        = number
  default     = 300
}
