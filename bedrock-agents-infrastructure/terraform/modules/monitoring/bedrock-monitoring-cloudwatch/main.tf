# CloudWatch Monitoring for Bedrock Agents
# Provides comprehensive monitoring with dashboards, alarms, and anomaly detection

locals {
  dashboard_name = var.dashboard_name != null ? var.dashboard_name : "${var.project_name}-${var.environment}-bedrock-monitoring"
  sns_topic_name = "${var.project_name}-${var.environment}-bedrock-alarms"

  common_tags = merge(
    var.tags,
    {
      Module      = "bedrock-monitoring-cloudwatch"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

# ============================================================================
# SNS Topic for Alarms
# ============================================================================

resource "aws_sns_topic" "alarms" {
  count = var.create_sns_topic ? 1 : 0

  name              = local.sns_topic_name
  display_name      = "Bedrock Agents Monitoring Alarms"
  kms_master_key_id = var.kms_key_id

  tags = merge(
    local.common_tags,
    {
      Name = local.sns_topic_name
    }
  )
}

resource "aws_sns_topic_subscription" "email" {
  for_each = var.create_sns_topic ? toset(var.sns_email_subscriptions) : []

  topic_arn = aws_sns_topic.alarms[0].arn
  protocol  = "email"
  endpoint  = each.value
}

# ============================================================================
# Bedrock Agent Alarms
# ============================================================================

# Bedrock Agent Invocation Errors
resource "aws_cloudwatch_metric_alarm" "bedrock_invocation_errors" {
  count = var.bedrock_agent_id != null ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-bedrock-invocation-errors"
  alarm_description   = "Bedrock agent invocation error rate is too high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.evaluation_periods
  threshold           = var.bedrock_error_rate_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = compact([var.alarm_sns_topic_arn, try(aws_sns_topic.alarms[0].arn, "")])
  actions_enabled     = var.alarm_actions_enabled

  metric_query {
    id          = "error_rate"
    expression  = "(errors / invocations) * 100"
    label       = "Error Rate"
    return_data = true
  }

  metric_query {
    id = "errors"
    metric {
      namespace   = "AWS/Bedrock"
      metric_name = "InvocationClientErrors"
      period      = 300
      stat        = "Sum"
      dimensions = {
        AgentId      = var.bedrock_agent_id
        AgentAliasId = var.bedrock_agent_alias_id
      }
    }
  }

  metric_query {
    id = "invocations"
    metric {
      namespace   = "AWS/Bedrock"
      metric_name = "Invocations"
      period      = 300
      stat        = "Sum"
      dimensions = {
        AgentId      = var.bedrock_agent_id
        AgentAliasId = var.bedrock_agent_alias_id
      }
    }
  }

  tags = local.common_tags
}

# Bedrock Agent Invocation Latency
resource "aws_cloudwatch_metric_alarm" "bedrock_invocation_latency" {
  count = var.bedrock_agent_id != null ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-bedrock-invocation-latency"
  alarm_description   = "Bedrock agent invocation latency is too high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.evaluation_periods
  metric_name         = "InvocationLatency"
  namespace           = "AWS/Bedrock"
  period              = 300
  statistic           = "Average"
  threshold           = var.bedrock_invocation_latency_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = compact([var.alarm_sns_topic_arn, try(aws_sns_topic.alarms[0].arn, "")])
  actions_enabled     = var.alarm_actions_enabled

  dimensions = {
    AgentId      = var.bedrock_agent_id
    AgentAliasId = var.bedrock_agent_alias_id
  }

  tags = local.common_tags
}

# Bedrock Agent Throttles
resource "aws_cloudwatch_metric_alarm" "bedrock_throttles" {
  count = var.bedrock_agent_id != null ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-bedrock-throttles"
  alarm_description   = "Bedrock agent is being throttled"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.evaluation_periods
  metric_name         = "ThrottledRequests"
  namespace           = "AWS/Bedrock"
  period              = 300
  statistic           = "Sum"
  threshold           = var.bedrock_throttle_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = compact([var.alarm_sns_topic_arn, try(aws_sns_topic.alarms[0].arn, "")])
  actions_enabled     = var.alarm_actions_enabled

  dimensions = {
    AgentId      = var.bedrock_agent_id
    AgentAliasId = var.bedrock_agent_alias_id
  }

  tags = local.common_tags
}

# ============================================================================
# Lambda Function Alarms
# ============================================================================

# Lambda Error Rate
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each = toset(var.lambda_function_names)

  alarm_name          = "${var.project_name}-${var.environment}-lambda-${each.value}-errors"
  alarm_description   = "Lambda function ${each.value} error rate is too high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.evaluation_periods
  threshold           = var.lambda_error_rate_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = compact([var.alarm_sns_topic_arn, try(aws_sns_topic.alarms[0].arn, "")])
  actions_enabled     = var.alarm_actions_enabled

  metric_query {
    id          = "error_rate"
    expression  = "(errors / invocations) * 100"
    label       = "Error Rate"
    return_data = true
  }

  metric_query {
    id = "errors"
    metric {
      namespace   = "AWS/Lambda"
      metric_name = "Errors"
      period      = 300
      stat        = "Sum"
      dimensions = {
        FunctionName = each.value
      }
    }
  }

  metric_query {
    id = "invocations"
    metric {
      namespace   = "AWS/Lambda"
      metric_name = "Invocations"
      period      = 300
      stat        = "Sum"
      dimensions = {
        FunctionName = each.value
      }
    }
  }

  tags = local.common_tags
}

# Lambda Duration
resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  for_each = toset(var.lambda_function_names)

  alarm_name          = "${var.project_name}-${var.environment}-lambda-${each.value}-duration"
  alarm_description   = "Lambda function ${each.value} duration is too high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.evaluation_periods
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Average"
  threshold           = var.lambda_duration_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = compact([var.alarm_sns_topic_arn, try(aws_sns_topic.alarms[0].arn, "")])
  actions_enabled     = var.alarm_actions_enabled

  dimensions = {
    FunctionName = each.value
  }

  tags = local.common_tags
}

# Lambda Throttles
resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  for_each = toset(var.lambda_function_names)

  alarm_name          = "${var.project_name}-${var.environment}-lambda-${each.value}-throttles"
  alarm_description   = "Lambda function ${each.value} is being throttled"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.evaluation_periods
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = var.lambda_throttles_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = compact([var.alarm_sns_topic_arn, try(aws_sns_topic.alarms[0].arn, "")])
  actions_enabled     = var.alarm_actions_enabled

  dimensions = {
    FunctionName = each.value
  }

  tags = local.common_tags
}

# Lambda Concurrent Executions
resource "aws_cloudwatch_metric_alarm" "lambda_concurrent_executions" {
  for_each = toset(var.lambda_function_names)

  alarm_name          = "${var.project_name}-${var.environment}-lambda-${each.value}-concurrent-executions"
  alarm_description   = "Lambda function ${each.value} concurrent executions are high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.evaluation_periods
  metric_name         = "ConcurrentExecutions"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Maximum"
  threshold           = var.lambda_concurrent_executions_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = compact([var.alarm_sns_topic_arn, try(aws_sns_topic.alarms[0].arn, "")])
  actions_enabled     = var.alarm_actions_enabled

  dimensions = {
    FunctionName = each.value
  }

  tags = local.common_tags
}

# ============================================================================
# Step Functions Alarms
# ============================================================================

# Step Functions Failed Executions
resource "aws_cloudwatch_metric_alarm" "step_functions_failed" {
  for_each = toset(var.step_function_state_machine_arns)

  alarm_name          = "${var.project_name}-${var.environment}-sfn-${basename(each.value)}-failed"
  alarm_description   = "Step Functions state machine ${basename(each.value)} has failed executions"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.evaluation_periods
  metric_name         = "ExecutionsFailed"
  namespace           = "AWS/States"
  period              = 300
  statistic           = "Sum"
  threshold           = var.step_functions_failed_executions_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = compact([var.alarm_sns_topic_arn, try(aws_sns_topic.alarms[0].arn, "")])
  actions_enabled     = var.alarm_actions_enabled

  dimensions = {
    StateMachineArn = each.value
  }

  tags = local.common_tags
}

# Step Functions Timed Out Executions
resource "aws_cloudwatch_metric_alarm" "step_functions_timed_out" {
  for_each = toset(var.step_function_state_machine_arns)

  alarm_name          = "${var.project_name}-${var.environment}-sfn-${basename(each.value)}-timed-out"
  alarm_description   = "Step Functions state machine ${basename(each.value)} has timed out executions"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.evaluation_periods
  metric_name         = "ExecutionsTimedOut"
  namespace           = "AWS/States"
  period              = 300
  statistic           = "Sum"
  threshold           = var.step_functions_timed_out_executions_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = compact([var.alarm_sns_topic_arn, try(aws_sns_topic.alarms[0].arn, "")])
  actions_enabled     = var.alarm_actions_enabled

  dimensions = {
    StateMachineArn = each.value
  }

  tags = local.common_tags
}

# ============================================================================
# API Gateway Alarms
# ============================================================================

# API Gateway 5XX Errors
resource "aws_cloudwatch_metric_alarm" "api_gateway_5xx" {
  for_each = toset(var.api_gateway_ids)

  alarm_name          = "${var.project_name}-${var.environment}-apigw-${each.value}-5xx"
  alarm_description   = "API Gateway ${each.value} 5XX error rate is too high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.evaluation_periods
  threshold           = var.api_gateway_5xx_error_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = compact([var.alarm_sns_topic_arn, try(aws_sns_topic.alarms[0].arn, "")])
  actions_enabled     = var.alarm_actions_enabled

  metric_query {
    id          = "error_rate"
    expression  = "(errors / count) * 100"
    label       = "5XX Error Rate"
    return_data = true
  }

  metric_query {
    id = "errors"
    metric {
      namespace   = "AWS/ApiGateway"
      metric_name = "5XXError"
      period      = 300
      stat        = "Sum"
      dimensions = {
        ApiName = each.value
      }
    }
  }

  metric_query {
    id = "count"
    metric {
      namespace   = "AWS/ApiGateway"
      metric_name = "Count"
      period      = 300
      stat        = "Sum"
      dimensions = {
        ApiName = each.value
      }
    }
  }

  tags = local.common_tags
}

# API Gateway Latency
resource "aws_cloudwatch_metric_alarm" "api_gateway_latency" {
  for_each = toset(var.api_gateway_ids)

  alarm_name          = "${var.project_name}-${var.environment}-apigw-${each.value}-latency"
  alarm_description   = "API Gateway ${each.value} latency is too high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.evaluation_periods
  metric_name         = "Latency"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Average"
  threshold           = var.api_gateway_latency_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = compact([var.alarm_sns_topic_arn, try(aws_sns_topic.alarms[0].arn, "")])
  actions_enabled     = var.alarm_actions_enabled

  dimensions = {
    ApiName = each.value
  }

  tags = local.common_tags
}

# ============================================================================
# Anomaly Detection
# ============================================================================

# Bedrock Invocation Anomaly Detector
resource "aws_cloudwatch_metric_alarm" "bedrock_invocation_anomaly" {
  count = var.enable_anomaly_detection && var.bedrock_agent_id != null ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-bedrock-invocation-anomaly"
  alarm_description   = "Anomaly detected in Bedrock agent invocations"
  comparison_operator = "LessThanLowerOrGreaterThanUpperThreshold"
  evaluation_periods  = 2
  threshold_metric_id = "anomaly1"
  treat_missing_data  = "notBreaching"
  alarm_actions       = compact([var.alarm_sns_topic_arn, try(aws_sns_topic.alarms[0].arn, "")])
  actions_enabled     = var.alarm_actions_enabled

  metric_query {
    id          = "invocations"
    return_data = true
    metric {
      namespace   = "AWS/Bedrock"
      metric_name = "Invocations"
      period      = 300
      stat        = "Sum"
      dimensions = {
        AgentId      = var.bedrock_agent_id
        AgentAliasId = var.bedrock_agent_alias_id
      }
    }
  }

  metric_query {
    id          = "anomaly1"
    expression  = "ANOMALY_DETECTION_BAND(invocations, 2)"
    label       = "Invocations (expected)"
    return_data = true
  }

  tags = local.common_tags
}

# ============================================================================
# Composite Alarms
# ============================================================================

# Critical Bedrock Agent Health Composite Alarm
resource "aws_cloudwatch_composite_alarm" "bedrock_critical_health" {
  count = var.enable_composite_alarms && var.bedrock_agent_id != null ? 1 : 0

  alarm_name        = "${var.project_name}-${var.environment}-bedrock-critical-health"
  alarm_description = "Critical health issues detected with Bedrock agent"
  actions_enabled   = var.alarm_actions_enabled
  alarm_actions     = compact([var.alarm_sns_topic_arn, try(aws_sns_topic.alarms[0].arn, "")])

  alarm_rule = join(" OR ", compact([
    try("ALARM(${aws_cloudwatch_metric_alarm.bedrock_invocation_errors[0].alarm_name})", ""),
    try("ALARM(${aws_cloudwatch_metric_alarm.bedrock_throttles[0].alarm_name})", ""),
  ]))

  tags = local.common_tags
}

# ============================================================================
# Metric Filters
# ============================================================================

# Bedrock Agent Error Pattern
resource "aws_cloudwatch_log_metric_filter" "bedrock_errors" {
  for_each = toset(var.log_group_names)

  name           = "${var.project_name}-${var.environment}-bedrock-errors"
  log_group_name = each.value
  pattern        = "[time, request_id, level = ERROR*, ...]"

  metric_transformation {
    name          = "BedrockErrorCount"
    namespace     = var.metric_namespace
    value         = "1"
    default_value = 0
  }
}

# Bedrock Agent Timeout Pattern
resource "aws_cloudwatch_log_metric_filter" "bedrock_timeouts" {
  for_each = toset(var.log_group_names)

  name           = "${var.project_name}-${var.environment}-bedrock-timeouts"
  log_group_name = each.value
  pattern        = "[time, request_id, level, msg = *timeout* || msg = *timed?out*]"

  metric_transformation {
    name          = "BedrockTimeoutCount"
    namespace     = var.metric_namespace
    value         = "1"
    default_value = 0
  }
}

# ============================================================================
# CloudWatch Dashboard
# ============================================================================

resource "aws_cloudwatch_dashboard" "main" {
  count = var.create_dashboard ? 1 : 0

  dashboard_name = local.dashboard_name
  dashboard_body = templatefile("${path.module}/templates/dashboard.json.tpl", {
    region = data.aws_region.current.region
    bedrock_agent_id       = var.bedrock_agent_id
    bedrock_agent_alias_id = var.bedrock_agent_alias_id
    lambda_functions       = jsonencode(var.lambda_function_names)
    step_functions         = jsonencode(var.step_function_state_machine_arns)
    api_gateways           = jsonencode(var.api_gateway_ids)
    metric_namespace       = var.metric_namespace
  })
}

# ============================================================================
# Data Sources
# ============================================================================

data "aws_region" "current" {}
