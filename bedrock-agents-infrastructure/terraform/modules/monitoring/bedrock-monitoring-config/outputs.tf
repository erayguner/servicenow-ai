output "config_recorder_id" {
  description = "ID of the Config recorder"
  value       = try(aws_config_configuration_recorder.main[0].id, null)
}

output "config_recorder_role_arn" {
  description = "ARN of the Config recorder IAM role"
  value       = try(aws_iam_role.config[0].arn, null)
}

output "delivery_channel_id" {
  description = "ID of the Config delivery channel"
  value       = try(aws_config_delivery_channel.main[0].id, null)
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for Config"
  value       = local.bucket_name
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for Config"
  value       = try(aws_s3_bucket.config[0].arn, "arn:aws:s3:::${var.s3_bucket_name}")
}

output "config_rule_arns" {
  description = "ARNs of Config rules"
  value = {
    s3_encryption         = try(aws_config_config_rule.s3_bucket_encryption[0].arn, null)
    kms_rotation          = try(aws_config_config_rule.kms_key_rotation[0].arn, null)
    cloudwatch_encryption = try(aws_config_config_rule.cloudwatch_logs_encryption[0].arn, null)
    s3_public_access      = try(aws_config_config_rule.s3_public_access[0].arn, null)
    iam_user_no_policies  = try(aws_config_config_rule.iam_user_no_policies[0].arn, null)
    lambda_dlq            = try(aws_config_config_rule.lambda_dlq[0].arn, null)
    lambda_in_vpc         = try(aws_config_config_rule.lambda_in_vpc[0].arn, null)
  }
}

output "config_aggregator_arn" {
  description = "ARN of the Config aggregator"
  value       = try(aws_config_configuration_aggregator.main[0].arn, null)
}

output "compliance_dashboard_url" {
  description = "URL to view Config compliance dashboard in AWS Console"
  value       = "https://console.aws.amazon.com/config/home?region=${data.aws_region.current.region}#/dashboard"
}

output "rules_dashboard_url" {
  description = "URL to view Config rules in AWS Console"
  value       = "https://console.aws.amazon.com/config/home?region=${data.aws_region.current.region}#/rules"
}
