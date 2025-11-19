output "canary_ids" {
  description = "IDs of the Synthetics canaries"
  value       = { for k, v in aws_synthetics_canary.canaries : k => v.id }
}

output "canary_arns" {
  description = "ARNs of the Synthetics canaries"
  value       = { for k, v in aws_synthetics_canary.canaries : k => v.arn }
}

output "canary_names" {
  description = "Names of the Synthetics canaries"
  value       = { for k, v in aws_synthetics_canary.canaries : k => v.name }
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for canary artifacts"
  value       = local.bucket_name
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for canary artifacts"
  value       = try(aws_s3_bucket.canary_artifacts[0].arn, "arn:aws:s3:::${var.s3_bucket_name}")
}

output "canary_role_arn" {
  description = "ARN of the IAM role for canaries"
  value       = try(aws_iam_role.canary[0].arn, null)
}

output "alarm_arns" {
  description = "ARNs of canary CloudWatch alarms"
  value = {
    failures = { for k, v in aws_cloudwatch_metric_alarm.canary_failures : k => v.arn }
    duration = { for k, v in aws_cloudwatch_metric_alarm.canary_duration : k => v.arn }
  }
}

output "canary_console_urls" {
  description = "URLs to view canaries in AWS Console"
  value = {
    for k, v in aws_synthetics_canary.canaries :
    k => "https://console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#synthetics:canary/detail/${v.name}"
  }
}
