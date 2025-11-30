output "event_bus_name" {
  description = "Name of the EventBridge event bus"
  value       = local.event_bus_name
}

output "event_bus_arn" {
  description = "ARN of the EventBridge event bus"
  value       = var.create_custom_event_bus ? aws_cloudwatch_event_bus.custom[0].arn : data.aws_cloudwatch_event_bus.default[0].arn
}

output "event_rule_arns" {
  description = "ARNs of EventBridge rules"
  value = {
    bedrock_state_change        = try(aws_cloudwatch_event_rule.bedrock_state_change[0].arn, null)
    bedrock_errors              = try(aws_cloudwatch_event_rule.bedrock_errors[0].arn, null)
    lambda_errors               = try(aws_cloudwatch_event_rule.lambda_errors[0].arn, null)
    lambda_throttles            = try(aws_cloudwatch_event_rule.lambda_throttles[0].arn, null)
    step_functions_state_change = try(aws_cloudwatch_event_rule.step_functions_state_change[0].arn, null)
    cloudtrail_insights         = try(aws_cloudwatch_event_rule.cloudtrail_insights[0].arn, null)
    config_compliance           = try(aws_cloudwatch_event_rule.config_compliance[0].arn, null)
    health_events               = try(aws_cloudwatch_event_rule.health_events[0].arn, null)
  }
}

output "custom_rule_arns" {
  description = "ARNs of custom EventBridge rules"
  value       = { for k, v in aws_cloudwatch_event_rule.custom : k => v.arn }
}

output "dlq_arn" {
  description = "ARN of the dead-letter queue"
  value       = try(aws_sqs_queue.dlq[0].arn, null)
}

output "dlq_url" {
  description = "URL of the dead-letter queue"
  value       = try(aws_sqs_queue.dlq[0].url, null)
}

output "archive_arn" {
  description = "ARN of the event archive"
  value       = try(aws_cloudwatch_event_archive.main[0].arn, null)
}

output "event_bus_console_url" {
  description = "URL to view EventBridge in AWS Console"
  value = "https://console.aws.amazon.com/events/home?region=${data.aws_region.current.region}#/eventbus/${local.event_bus_name}"
}

output "rules_console_url" {
  description = "URL to view EventBridge rules in AWS Console"
  value = "https://console.aws.amazon.com/events/home?region=${data.aws_region.current.region}#/rules"
}
