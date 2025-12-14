# ==============================================================================
# Bedrock AgentCore Module Outputs
# ==============================================================================

# ==============================================================================
# Runtime Outputs
# ==============================================================================

output "runtime_id" {
  description = "ID of the AgentCore Runtime"
  value       = local.create_runtime ? (var.runtime_artifact_type == "container" ? awscc_bedrockagentcore_runtime.container[0].agent_runtime_id : awscc_bedrockagentcore_runtime.code[0].agent_runtime_id) : null
}

output "runtime_arn" {
  description = "ARN of the AgentCore Runtime"
  value       = local.create_runtime ? (var.runtime_artifact_type == "container" ? awscc_bedrockagentcore_runtime.container[0].agent_runtime_arn : awscc_bedrockagentcore_runtime.code[0].agent_runtime_arn) : null
}

output "runtime_role_arn" {
  description = "ARN of the Runtime IAM role"
  value       = local.create_runtime && var.runtime_role_arn == null ? aws_iam_role.runtime_role[0].arn : var.runtime_role_arn
}

output "runtime_log_group_name" {
  description = "CloudWatch Log Group name for runtime"
  value       = local.create_runtime ? aws_cloudwatch_log_group.runtime[0].name : null
}

# ==============================================================================
# Gateway Outputs
# ==============================================================================

output "gateway_id" {
  description = "ID of the AgentCore Gateway"
  value       = local.create_gateway ? awscc_bedrockagentcore_gateway.this[0].gateway_identifier : null
}

output "gateway_arn" {
  description = "ARN of the AgentCore Gateway"
  value       = local.create_gateway ? awscc_bedrockagentcore_gateway.this[0].gateway_arn : null
}

output "gateway_url" {
  description = "URL of the AgentCore Gateway"
  value       = local.create_gateway ? awscc_bedrockagentcore_gateway.this[0].gateway_url : null
}

output "gateway_endpoint" {
  description = "Endpoint URL of the AgentCore Gateway (alias for gateway_url)"
  value       = local.create_gateway ? awscc_bedrockagentcore_gateway.this[0].gateway_url : null
}

output "gateway_role_arn" {
  description = "ARN of the Gateway IAM role"
  value       = local.create_gateway && var.gateway_role_arn == null ? aws_iam_role.gateway_role[0].arn : var.gateway_role_arn
}

output "gateway_log_group_name" {
  description = "CloudWatch Log Group name for gateway"
  value       = local.create_gateway ? aws_cloudwatch_log_group.gateway[0].name : null
}

# Gateway targets are not yet supported by the AWSCC provider (v1.66.0)
# output "gateway_target_arns" {
#   description = "ARNs of Gateway targets"
#   value = merge(
#     { for k, v in awscc_bedrockagentcore_gateway_target.lambda : k => v.gateway_target_arn },
#     { for k, v in awscc_bedrockagentcore_gateway_target.mcp_server : k => v.gateway_target_arn }
#   )
# }

# ==============================================================================
# Memory Outputs
# ==============================================================================

output "memory_id" {
  description = "ID of the AgentCore Memory"
  value       = local.create_memory ? awscc_bedrockagentcore_memory.this[0].memory_id : null
}

output "memory_arn" {
  description = "ARN of the AgentCore Memory"
  value       = local.create_memory ? awscc_bedrockagentcore_memory.this[0].memory_arn : null
}

output "memory_role_arn" {
  description = "ARN of the Memory IAM role"
  value       = local.create_memory && var.memory_role_arn == null ? aws_iam_role.memory_role[0].arn : var.memory_role_arn
}

output "memory_log_group_name" {
  description = "CloudWatch Log Group name for memory"
  value       = local.create_memory ? aws_cloudwatch_log_group.memory[0].name : null
}

# ==============================================================================
# Code Interpreter Outputs
# ==============================================================================

output "code_interpreter_id" {
  description = "ID of the AgentCore Code Interpreter"
  value       = local.create_code_interpreter ? awscc_bedrockagentcore_code_interpreter_custom.this[0].code_interpreter_id : null
}

output "code_interpreter_arn" {
  description = "ARN of the AgentCore Code Interpreter"
  value       = local.create_code_interpreter ? awscc_bedrockagentcore_code_interpreter_custom.this[0].code_interpreter_arn : null
}

output "code_interpreter_role_arn" {
  description = "ARN of the Code Interpreter IAM role"
  value       = local.create_code_interpreter && var.code_interpreter_role_arn == null ? aws_iam_role.code_interpreter_role[0].arn : var.code_interpreter_role_arn
}

output "code_interpreter_log_group_name" {
  description = "CloudWatch Log Group name for code interpreter"
  value       = local.create_code_interpreter ? aws_cloudwatch_log_group.code_interpreter[0].name : null
}

# ==============================================================================
# Cognito Outputs
# ==============================================================================

output "cognito_user_pool_id" {
  description = "ID of the Cognito User Pool"
  value       = local.create_cognito ? aws_cognito_user_pool.gateway[0].id : null
}

output "cognito_user_pool_arn" {
  description = "ARN of the Cognito User Pool"
  value       = local.create_cognito ? aws_cognito_user_pool.gateway[0].arn : null
}

output "cognito_user_pool_endpoint" {
  description = "Endpoint of the Cognito User Pool"
  value       = local.create_cognito ? aws_cognito_user_pool.gateway[0].endpoint : null
}

output "cognito_user_pool_client_id" {
  description = "ID of the Cognito User Pool Client"
  value       = local.create_cognito ? aws_cognito_user_pool_client.gateway[0].id : null
}

output "cognito_user_pool_client_secret" {
  description = "Secret of the Cognito User Pool Client"
  value       = local.create_cognito ? aws_cognito_user_pool_client.gateway[0].client_secret : null
  sensitive   = true
}

output "cognito_domain" {
  description = "Domain of the Cognito User Pool"
  value       = local.create_cognito && var.cognito_domain_prefix != "" ? aws_cognito_user_pool_domain.gateway[0].domain : null
}

output "cognito_discovery_url" {
  description = "OIDC Discovery URL for Cognito"
  value       = local.create_cognito ? "https://cognito-idp.${local.region}.amazonaws.com/${aws_cognito_user_pool.gateway[0].id}" : null
}

# ==============================================================================
# IAM Permission Policy Documents
# ==============================================================================
# These outputs provide ready-to-use IAM policy documents for external consumers

output "memory_stm_read_policy_json" {
  description = "IAM policy document JSON for Short-Term Memory read access"
  value       = local.create_memory ? data.aws_iam_policy_document.memory_stm_read[0].json : null
}

output "memory_stm_write_policy_json" {
  description = "IAM policy document JSON for Short-Term Memory write access"
  value       = local.create_memory ? data.aws_iam_policy_document.memory_stm_write[0].json : null
}

output "memory_ltm_read_policy_json" {
  description = "IAM policy document JSON for Long-Term Memory read access"
  value       = local.create_memory ? data.aws_iam_policy_document.memory_ltm_read[0].json : null
}

output "memory_ltm_write_policy_json" {
  description = "IAM policy document JSON for Long-Term Memory write access"
  value       = local.create_memory ? data.aws_iam_policy_document.memory_ltm_write[0].json : null
}

output "memory_full_access_policy_json" {
  description = "IAM policy document JSON for full Memory access"
  value       = local.create_memory ? data.aws_iam_policy_document.memory_full_access[0].json : null
}

output "code_interpreter_invoke_policy_json" {
  description = "IAM policy document JSON for Code Interpreter invoke access"
  value       = local.create_code_interpreter ? data.aws_iam_policy_document.code_interpreter_invoke[0].json : null
}

# ==============================================================================
# Resource Suffix
# ==============================================================================

output "resource_suffix" {
  description = "Random suffix used for resource naming"
  value       = local.resource_suffix
}
