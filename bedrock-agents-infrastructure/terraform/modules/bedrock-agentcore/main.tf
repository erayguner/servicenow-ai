# ==============================================================================
# Bedrock AgentCore Module
# ==============================================================================
# Purpose: Advanced Bedrock agent capabilities with gateway, memory, and code interpreter
# Based on patterns from: https://github.com/aws-ia/terraform-aws-agentcore
# Features:
#   - AgentCore Runtime (container/code-based)
#   - Gateway with MCP protocol support
#   - Memory with semantic/summary/user preference strategies
#   - Code Interpreter with sandbox/VPC modes
#   - Cognito authentication for JWT authorization
#   - Granular IAM permission outputs
# ==============================================================================

# Provider requirements are defined in versions.tf

# ==============================================================================
# Data Sources
# ==============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

# ==============================================================================
# Local Variables
# ==============================================================================

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.id
  partition  = data.aws_partition.current.partition

  # Resource naming
  name_prefix = "${var.project_name}-${var.environment}"

  # Unique suffix for resources
  resource_suffix = random_string.suffix.result

  # Sanitized names for AWSCC resources (underscore instead of hyphen)
  sanitized_runtime_name          = replace(var.runtime_name, "-", "_")
  sanitized_memory_name           = replace(var.memory_name, "-", "_")
  sanitized_code_interpreter_name = replace(var.code_interpreter_name, "-", "_")

  # Feature flags
  create_runtime          = var.create_runtime
  create_gateway          = var.create_gateway
  create_memory           = var.create_memory
  create_code_interpreter = var.create_code_interpreter
  create_cognito          = var.create_cognito && var.gateway_authorizer_type == "CUSTOM_JWT"

  # Common tags
  common_tags = merge(
    var.tags,
    {
      Module        = "bedrock-agentcore"
      ManagedBy     = "terraform"
      Project       = var.project_name
      Environment   = var.environment
      AgentCoreBase = "aws-ia/terraform-aws-agentcore"
    }
  )

  # IAM permission definitions for memory operations
  stm_write_perms = [
    "bedrock-agentcore:CreateEvent"
  ]

  stm_read_perms = [
    "bedrock-agentcore:GetEvent",
    "bedrock-agentcore:ListEvents",
    "bedrock-agentcore:ListEventsPaginated"
  ]

  stm_delete_perms = [
    "bedrock-agentcore:DeleteEvents",
    "bedrock-agentcore:DeleteSession"
  ]

  ltm_write_perms = [
    "bedrock-agentcore:CreateMemoryRecord"
  ]

  ltm_read_perms = [
    "bedrock-agentcore:GetMemoryRecord",
    "bedrock-agentcore:RetrieveMemoryRecords",
    "bedrock-agentcore:ListMemoryRecords"
  ]

  ltm_update_perms = [
    "bedrock-agentcore:UpdateMemoryRecord"
  ]

  ltm_delete_perms = [
    "bedrock-agentcore:DeleteMemoryRecord"
  ]

  # Merge all memory permissions
  all_memory_write_perms  = concat(local.stm_write_perms, local.ltm_write_perms)
  all_memory_read_perms   = concat(local.stm_read_perms, local.ltm_read_perms)
  all_memory_update_perms = local.ltm_update_perms
  all_memory_delete_perms = concat(local.stm_delete_perms, local.ltm_delete_perms)
}

# ==============================================================================
# Random Suffix for Unique Naming
# ==============================================================================

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# ==============================================================================
# IAM Role Propagation Wait
# ==============================================================================
# AWS IAM role propagation can take up to 20 seconds
# This ensures roles are available before creating dependent resources

resource "time_sleep" "iam_role_propagation" {
  count = (local.create_runtime && var.runtime_role_arn == null) || (local.create_gateway && var.gateway_role_arn == null) || (local.create_memory && var.memory_role_arn == null) || (local.create_code_interpreter && var.code_interpreter_role_arn == null) ? 1 : 0

  depends_on = [
    aws_iam_role.runtime_role,
    aws_iam_role.gateway_role,
    aws_iam_role.memory_role,
    aws_iam_role.code_interpreter_role,
    aws_iam_role_policy.runtime_role_policy,
    aws_iam_role_policy.gateway_role_policy,
    aws_iam_role_policy.memory_role_policy,
    aws_iam_role_policy.code_interpreter_role_policy
  ]

  create_duration = "20s"
}
