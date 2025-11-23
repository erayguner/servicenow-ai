# ==============================================================================
# Bedrock Security WAF Module - Variables
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
# WAF Configuration
# ==============================================================================

variable "waf_scope" {
  description = "Scope of the WAF (REGIONAL for API Gateway, CLOUDFRONT for CloudFront)"
  type        = string
  default     = "REGIONAL"

  validation {
    condition     = can(regex("^(REGIONAL|CLOUDFRONT)$", var.waf_scope))
    error_message = "WAF scope must be REGIONAL or CLOUDFRONT."
  }
}

variable "rate_limit" {
  description = "Maximum number of requests per 5 minutes from a single IP"
  type        = number
  default     = 2000

  validation {
    condition     = var.rate_limit >= 100 && var.rate_limit <= 20000000
    error_message = "Rate limit must be between 100 and 20,000,000."
  }
}

variable "enable_core_rule_exceptions" {
  description = "Enable exceptions for AWS Core Rule Set"
  type        = bool
  default     = false
}

variable "enable_anonymous_ip_list" {
  description = "Enable blocking of anonymous IP addresses (VPN, Tor, etc.)"
  type        = bool
  default     = true
}

# ==============================================================================
# Geo-blocking Configuration
# ==============================================================================

variable "blocked_countries" {
  description = "List of country codes to block (ISO 3166-1 alpha-2)"
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.blocked_countries : length(c) == 2])
    error_message = "Country codes must be 2-character ISO 3166-1 alpha-2 codes."
  }
}

# ==============================================================================
# IP Filtering Configuration
# ==============================================================================

variable "allowed_ip_addresses" {
  description = "List of allowed IP addresses in CIDR notation"
  type        = list(string)
  default     = []
}

variable "blocked_ip_addresses" {
  description = "List of blocked IP addresses in CIDR notation"
  type        = list(string)
  default     = []
}

# ==============================================================================
# API Key Validation
# ==============================================================================

variable "require_api_key_header" {
  description = "Require specific API key header for requests"
  type        = bool
  default     = false
}

variable "api_key_header_name" {
  description = "Name of the API key header"
  type        = string
  default     = "x-api-key"
}

variable "api_key_header_value" {
  description = "Expected value of the API key header"
  type        = string
  default     = ""
  sensitive   = true
}

# ==============================================================================
# API Gateway Association
# ==============================================================================

variable "api_gateway_arn" {
  description = "ARN of the API Gateway to associate with WAF"
  type        = string
  default     = ""
}

# ==============================================================================
# Logging Configuration
# ==============================================================================

variable "enable_waf_logging" {
  description = "Enable WAF logging to CloudWatch"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Number of days to retain WAF logs"
  type        = number
  default     = 90
}

variable "kms_key_arn" {
  description = "KMS key ARN for encrypting CloudWatch logs"
  type        = string
  default     = ""
}

# ==============================================================================
# CloudWatch Alarms Configuration
# ==============================================================================

variable "sns_topic_arn" {
  description = "SNS topic ARN for WAF alarms"
  type        = string
}

variable "blocked_requests_threshold" {
  description = "Threshold for blocked requests alarm"
  type        = number
  default     = 1000
}

variable "rate_limit_alarm_threshold" {
  description = "Threshold for rate limit exceeded alarm"
  type        = number
  default     = 500
}
