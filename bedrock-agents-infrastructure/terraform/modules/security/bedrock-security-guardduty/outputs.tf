# ==============================================================================
# Bedrock Security GuardDuty Module - Outputs
# ==============================================================================

# ==============================================================================
# GuardDuty Detector
# ==============================================================================

output "detector_id" {
  description = "ID of the GuardDuty detector"
  value       = aws_guardduty_detector.main.id
}

output "detector_arn" {
  description = "ARN of the GuardDuty detector"
  value       = aws_guardduty_detector.main.arn
}

output "detector_account_id" {
  description = "Account ID of the GuardDuty detector"
  value       = aws_guardduty_detector.main.account_id
}

# ==============================================================================
# Protection Features
# ==============================================================================

output "s3_protection_enabled" {
  description = "Whether S3 protection is enabled"
  value       = var.enable_s3_protection
}

output "eks_protection_enabled" {
  description = "Whether EKS protection is enabled"
  value       = var.enable_eks_protection
}

output "lambda_protection_enabled" {
  description = "Whether Lambda protection is enabled"
  value       = var.enable_lambda_protection
}

output "rds_protection_enabled" {
  description = "Whether RDS protection is enabled"
  value       = var.enable_rds_protection
}

output "malware_protection_enabled" {
  description = "Whether malware protection is enabled"
  value       = var.enable_malware_protection
}

# ==============================================================================
# EventBridge Rules
# ==============================================================================

output "guardduty_findings_rule_arn" {
  description = "ARN of the GuardDuty findings EventBridge rule"
  value       = aws_cloudwatch_event_rule.guardduty_findings.arn
}

output "high_severity_findings_rule_arn" {
  description = "ARN of the high severity findings EventBridge rule"
  value       = aws_cloudwatch_event_rule.high_severity_findings.arn
}

output "crypto_mining_rule_arn" {
  description = "ARN of the crypto mining detection EventBridge rule"
  value       = var.enable_crypto_mining_detection ? aws_cloudwatch_event_rule.crypto_mining[0].arn : null
}

# ==============================================================================
# CloudWatch Alarms
# ==============================================================================

output "findings_count_alarm_arn" {
  description = "ARN of the findings count CloudWatch alarm"
  value       = aws_cloudwatch_metric_alarm.guardduty_findings_count.arn
}

output "high_severity_alarm_arn" {
  description = "ARN of the high severity findings CloudWatch alarm"
  value       = aws_cloudwatch_metric_alarm.high_severity_findings.arn
}

# ==============================================================================
# Lambda Function
# ==============================================================================

output "findings_processor_function_arn" {
  description = "ARN of the GuardDuty findings processor Lambda function"
  value       = var.enable_findings_processor ? aws_lambda_function.guardduty_processor[0].arn : null
}

output "findings_processor_function_name" {
  description = "Name of the GuardDuty findings processor Lambda function"
  value       = var.enable_findings_processor ? aws_lambda_function.guardduty_processor[0].function_name : null
}

output "findings_processor_role_arn" {
  description = "ARN of the GuardDuty findings processor IAM role"
  value       = var.enable_findings_processor ? aws_iam_role.guardduty_processor[0].arn : null
}

# ==============================================================================
# Threat Intelligence
# ==============================================================================

output "threat_intel_set_id" {
  description = "ID of the custom threat intelligence set"
  value       = var.custom_threat_intel_set_location != "" ? aws_guardduty_threat_intel_set.custom[0].id : null
}

output "trusted_ip_set_id" {
  description = "ID of the trusted IP set"
  value       = var.trusted_ip_set_location != "" ? aws_guardduty_ipset.trusted[0].id : null
}

# ==============================================================================
# CloudWatch Logs
# ==============================================================================

output "guardduty_log_group_name" {
  description = "Name of the GuardDuty CloudWatch log group"
  value       = aws_cloudwatch_log_group.guardduty_findings.name
}

output "guardduty_log_group_arn" {
  description = "ARN of the GuardDuty CloudWatch log group"
  value       = aws_cloudwatch_log_group.guardduty_findings.arn
}

# ==============================================================================
# Configuration Details
# ==============================================================================

output "finding_publishing_frequency" {
  description = "Frequency of publishing findings"
  value       = var.finding_publishing_frequency
}

output "crypto_mining_detection_enabled" {
  description = "Whether cryptocurrency mining detection is enabled"
  value       = var.enable_crypto_mining_detection
}

# ==============================================================================
# Module Information
# ==============================================================================

output "module_version" {
  description = "Version of the bedrock-security-guardduty module"
  value       = "1.0.0"
}

output "protection_features" {
  description = "Map of enabled protection features"
  value = {
    s3            = var.enable_s3_protection
    eks           = var.enable_eks_protection
    lambda        = var.enable_lambda_protection
    rds           = var.enable_rds_protection
    malware       = var.enable_malware_protection
    crypto_mining = var.enable_crypto_mining_detection
  }
}
