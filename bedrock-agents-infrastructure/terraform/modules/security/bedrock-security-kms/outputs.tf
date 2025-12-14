# ==============================================================================
# Bedrock Security KMS Module - Outputs
# ==============================================================================

# ==============================================================================
# Bedrock Data KMS Key
# ==============================================================================

output "bedrock_data_key_id" {
  description = "ID of the Bedrock data KMS key"
  value       = aws_kms_key.bedrock_data.id
}

output "bedrock_data_key_arn" {
  description = "ARN of the Bedrock data KMS key"
  value       = aws_kms_key.bedrock_data.arn
}

output "bedrock_data_key_alias" {
  description = "Alias of the Bedrock data KMS key"
  value       = aws_kms_alias.bedrock_data.name
}

output "bedrock_data_key_alias_arn" {
  description = "ARN of the Bedrock data KMS key alias"
  value       = aws_kms_alias.bedrock_data.arn
}

# ==============================================================================
# Secrets KMS Key
# ==============================================================================

output "secrets_key_id" {
  description = "ID of the Secrets Manager KMS key"
  value       = aws_kms_key.secrets.id
}

output "secrets_key_arn" {
  description = "ARN of the Secrets Manager KMS key"
  value       = aws_kms_key.secrets.arn
}

output "secrets_key_alias" {
  description = "Alias of the Secrets Manager KMS key"
  value       = aws_kms_alias.secrets.name
}

output "secrets_key_alias_arn" {
  description = "ARN of the Secrets Manager KMS key alias"
  value       = aws_kms_alias.secrets.arn
}

# ==============================================================================
# S3 KMS Key
# ==============================================================================

output "s3_key_id" {
  description = "ID of the S3 KMS key"
  value       = aws_kms_key.s3.id
}

output "s3_key_arn" {
  description = "ARN of the S3 KMS key"
  value       = aws_kms_key.s3.arn
}

output "s3_key_alias" {
  description = "Alias of the S3 KMS key"
  value       = aws_kms_alias.s3.name
}

output "s3_key_alias_arn" {
  description = "ARN of the S3 KMS key alias"
  value       = aws_kms_alias.s3.arn
}

# ==============================================================================
# All Keys
# ==============================================================================

output "all_key_ids" {
  description = "Map of all KMS key IDs"
  value = {
    bedrock_data = aws_kms_key.bedrock_data.id
    secrets      = aws_kms_key.secrets.id
    s3           = aws_kms_key.s3.id
  }
}

output "all_key_arns" {
  description = "Map of all KMS key ARNs"
  value = {
    bedrock_data = aws_kms_key.bedrock_data.arn
    secrets      = aws_kms_key.secrets.arn
    s3           = aws_kms_key.s3.arn
  }
}

output "all_key_aliases" {
  description = "Map of all KMS key aliases"
  value = {
    bedrock_data = aws_kms_alias.bedrock_data.name
    secrets      = aws_kms_alias.secrets.name
    s3           = aws_kms_alias.s3.name
  }
}

# ==============================================================================
# CloudWatch Alarms
# ==============================================================================

output "kms_key_disabled_alarm_arns" {
  description = "Map of KMS key disabled alarm ARNs"
  value = {
    for k, v in aws_cloudwatch_metric_alarm.kms_key_disabled : k => v.arn
  }
}

output "kms_api_errors_alarm_arns" {
  description = "Map of KMS API errors alarm ARNs"
  value = {
    for k, v in aws_cloudwatch_metric_alarm.kms_api_errors : k => v.arn
  }
}

output "kms_key_deletion_alarm_arn" {
  description = "ARN of the KMS key deletion alarm"
  value       = var.enable_cloudtrail_metrics && var.cloudtrail_log_group_name != "" ? aws_cloudwatch_metric_alarm.kms_key_deletion[0].arn : null
}

# ==============================================================================
# Key Properties
# ==============================================================================

output "key_rotation_enabled" {
  description = "Whether automatic key rotation is enabled"
  value       = var.enable_key_rotation
}

output "multi_region_enabled" {
  description = "Whether multi-region keys are enabled"
  value       = var.enable_multi_region
}

output "deletion_window_days" {
  description = "Number of days in the deletion window"
  value       = var.deletion_window_in_days
}

# ==============================================================================
# Module Information
# ==============================================================================

output "module_version" {
  description = "Version of the bedrock-security-kms module"
  value       = "1.0.0"
}
