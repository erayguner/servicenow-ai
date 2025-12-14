# ==============================================================================
# Bedrock AgentCore Module Variables
# ==============================================================================

# ==============================================================================
# General Configuration
# ==============================================================================

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 30
}

# ==============================================================================
# Runtime Configuration
# ==============================================================================

variable "create_runtime" {
  description = "Whether to create the AgentCore Runtime"
  type        = bool
  default     = false
}

variable "runtime_name" {
  description = "Name of the AgentCore Runtime"
  type        = string
  default     = "agentcore-runtime"
}

variable "runtime_description" {
  description = "Description of the AgentCore Runtime"
  type        = string
  default     = "AgentCore Runtime for Bedrock agents"
}

variable "runtime_role_arn" {
  description = "ARN of existing IAM role for runtime. If null, creates new role"
  type        = string
  default     = null
}

variable "runtime_artifact_type" {
  description = "Type of runtime artifact: container or code"
  type        = string
  default     = "container"

  validation {
    condition     = contains(["container", "code"], var.runtime_artifact_type)
    error_message = "Runtime artifact type must be one of: container, code."
  }
}

variable "runtime_container_uri" {
  description = "Container image URI for container-based runtime"
  type        = string
  default     = ""
}

variable "runtime_code_s3_bucket" {
  description = "S3 bucket name for code-based runtime"
  type        = string
  default     = ""
}

variable "runtime_code_s3_key" {
  description = "S3 object key for code-based runtime"
  type        = string
  default     = ""
}

variable "runtime_network_mode" {
  description = "Network mode for runtime: PUBLIC or VPC"
  type        = string
  default     = "PUBLIC"

  validation {
    condition     = contains(["PUBLIC", "VPC"], var.runtime_network_mode)
    error_message = "Runtime network mode must be one of: PUBLIC, VPC."
  }
}

variable "runtime_allowed_model_arns" {
  description = "List of Bedrock model ARNs allowed for runtime invocation"
  type        = list(string)
  default     = ["arn:aws:bedrock:*::foundation-model/anthropic.claude-*"]
}

variable "runtime_kms_key_arn" {
  description = "KMS key ARN for runtime encryption"
  type        = string
  default     = null
}

# ==============================================================================
# Gateway Configuration
# ==============================================================================

variable "create_gateway" {
  description = "Whether to create the AgentCore Gateway"
  type        = bool
  default     = false
}

variable "gateway_name" {
  description = "Name of the AgentCore Gateway"
  type        = string
  default     = "agentcore-gateway"
}

variable "gateway_description" {
  description = "Description of the AgentCore Gateway"
  type        = string
  default     = "AgentCore Gateway for MCP protocol"
}

variable "gateway_role_arn" {
  description = "ARN of existing IAM role for gateway. If null, creates new role"
  type        = string
  default     = null
}

variable "gateway_authorizer_type" {
  description = "Authorization type: CUSTOM_JWT or AWS_IAM"
  type        = string
  default     = "AWS_IAM"

  validation {
    condition     = contains(["CUSTOM_JWT", "AWS_IAM"], var.gateway_authorizer_type)
    error_message = "Gateway authorizer type must be one of: CUSTOM_JWT, AWS_IAM."
  }
}

variable "gateway_protocol_type" {
  description = "Protocol type for gateway: MCP"
  type        = string
  default     = "MCP"

  validation {
    condition     = contains(["MCP"], var.gateway_protocol_type)
    error_message = "Gateway protocol type must be: MCP."
  }
}

variable "gateway_kms_key_arn" {
  description = "KMS key ARN for gateway encryption"
  type        = string
  default     = null
}

variable "gateway_lambda_function_arns" {
  description = "List of Lambda function ARNs for gateway targets"
  type        = list(string)
  default     = []
}

variable "gateway_mcp_configuration" {
  description = "MCP protocol configuration for gateway"
  type = object({
    instructions       = optional(string, "")
    search_type        = optional(string, "SEMANTIC")
    supported_versions = optional(list(string), ["2024-11-05"])
  })
  default = {
    instructions       = ""
    search_type        = "SEMANTIC"
    supported_versions = ["2024-11-05"]
  }
}

# JWT Authentication (for CUSTOM_JWT)
variable "cognito_user_pool_discovery_url" {
  description = "Cognito User Pool discovery URL (if not creating new pool)"
  type        = string
  default     = ""
}

variable "jwt_allowed_audiences" {
  description = "Allowed JWT audiences (if using external Cognito)"
  type        = list(string)
  default     = []
}

variable "jwt_allowed_clients" {
  description = "Allowed JWT client IDs (if using external Cognito)"
  type        = list(string)
  default     = []
}

# ==============================================================================
# Memory Configuration
# ==============================================================================

variable "create_memory" {
  description = "Whether to create the AgentCore Memory"
  type        = bool
  default     = false
}

variable "memory_name" {
  description = "Name of the AgentCore Memory"
  type        = string
  default     = "agentcore-memory"
}

variable "memory_description" {
  description = "Description of the AgentCore Memory"
  type        = string
  default     = "AgentCore Memory for agent context"
}

variable "memory_role_arn" {
  description = "ARN of existing IAM role for memory. If null, creates new role"
  type        = string
  default     = null
}

variable "memory_event_expiry_duration" {
  description = "Event expiry duration in days"
  type        = number
  default     = 90
}

variable "memory_kms_key_arn" {
  description = "KMS key ARN for memory encryption"
  type        = string
  default     = null
}

variable "memory_allowed_model_arns" {
  description = "List of Bedrock model ARNs allowed for memory strategies"
  type        = list(string)
  default     = ["arn:aws:bedrock:*::foundation-model/anthropic.claude-*"]
}

variable "memory_strategies" {
  description = "List of memory strategies to configure"
  type = list(object({
    semantic_memory_strategy = optional(object({
      name        = string
      description = optional(string, "")
      namespaces  = optional(list(string), [])
      model_id    = optional(string)
    }))
    summary_memory_strategy = optional(object({
      name        = string
      description = optional(string, "")
      namespaces  = optional(list(string), [])
      model_id    = optional(string)
    }))
    user_preference_memory_strategy = optional(object({
      name        = string
      description = optional(string, "")
      namespaces  = optional(list(string), [])
      model_id    = optional(string)
    }))
    custom_memory_strategy = optional(object({
      name          = string
      description   = optional(string, "")
      namespaces    = optional(list(string), [])
      configuration = optional(any)
    }))
  }))
  default = []
}

# ==============================================================================
# Code Interpreter Configuration
# ==============================================================================

variable "create_code_interpreter" {
  description = "Whether to create the AgentCore Code Interpreter"
  type        = bool
  default     = false
}

variable "code_interpreter_name" {
  description = "Name of the AgentCore Code Interpreter"
  type        = string
  default     = "agentcore-code-interpreter"
}

variable "code_interpreter_description" {
  description = "Description of the AgentCore Code Interpreter"
  type        = string
  default     = "AgentCore Code Interpreter for code execution"
}

variable "code_interpreter_role_arn" {
  description = "ARN of existing IAM role for code interpreter. If null, creates new role"
  type        = string
  default     = null
}

variable "code_interpreter_network_mode" {
  description = "Network mode for code interpreter: SANDBOX or VPC"
  type        = string
  default     = "SANDBOX"

  validation {
    condition     = contains(["SANDBOX", "VPC"], var.code_interpreter_network_mode)
    error_message = "Code interpreter network mode must be one of: SANDBOX, VPC."
  }
}

variable "code_interpreter_security_group_ids" {
  description = "Security group IDs for VPC mode code interpreter"
  type        = list(string)
  default     = []
}

variable "code_interpreter_subnet_ids" {
  description = "Subnet IDs for VPC mode code interpreter"
  type        = list(string)
  default     = []
}

variable "code_interpreter_kms_key_arn" {
  description = "KMS key ARN for code interpreter encryption"
  type        = string
  default     = null
}

variable "code_interpreter_s3_bucket_arns" {
  description = "S3 bucket ARNs for code interpreter artifacts"
  type        = list(string)
  default     = []
}

# ==============================================================================
# Cognito Configuration
# ==============================================================================

variable "create_cognito" {
  description = "Whether to create Cognito User Pool for JWT authentication"
  type        = bool
  default     = false
}

variable "cognito_password_minimum_length" {
  description = "Minimum password length for Cognito"
  type        = number
  default     = 12
}

variable "cognito_temporary_password_validity_days" {
  description = "Temporary password validity in days"
  type        = number
  default     = 7
}

variable "cognito_mfa_configuration" {
  description = "MFA configuration: OFF, ON, or OPTIONAL"
  type        = string
  default     = "OPTIONAL"

  validation {
    condition     = contains(["OFF", "ON", "OPTIONAL"], var.cognito_mfa_configuration)
    error_message = "Cognito MFA configuration must be one of: OFF, ON, OPTIONAL."
  }
}

variable "cognito_allow_admin_create_user_only" {
  description = "Whether only admins can create users"
  type        = bool
  default     = true
}

variable "cognito_advanced_security_mode" {
  description = "Advanced security mode: OFF, AUDIT, or ENFORCED"
  type        = string
  default     = "AUDIT"

  validation {
    condition     = contains(["OFF", "AUDIT", "ENFORCED"], var.cognito_advanced_security_mode)
    error_message = "Cognito advanced security mode must be one of: OFF, AUDIT, ENFORCED."
  }
}

variable "cognito_deletion_protection" {
  description = "Enable deletion protection for Cognito User Pool"
  type        = bool
  default     = true
}

variable "cognito_access_token_validity" {
  description = "Access token validity in hours"
  type        = number
  default     = 1
}

variable "cognito_id_token_validity" {
  description = "ID token validity in hours"
  type        = number
  default     = 1
}

variable "cognito_refresh_token_validity" {
  description = "Refresh token validity in days"
  type        = number
  default     = 30
}

variable "cognito_callback_urls" {
  description = "Callback URLs for Cognito OAuth"
  type        = list(string)
  default     = ["https://localhost:3000/callback"]
}

variable "cognito_logout_urls" {
  description = "Logout URLs for Cognito OAuth"
  type        = list(string)
  default     = ["https://localhost:3000/logout"]
}

variable "cognito_generate_client_secret" {
  description = "Whether to generate client secret for Cognito client"
  type        = bool
  default     = true
}

variable "cognito_domain_prefix" {
  description = "Domain prefix for Cognito hosted UI"
  type        = string
  default     = ""
}
