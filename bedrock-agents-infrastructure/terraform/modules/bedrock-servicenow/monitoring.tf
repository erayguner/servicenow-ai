# CloudWatch alarms and monitoring for ServiceNow integration

# SNS Topic for Notifications
resource "aws_sns_topic" "servicenow_notifications" {
  name              = "${local.name_prefix}-notifications"
  display_name      = "ServiceNow Integration Notifications"
  kms_master_key_id = var.sns_kms_master_key_id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-notifications-topic"
    }
  )
}

# SNS Topic Policy
resource "aws_sns_topic_policy" "servicenow_notifications" {
  arn = aws_sns_topic.servicenow_notifications.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudWatchEvents"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.servicenow_notifications.arn
      },
      {
        Sid    = "AllowCloudWatchAlarms"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.servicenow_notifications.arn
      },
      {
        Sid    = "AllowStepFunctions"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.servicenow_notifications.arn
      }
    ]
  })
}

# SNS Topic Subscriptions (Email)
resource "aws_sns_topic_subscription" "email_notifications" {
  count = length(var.alarm_notification_emails)

  topic_arn = aws_sns_topic.servicenow_notifications.arn
  protocol  = "email"
  endpoint  = var.alarm_notification_emails[count.index]
}

# Lambda Error Rate Alarm
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  count = var.enable_enhanced_monitoring ? 1 : 0

  alarm_name          = "${local.name_prefix}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "ServiceNow integration Lambda function error rate"
  alarm_actions       = [aws_sns_topic.servicenow_notifications.arn]

  dimensions = {
    FunctionName = aws_lambda_function.servicenow_integration.function_name
  }

  tags = local.common_tags
}

# Lambda Throttle Alarm
resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  count = var.enable_enhanced_monitoring ? 1 : 0

  alarm_name          = "${local.name_prefix}-lambda-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "ServiceNow integration Lambda function throttles"
  alarm_actions       = [aws_sns_topic.servicenow_notifications.arn]

  dimensions = {
    FunctionName = aws_lambda_function.servicenow_integration.function_name
  }

  tags = local.common_tags
}

# Lambda Duration Alarm
resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  count = var.enable_enhanced_monitoring ? 1 : 0

  alarm_name          = "${local.name_prefix}-lambda-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Average"
  threshold           = var.lambda_timeout * 1000 * 0.8 # 80% of timeout
  alarm_description   = "ServiceNow integration Lambda function duration approaching timeout"
  alarm_actions       = [aws_sns_topic.servicenow_notifications.arn]

  dimensions = {
    FunctionName = aws_lambda_function.servicenow_integration.function_name
  }

  tags = local.common_tags
}

# API Gateway 5XX Error Alarm
resource "aws_cloudwatch_metric_alarm" "api_gateway_5xx" {
  count = var.enable_enhanced_monitoring ? 1 : 0

  alarm_name          = "${local.name_prefix}-api-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "ServiceNow webhook API Gateway 5XX errors"
  alarm_actions       = [aws_sns_topic.servicenow_notifications.arn]

  dimensions = {
    ApiName = aws_api_gateway_rest_api.servicenow_webhooks.name
    Stage   = aws_api_gateway_stage.servicenow_webhooks.stage_name
  }

  tags = local.common_tags
}

# API Gateway 4XX Error Alarm
resource "aws_cloudwatch_metric_alarm" "api_gateway_4xx" {
  count = var.enable_enhanced_monitoring ? 1 : 0

  alarm_name          = "${local.name_prefix}-api-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = "50"
  alarm_description   = "ServiceNow webhook API Gateway 4XX errors"
  alarm_actions       = [aws_sns_topic.servicenow_notifications.arn]

  dimensions = {
    ApiName = aws_api_gateway_rest_api.servicenow_webhooks.name
    Stage   = aws_api_gateway_stage.servicenow_webhooks.stage_name
  }

  tags = local.common_tags
}

# API Gateway Latency Alarm
resource "aws_cloudwatch_metric_alarm" "api_gateway_latency" {
  count = var.enable_enhanced_monitoring ? 1 : 0

  alarm_name          = "${local.name_prefix}-api-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Latency"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Average"
  threshold           = "5000"
  alarm_description   = "ServiceNow webhook API Gateway latency"
  alarm_actions       = [aws_sns_topic.servicenow_notifications.arn]

  dimensions = {
    ApiName = aws_api_gateway_rest_api.servicenow_webhooks.name
    Stage   = aws_api_gateway_stage.servicenow_webhooks.stage_name
  }

  tags = local.common_tags
}

# Step Functions Failed Execution Alarm
resource "aws_cloudwatch_metric_alarm" "step_functions_failed" {
  count = var.enable_enhanced_monitoring ? 1 : 0

  alarm_name          = "${local.name_prefix}-workflow-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ExecutionsFailed"
  namespace           = "AWS/States"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "ServiceNow workflow execution failures"
  alarm_actions       = [aws_sns_topic.servicenow_notifications.arn]

  dimensions = {
    StateMachineArn = aws_sfn_state_machine.incident_workflow.arn
  }

  tags = local.common_tags
}

# Step Functions Execution Time Alarm
resource "aws_cloudwatch_metric_alarm" "step_functions_duration" {
  count = var.enable_enhanced_monitoring ? 1 : 0

  alarm_name          = "${local.name_prefix}-workflow-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ExecutionTime"
  namespace           = "AWS/States"
  period              = "300"
  statistic           = "Average"
  threshold           = "60000" # 60 seconds
  alarm_description   = "ServiceNow workflow execution taking too long"
  alarm_actions       = [aws_sns_topic.servicenow_notifications.arn]

  dimensions = {
    StateMachineArn = aws_sfn_state_machine.incident_workflow.arn
  }

  tags = local.common_tags
}

# DynamoDB Read Throttle Alarm
resource "aws_cloudwatch_metric_alarm" "dynamodb_read_throttles" {
  count = var.enable_enhanced_monitoring ? 1 : 0

  alarm_name          = "${local.name_prefix}-dynamodb-read-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ReadThrottleEvents"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "ServiceNow state table read throttles"
  alarm_actions       = [aws_sns_topic.servicenow_notifications.arn]

  dimensions = {
    TableName = aws_dynamodb_table.servicenow_state.name
  }

  tags = local.common_tags
}

# DynamoDB Write Throttle Alarm
resource "aws_cloudwatch_metric_alarm" "dynamodb_write_throttles" {
  count = var.enable_enhanced_monitoring ? 1 : 0

  alarm_name          = "${local.name_prefix}-dynamodb-write-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "WriteThrottleEvents"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "ServiceNow state table write throttles"
  alarm_actions       = [aws_sns_topic.servicenow_notifications.arn]

  dimensions = {
    TableName = aws_dynamodb_table.servicenow_state.name
  }

  tags = local.common_tags
}

# Bedrock Agent Invocation Error Alarm
resource "aws_cloudwatch_metric_alarm" "bedrock_agent_errors" {
  count = var.enable_enhanced_monitoring ? 1 : 0

  alarm_name          = "${local.name_prefix}-bedrock-agent-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "InvocationClientErrors"
  namespace           = "AWS/Bedrock"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "Bedrock agent invocation errors"
  alarm_actions       = [aws_sns_topic.servicenow_notifications.arn]

  tags = local.common_tags
}

# Composite Alarm for Critical Issues
resource "aws_cloudwatch_composite_alarm" "critical_issues" {
  count = var.enable_enhanced_monitoring ? 1 : 0

  alarm_name        = "${local.name_prefix}-critical-issues"
  alarm_description = "Critical issues detected in ServiceNow integration"
  actions_enabled   = true
  alarm_actions     = [aws_sns_topic.servicenow_notifications.arn]

  alarm_rule = join(" OR ", compact([
    length(aws_cloudwatch_metric_alarm.lambda_errors) > 0 ? "ALARM(${aws_cloudwatch_metric_alarm.lambda_errors[0].alarm_name})" : "",
    length(aws_cloudwatch_metric_alarm.api_gateway_5xx) > 0 ? "ALARM(${aws_cloudwatch_metric_alarm.api_gateway_5xx[0].alarm_name})" : "",
    length(aws_cloudwatch_metric_alarm.step_functions_failed) > 0 ? "ALARM(${aws_cloudwatch_metric_alarm.step_functions_failed[0].alarm_name})" : "",
  ]))

  tags = local.common_tags

  depends_on = [
    aws_cloudwatch_metric_alarm.lambda_errors,
    aws_cloudwatch_metric_alarm.api_gateway_5xx,
    aws_cloudwatch_metric_alarm.step_functions_failed
  ]
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "servicenow_integration" {
  count = var.enable_enhanced_monitoring ? 1 : 0

  dashboard_name = "${local.name_prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", { stat = "Sum", label = "Lambda Invocations" }],
            [".", "Errors", { stat = "Sum", label = "Lambda Errors" }],
            [".", "Duration", { stat = "Average", label = "Lambda Duration" }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Lambda Metrics"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApiGateway", "Count", { stat = "Sum", label = "API Requests" }],
            [".", "4XXError", { stat = "Sum", label = "4XX Errors" }],
            [".", "5XXError", { stat = "Sum", label = "5XX Errors" }],
            [".", "Latency", { stat = "Average", label = "Latency" }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "API Gateway Metrics"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/States", "ExecutionsStarted", { stat = "Sum", label = "Executions Started" }],
            [".", "ExecutionsSucceeded", { stat = "Sum", label = "Executions Succeeded" }],
            [".", "ExecutionsFailed", { stat = "Sum", label = "Executions Failed" }],
            [".", "ExecutionTime", { stat = "Average", label = "Execution Time" }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Step Functions Metrics"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", { stat = "Sum", label = "Read Capacity" }],
            [".", "ConsumedWriteCapacityUnits", { stat = "Sum", label = "Write Capacity" }],
            [".", "ReadThrottleEvents", { stat = "Sum", label = "Read Throttles" }],
            [".", "WriteThrottleEvents", { stat = "Sum", label = "Write Throttles" }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "DynamoDB Metrics"
        }
      }
    ]
  })
}

# Custom Metrics
resource "aws_cloudwatch_log_metric_filter" "sla_breaches" {
  count = var.enable_sla_monitoring ? 1 : 0

  name           = "${local.name_prefix}-sla-breaches"
  log_group_name = aws_cloudwatch_log_group.lambda_integration.name
  pattern        = "[time, request_id, level, msg=\"SLA breach detected\", ...]"

  metric_transformation {
    name      = "SLABreaches"
    namespace = "ServiceNow/Integration"
    value     = "1"
    unit      = "Count"
  }
}

resource "aws_cloudwatch_metric_alarm" "sla_breach_alarm" {
  count = var.enable_sla_monitoring ? 1 : 0

  alarm_name          = "${local.name_prefix}-sla-breaches"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "SLABreaches"
  namespace           = "ServiceNow/Integration"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "SLA breach detected"
  alarm_actions       = [aws_sns_topic.servicenow_notifications.arn]
  treat_missing_data  = "notBreaching"

  tags = local.common_tags
}
