# ==============================================================================
# Bedrock Security Secrets Module - Outputs
# ==============================================================================

# ==============================================================================
# Secrets
# ==============================================================================

output "bedrock_api_keys_secret_arn" {
  description = "ARN of the Bedrock API keys secret"
  value       = aws_secretsmanager_secret.bedrock_api_keys.arn
}

output "bedrock_api_keys_secret_id" {
  description = "ID of the Bedrock API keys secret"
  value       = aws_secretsmanager_secret.bedrock_api_keys.id
}

output "bedrock_api_keys_secret_name" {
  description = "Name of the Bedrock API keys secret"
  value       = aws_secretsmanager_secret.bedrock_api_keys.name
}

output "database_credentials_secret_arn" {
  description = "ARN of the database credentials secret"
  value       = var.enable_database_secrets ? aws_secretsmanager_secret.database_credentials[0].arn : null
}

output "database_credentials_secret_id" {
  description = "ID of the database credentials secret"
  value       = var.enable_database_secrets ? aws_secretsmanager_secret.database_credentials[0].id : null
}

output "database_credentials_secret_name" {
  description = "Name of the database credentials secret"
  value       = var.enable_database_secrets ? aws_secretsmanager_secret.database_credentials[0].name : null
}

output "third_party_keys_secret_arn" {
  description = "ARN of the third-party API keys secret"
  value       = length(var.third_party_api_keys) > 0 ? aws_secretsmanager_secret.third_party_keys[0].arn : null
}

output "third_party_keys_secret_id" {
  description = "ID of the third-party API keys secret"
  value       = length(var.third_party_api_keys) > 0 ? aws_secretsmanager_secret.third_party_keys[0].id : null
}

output "third_party_keys_secret_name" {
  description = "Name of the third-party API keys secret"
  value       = length(var.third_party_api_keys) > 0 ? aws_secretsmanager_secret.third_party_keys[0].name : null
}

# ==============================================================================
# All Secrets
# ==============================================================================

output "all_secret_arns" {
  description = "Map of all secret ARNs"
  value = {
    bedrock_api_keys     = aws_secretsmanager_secret.bedrock_api_keys.arn
    database_credentials = var.enable_database_secrets ? aws_secretsmanager_secret.database_credentials[0].arn : null
    third_party_keys     = length(var.third_party_api_keys) > 0 ? aws_secretsmanager_secret.third_party_keys[0].arn : null
  }
}

output "all_secret_names" {
  description = "Map of all secret names"
  value = {
    bedrock_api_keys     = aws_secretsmanager_secret.bedrock_api_keys.name
    database_credentials = var.enable_database_secrets ? aws_secretsmanager_secret.database_credentials[0].name : null
    third_party_keys     = length(var.third_party_api_keys) > 0 ? aws_secretsmanager_secret.third_party_keys[0].name : null
  }
}

# ==============================================================================
# Rotation Lambda
# ==============================================================================

output "rotation_lambda_function_arn" {
  description = "ARN of the secrets rotation Lambda function"
  value       = var.enable_rotation ? aws_lambda_function.secrets_rotation[0].arn : null
}

output "rotation_lambda_function_name" {
  description = "Name of the secrets rotation Lambda function"
  value       = var.enable_rotation ? aws_lambda_function.secrets_rotation[0].function_name : null
}

output "rotation_lambda_role_arn" {
  description = "ARN of the secrets rotation Lambda IAM role"
  value       = var.enable_rotation ? aws_iam_role.secrets_rotation[0].arn : null
}

# ==============================================================================
# CloudWatch Alarms
# ==============================================================================

output "secrets_access_alarm_arn" {
  description = "ARN of the secrets access CloudWatch alarm"
  value       = aws_cloudwatch_metric_alarm.secrets_access_high.arn
}

output "rotation_failures_alarm_arn" {
  description = "ARN of the rotation failures CloudWatch alarm"
  value       = aws_cloudwatch_metric_alarm.rotation_failures.arn
}

# ==============================================================================
# EventBridge Rules
# ==============================================================================

output "rotation_success_rule_arn" {
  description = "ARN of the rotation success EventBridge rule"
  value       = aws_cloudwatch_event_rule.rotation_success.arn
}

output "rotation_failed_rule_arn" {
  description = "ARN of the rotation failed EventBridge rule"
  value       = aws_cloudwatch_event_rule.rotation_failed.arn
}

# ==============================================================================
# Configuration Details
# ==============================================================================

output "rotation_enabled" {
  description = "Whether automatic rotation is enabled"
  value       = var.enable_rotation
}

output "rotation_days" {
  description = "Number of days between rotations"
  value       = var.rotation_days
}

output "cross_region_replication_enabled" {
  description = "Whether cross-region replication is enabled"
  value       = var.enable_cross_region_replication
}

output "replica_regions" {
  description = "List of replica regions"
  value       = var.replica_regions
}

output "recovery_window_days" {
  description = "Number of days in the recovery window"
  value       = var.recovery_window_in_days
}

# ==============================================================================
# Rotation Status
# ==============================================================================

output "bedrock_api_keys_rotation_enabled" {
  description = "Whether rotation is enabled for Bedrock API keys"
  value       = var.enable_rotation
}

output "database_credentials_rotation_enabled" {
  description = "Whether rotation is enabled for database credentials"
  value       = var.enable_rotation && var.enable_database_secrets
}

# ==============================================================================
# Module Information
# ==============================================================================

output "module_version" {
  description = "Version of the bedrock-security-secrets module"
  value       = "1.0.0"
}

output "secrets_count" {
  description = "Total number of secrets created"
  value = (
    1 + # bedrock_api_keys
    (var.enable_database_secrets ? 1 : 0) +
    (length(var.third_party_api_keys) > 0 ? 1 : 0)
  )
}
