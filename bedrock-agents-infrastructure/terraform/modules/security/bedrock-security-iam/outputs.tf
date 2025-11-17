# ==============================================================================
# Bedrock Security IAM Module - Outputs
# ==============================================================================

# ==============================================================================
# Bedrock Agent Execution Role
# ==============================================================================

output "bedrock_agent_execution_role_arn" {
  description = "ARN of the Bedrock agent execution role"
  value       = aws_iam_role.bedrock_agent_execution.arn
}

output "bedrock_agent_execution_role_name" {
  description = "Name of the Bedrock agent execution role"
  value       = aws_iam_role.bedrock_agent_execution.name
}

output "bedrock_agent_execution_role_id" {
  description = "ID of the Bedrock agent execution role"
  value       = aws_iam_role.bedrock_agent_execution.id
}

# ==============================================================================
# Lambda Execution Role
# ==============================================================================

output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role for Bedrock action groups"
  value       = aws_iam_role.lambda_execution.arn
}

output "lambda_execution_role_name" {
  description = "Name of the Lambda execution role"
  value       = aws_iam_role.lambda_execution.name
}

output "lambda_execution_role_id" {
  description = "ID of the Lambda execution role"
  value       = aws_iam_role.lambda_execution.id
}

# ==============================================================================
# Step Functions Execution Role
# ==============================================================================

output "step_functions_execution_role_arn" {
  description = "ARN of the Step Functions execution role"
  value       = var.enable_step_functions ? aws_iam_role.step_functions_execution[0].arn : null
}

output "step_functions_execution_role_name" {
  description = "Name of the Step Functions execution role"
  value       = var.enable_step_functions ? aws_iam_role.step_functions_execution[0].name : null
}

# ==============================================================================
# Cross-Account Access Role
# ==============================================================================

output "cross_account_access_role_arn" {
  description = "ARN of the cross-account access role"
  value       = var.enable_cross_account_access ? aws_iam_role.cross_account_access[0].arn : null
}

output "cross_account_access_role_name" {
  description = "Name of the cross-account access role"
  value       = var.enable_cross_account_access ? aws_iam_role.cross_account_access[0].name : null
}

# ==============================================================================
# Permission Boundary
# ==============================================================================

output "permission_boundary_arn" {
  description = "ARN of the permission boundary policy"
  value       = var.enable_permission_boundary ? aws_iam_policy.permission_boundary[0].arn : null
}

output "permission_boundary_name" {
  description = "Name of the permission boundary policy"
  value       = var.enable_permission_boundary ? aws_iam_policy.permission_boundary[0].name : null
}

# ==============================================================================
# CloudWatch Alarms
# ==============================================================================

output "unauthorized_api_calls_alarm_arn" {
  description = "ARN of the unauthorized API calls CloudWatch alarm"
  value       = aws_cloudwatch_metric_alarm.unauthorized_api_calls.arn
}

output "iam_policy_changes_alarm_arn" {
  description = "ARN of the IAM policy changes CloudWatch alarm"
  value       = aws_cloudwatch_metric_alarm.iam_policy_changes.arn
}

# ==============================================================================
# Metric Filters
# ==============================================================================

output "unauthorized_api_calls_metric_filter_name" {
  description = "Name of the unauthorized API calls metric filter"
  value       = aws_cloudwatch_log_metric_filter.unauthorized_api_calls.name
}

output "iam_policy_changes_metric_filter_name" {
  description = "Name of the IAM policy changes metric filter"
  value       = aws_cloudwatch_log_metric_filter.iam_policy_changes.name
}

# ==============================================================================
# Module Information
# ==============================================================================

output "module_version" {
  description = "Version of the bedrock-security-iam module"
  value       = "1.0.0"
}

output "abac_enabled" {
  description = "Whether ABAC is enabled"
  value       = var.enable_abac
}

output "permission_boundary_enabled" {
  description = "Whether permission boundary is enabled"
  value       = var.enable_permission_boundary
}

output "all_role_arns" {
  description = "Map of all IAM role ARNs created by this module"
  value = {
    bedrock_agent_execution = aws_iam_role.bedrock_agent_execution.arn
    lambda_execution        = aws_iam_role.lambda_execution.arn
    step_functions_execution = var.enable_step_functions ? aws_iam_role.step_functions_execution[0].arn : null
    cross_account_access    = var.enable_cross_account_access ? aws_iam_role.cross_account_access[0].arn : null
  }
}
