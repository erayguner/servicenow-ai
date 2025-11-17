variable "agent_name" {
  description = "Name of the Bedrock agent"
  type        = string
}

variable "description" {
  description = "Description of the Bedrock agent"
  type        = string
  default     = ""
}

variable "model_id" {
  description = "Model ID for the Bedrock agent (e.g., anthropic.claude-3-5-sonnet-20241022-v2:0, anthropic.claude-3-5-haiku-20241022-v1:0)"
  type        = string
  default     = "anthropic.claude-3-5-sonnet-20241022-v2:0"

  validation {
    condition     = can(regex("^anthropic\\.claude-", var.model_id))
    error_message = "Model ID must be a valid Anthropic Claude model."
  }
}

variable "instruction" {
  description = "Instructions for the Bedrock agent"
  type        = string
}

variable "foundation_model" {
  description = "Foundation model for the agent"
  type        = string
  default     = "anthropic.claude-3-5-sonnet-20241022-v2:0"
}

variable "idle_session_ttl_in_seconds" {
  description = "Idle session timeout in seconds"
  type        = number
  default     = 600
}

variable "agent_aliases" {
  description = "Map of agent aliases to create"
  type = map(object({
    description = string
    tags        = optional(map(string), {})
  }))
  default = {}
}

variable "knowledge_bases" {
  description = "List of knowledge base IDs to associate with the agent"
  type = list(object({
    knowledge_base_id = string
    description       = string
  }))
  default = []
}

variable "action_groups" {
  description = "List of action groups to associate with the agent"
  type = list(object({
    action_group_name = string
    description       = string
    lambda_arn        = string
    api_schema        = string
    enabled           = optional(bool, true)
  }))
  default = []
}

variable "enable_user_input" {
  description = "Whether to enable user input for the agent"
  type        = bool
  default     = true
}

variable "prompt_override_configuration" {
  description = "Prompt override configuration for the agent"
  type = object({
    prompt_type          = string
    prompt_creation_mode = string
    prompt_state         = string
    base_prompt_template = string
    inference_configuration = optional(object({
      temperature    = optional(number, 0.7)
      top_p          = optional(number, 0.9)
      top_k          = optional(number, 250)
      maximum_length = optional(number, 2048)
      stop_sequences = optional(list(string), [])
    }), null)
  })
  default = null
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "kms_key_id" {
  description = "KMS key ID for encryption (optional)"
  type        = string
  default     = null
}

variable "customer_encryption_key_arn" {
  description = "Customer managed KMS key ARN for agent encryption"
  type        = string
  default     = null
}

variable "prepare_agent" {
  description = "Whether to prepare the agent after creation"
  type        = bool
  default     = true
}

variable "guardrail_configuration" {
  description = "Guardrail configuration for the agent"
  type = object({
    guardrail_identifier = string
    guardrail_version    = string
  })
  default = null
}
