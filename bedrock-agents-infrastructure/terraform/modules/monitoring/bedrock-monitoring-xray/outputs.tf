output "encryption_config_id" {
  description = "ID of the X-Ray encryption configuration"
  value       = try(aws_xray_encryption_config.main[0].id, null)
}

output "sampling_rule_ids" {
  description = "IDs of X-Ray sampling rules"
  value = {
    default     = try(aws_xray_sampling_rule.default[0].id, null)
    bedrock     = try(aws_xray_sampling_rule.bedrock[0].id, null)
    lambda      = try(aws_xray_sampling_rule.lambda[0].id, null)
    api_gateway = try(aws_xray_sampling_rule.api_gateway[0].id, null)
    errors      = try(aws_xray_sampling_rule.errors[0].id, null)
  }
}

output "sampling_rule_arns" {
  description = "ARNs of X-Ray sampling rules"
  value = {
    default     = try(aws_xray_sampling_rule.default[0].arn, null)
    bedrock     = try(aws_xray_sampling_rule.bedrock[0].arn, null)
    lambda      = try(aws_xray_sampling_rule.lambda[0].arn, null)
    api_gateway = try(aws_xray_sampling_rule.api_gateway[0].arn, null)
    errors      = try(aws_xray_sampling_rule.errors[0].arn, null)
  }
}

output "xray_group_ids" {
  description = "IDs of X-Ray groups"
  value       = { for k, v in aws_xray_group.groups : k => v.id }
}

output "xray_group_arns" {
  description = "ARNs of X-Ray groups"
  value       = { for k, v in aws_xray_group.groups : k => v.arn }
}

output "insights_event_rule_arn" {
  description = "ARN of the EventBridge rule for X-Ray Insights"
  value       = try(aws_cloudwatch_event_rule.xray_insights[0].arn, null)
}

output "service_map_url" {
  description = "URL to view X-Ray service map in AWS Console"
  value       = "https://console.aws.amazon.com/xray/home?region=${data.aws_region.current.region}#/service-map"
}

output "traces_url" {
  description = "URL to view X-Ray traces in AWS Console"
  value       = "https://console.aws.amazon.com/xray/home?region=${data.aws_region.current.region}#/traces"
}

output "analytics_url" {
  description = "URL to view X-Ray analytics in AWS Console"
  value       = "https://console.aws.amazon.com/xray/home?region=${data.aws_region.current.region}#/analytics"
}
