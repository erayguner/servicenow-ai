output "trail_id" {
  description = "ID of the CloudTrail trail"
  value       = try(aws_cloudtrail.main[0].id, null)
}

output "trail_arn" {
  description = "ARN of the CloudTrail trail"
  value       = try(aws_cloudtrail.main[0].arn, null)
}

output "trail_name" {
  description = "Name of the CloudTrail trail"
  value       = local.trail_name
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for CloudTrail logs"
  value       = local.bucket_name
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for CloudTrail logs"
  value       = try(aws_s3_bucket.cloudtrail[0].arn, "arn:aws:s3:::${var.s3_bucket_name}")
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch Logs group"
  value       = try(aws_cloudwatch_log_group.cloudtrail[0].name, var.cloudwatch_logs_group_name)
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch Logs group"
  value       = try(aws_cloudwatch_log_group.cloudtrail[0].arn, null)
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for CloudTrail notifications"
  value       = try(aws_sns_topic.cloudtrail[0].arn, null)
}

output "cloudwatch_role_arn" {
  description = "ARN of the IAM role for CloudWatch Logs"
  value       = try(aws_iam_role.cloudtrail_cloudwatch[0].arn, null)
}

output "insights_query_ids" {
  description = "IDs of CloudWatch Insights queries"
  value = {
    bedrock_api_calls      = try(aws_cloudwatch_query_definition.bedrock_api_calls[0].query_definition_id, null)
    bedrock_errors         = try(aws_cloudwatch_query_definition.bedrock_errors[0].query_definition_id, null)
    unauthorized_api_calls = try(aws_cloudwatch_query_definition.unauthorized_api_calls[0].query_definition_id, null)
  }
}

output "trail_console_url" {
  description = "URL to view CloudTrail in AWS Console"
  value = "https://console.aws.amazon.com/cloudtrail/home?region=${data.aws_region.current.region}#/trails/${local.trail_name}"
}

output "event_history_url" {
  description = "URL to view CloudTrail event history in AWS Console"
  value = "https://console.aws.amazon.com/cloudtrail/home?region=${data.aws_region.current.region}#/events"
}
