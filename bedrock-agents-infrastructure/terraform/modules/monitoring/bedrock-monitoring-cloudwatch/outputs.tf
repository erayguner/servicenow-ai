output "sns_topic_arn" {
  description = "ARN of the SNS topic for alarms"
  value       = try(aws_sns_topic.alarms[0].arn, var.alarm_sns_topic_arn)
}

output "sns_topic_name" {
  description = "Name of the SNS topic for alarms"
  value       = try(aws_sns_topic.alarms[0].name, null)
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = try(aws_cloudwatch_dashboard.main[0].dashboard_name, null)
}

output "dashboard_arn" {
  description = "ARN of the CloudWatch dashboard"
  value       = try(aws_cloudwatch_dashboard.main[0].dashboard_arn, null)
}

output "bedrock_alarm_names" {
  description = "Names of Bedrock agent alarms"
  value = {
    invocation_errors   = try(aws_cloudwatch_metric_alarm.bedrock_invocation_errors[0].alarm_name, null)
    invocation_latency  = try(aws_cloudwatch_metric_alarm.bedrock_invocation_latency[0].alarm_name, null)
    throttles           = try(aws_cloudwatch_metric_alarm.bedrock_throttles[0].alarm_name, null)
    invocation_anomaly  = try(aws_cloudwatch_metric_alarm.bedrock_invocation_anomaly[0].alarm_name, null)
  }
}

output "lambda_alarm_names" {
  description = "Names of Lambda function alarms"
  value = {
    errors                 = { for k, v in aws_cloudwatch_metric_alarm.lambda_errors : k => v.alarm_name }
    duration              = { for k, v in aws_cloudwatch_metric_alarm.lambda_duration : k => v.alarm_name }
    throttles             = { for k, v in aws_cloudwatch_metric_alarm.lambda_throttles : k => v.alarm_name }
    concurrent_executions = { for k, v in aws_cloudwatch_metric_alarm.lambda_concurrent_executions : k => v.alarm_name }
  }
}

output "step_functions_alarm_names" {
  description = "Names of Step Functions alarms"
  value = {
    failed     = { for k, v in aws_cloudwatch_metric_alarm.step_functions_failed : k => v.alarm_name }
    timed_out  = { for k, v in aws_cloudwatch_metric_alarm.step_functions_timed_out : k => v.alarm_name }
  }
}

output "api_gateway_alarm_names" {
  description = "Names of API Gateway alarms"
  value = {
    errors_5xx = { for k, v in aws_cloudwatch_metric_alarm.api_gateway_5xx : k => v.alarm_name }
    latency    = { for k, v in aws_cloudwatch_metric_alarm.api_gateway_latency : k => v.alarm_name }
  }
}

output "composite_alarm_names" {
  description = "Names of composite alarms"
  value = {
    bedrock_critical_health = try(aws_cloudwatch_composite_alarm.bedrock_critical_health[0].alarm_name, null)
  }
}

output "metric_filters" {
  description = "Names of metric filters"
  value = {
    bedrock_errors   = { for k, v in aws_cloudwatch_log_metric_filter.bedrock_errors : k => v.name }
    bedrock_timeouts = { for k, v in aws_cloudwatch_log_metric_filter.bedrock_timeouts : k => v.name }
  }
}

output "custom_metric_namespace" {
  description = "Custom CloudWatch metric namespace"
  value       = var.metric_namespace
}
