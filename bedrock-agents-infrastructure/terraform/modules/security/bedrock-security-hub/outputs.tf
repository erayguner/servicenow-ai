# ==============================================================================
# Bedrock Security Hub Module - Outputs
# ==============================================================================

# ==============================================================================
# Security Hub Account
# ==============================================================================

output "security_hub_account_id" {
  description = "AWS account ID for Security Hub"
  value       = aws_securityhub_account.main.id
}

output "security_hub_arn" {
  description = "ARN of the Security Hub account"
  value       = aws_securityhub_account.main.arn
}

# ==============================================================================
# Security Standards
# ==============================================================================

output "aws_foundational_standard_subscription_arn" {
  description = "ARN of the AWS Foundational Security Best Practices subscription"
  value       = var.enable_aws_foundational_standard ? aws_securityhub_standards_subscription.aws_foundational[0].standards_subscription_arn : null
}

output "cis_aws_foundations_subscription_arn" {
  description = "ARN of the CIS AWS Foundations Benchmark subscription"
  value       = var.enable_cis_aws_foundations ? aws_securityhub_standards_subscription.cis_aws_foundations[0].standards_subscription_arn : null
}

output "pci_dss_subscription_arn" {
  description = "ARN of the PCI-DSS subscription"
  value       = var.enable_pci_dss ? aws_securityhub_standards_subscription.pci_dss[0].standards_subscription_arn : null
}

output "nist_subscription_arn" {
  description = "ARN of the NIST 800-53 subscription"
  value       = var.enable_nist ? aws_securityhub_standards_subscription.nist[0].standards_subscription_arn : null
}

# ==============================================================================
# Insights
# ==============================================================================

output "critical_findings_insight_arn" {
  description = "ARN of the critical findings insight"
  value       = aws_securityhub_insight.critical_findings.arn
}

output "failed_compliance_insight_arn" {
  description = "ARN of the failed compliance checks insight"
  value       = aws_securityhub_insight.failed_compliance_checks.arn
}

output "bedrock_findings_insight_arn" {
  description = "ARN of the Bedrock findings insight"
  value       = aws_securityhub_insight.bedrock_findings.arn
}

output "iam_findings_insight_arn" {
  description = "ARN of the IAM findings insight"
  value       = aws_securityhub_insight.iam_findings.arn
}

# ==============================================================================
# EventBridge Rules
# ==============================================================================

output "security_hub_findings_rule_arn" {
  description = "ARN of the Security Hub findings EventBridge rule"
  value       = aws_cloudwatch_event_rule.security_hub_findings.arn
}

output "high_severity_findings_rule_arn" {
  description = "ARN of the high severity findings EventBridge rule"
  value       = aws_cloudwatch_event_rule.high_severity_findings.arn
}

output "failed_compliance_rule_arn" {
  description = "ARN of the failed compliance EventBridge rule"
  value       = aws_cloudwatch_event_rule.failed_compliance.arn
}

# ==============================================================================
# CloudWatch Alarms
# ==============================================================================

output "critical_findings_alarm_arn" {
  description = "ARN of the critical findings CloudWatch alarm"
  value       = aws_cloudwatch_metric_alarm.critical_findings.arn
}

output "failed_compliance_alarm_arn" {
  description = "ARN of the failed compliance checks CloudWatch alarm"
  value       = aws_cloudwatch_metric_alarm.failed_compliance_checks.arn
}

# ==============================================================================
# Product Integrations
# ==============================================================================

output "guardduty_integration_arn" {
  description = "ARN of the GuardDuty product subscription"
  value       = var.enable_guardduty_integration ? aws_securityhub_product_subscription.guardduty[0].arn : null
}

output "config_integration_arn" {
  description = "ARN of the AWS Config product subscription"
  value       = var.enable_config_integration ? aws_securityhub_product_subscription.config[0].arn : null
}

output "inspector_integration_arn" {
  description = "ARN of the AWS Inspector product subscription"
  value       = var.enable_inspector_integration ? aws_securityhub_product_subscription.inspector[0].arn : null
}

output "access_analyzer_integration_arn" {
  description = "ARN of the IAM Access Analyzer product subscription"
  value       = var.enable_access_analyzer_integration ? aws_securityhub_product_subscription.access_analyzer[0].arn : null
}

# ==============================================================================
# Automated Remediation
# ==============================================================================

output "auto_remediation_function_arn" {
  description = "ARN of the auto-remediation Lambda function"
  value       = var.enable_auto_remediation ? aws_lambda_function.auto_remediation[0].arn : null
}

output "auto_remediation_function_name" {
  description = "Name of the auto-remediation Lambda function"
  value       = var.enable_auto_remediation ? aws_lambda_function.auto_remediation[0].function_name : null
}

output "auto_remediation_role_arn" {
  description = "ARN of the auto-remediation IAM role"
  value       = var.enable_auto_remediation ? aws_iam_role.auto_remediation[0].arn : null
}

output "auto_remediation_enabled" {
  description = "Whether auto-remediation is enabled"
  value       = var.enable_auto_remediation
}

output "remediation_dry_run" {
  description = "Whether remediation is in dry-run mode"
  value       = var.remediation_dry_run
}

# ==============================================================================
# Configuration Details
# ==============================================================================

output "enabled_standards" {
  description = "Map of enabled security standards"
  value = {
    aws_foundational = var.enable_aws_foundational_standard
    cis_aws_foundations = var.enable_cis_aws_foundations
    pci_dss = var.enable_pci_dss
    nist = var.enable_nist
  }
}

output "enabled_integrations" {
  description = "Map of enabled product integrations"
  value = {
    guardduty = var.enable_guardduty_integration
    config = var.enable_config_integration
    inspector = var.enable_inspector_integration
    access_analyzer = var.enable_access_analyzer_integration
  }
}

# ==============================================================================
# Module Information
# ==============================================================================

output "module_version" {
  description = "Version of the bedrock-security-hub module"
  value       = "1.0.0"
}
