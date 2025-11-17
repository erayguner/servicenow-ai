# EventBridge Event-Driven Monitoring for Bedrock Agents
# Provides real-time event detection and automated responses

locals {
  event_bus_name = var.create_custom_event_bus ? "${var.project_name}-${var.environment}-events" : var.event_bus_name

  common_tags = merge(
    var.tags,
    {
      Module      = "bedrock-monitoring-eventbridge"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

# ============================================================================
# EventBridge Event Bus
# ============================================================================

resource "aws_cloudwatch_event_bus" "custom" {
  count = var.create_custom_event_bus ? 1 : 0

  name = local.event_bus_name

  tags = merge(
    local.common_tags,
    {
      Name = local.event_bus_name
    }
  )
}

# ============================================================================
# Dead Letter Queue for Failed Events
# ============================================================================

resource "aws_sqs_queue" "dlq" {
  count = var.enable_dlq ? 1 : 0

  name                      = "${var.project_name}-${var.environment}-events-dlq"
  message_retention_seconds = 1209600  # 14 days
  kms_master_key_id        = var.kms_key_id

  tags = local.common_tags
}

# ============================================================================
# EventBridge Rules - Bedrock Events
# ============================================================================

# Bedrock Agent State Changes
resource "aws_cloudwatch_event_rule" "bedrock_state_change" {
  count = var.enable_bedrock_state_change_events ? 1 : 0

  name           = "${var.project_name}-${var.environment}-bedrock-state-change"
  description    = "Capture Bedrock agent state changes"
  event_bus_name = local.event_bus_name

  event_pattern = jsonencode({
    source      = ["aws.bedrock"]
    detail-type = ["Bedrock Agent State Change"]
  })

  tags = local.common_tags
}

# Bedrock API Errors
resource "aws_cloudwatch_event_rule" "bedrock_errors" {
  count = var.enable_bedrock_error_events ? 1 : 0

  name           = "${var.project_name}-${var.environment}-bedrock-errors"
  description    = "Capture Bedrock API errors"
  event_bus_name = local.event_bus_name

  event_pattern = jsonencode({
    source      = ["aws.bedrock"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      errorCode = [{ exists = true }]
    }
  })

  tags = local.common_tags
}

# ============================================================================
# EventBridge Rules - Lambda Events
# ============================================================================

# Lambda Function Errors
resource "aws_cloudwatch_event_rule" "lambda_errors" {
  count = var.enable_lambda_error_events ? 1 : 0

  name           = "${var.project_name}-${var.environment}-lambda-errors"
  description    = "Capture Lambda function errors"
  event_bus_name = local.event_bus_name

  event_pattern = jsonencode({
    source      = ["aws.lambda"]
    detail-type = ["Lambda Function Execution State Change"]
    detail = {
      status = ["Failed"]
    }
  })

  tags = local.common_tags
}

# Lambda Throttling
resource "aws_cloudwatch_event_rule" "lambda_throttles" {
  count = var.enable_lambda_error_events ? 1 : 0

  name           = "${var.project_name}-${var.environment}-lambda-throttles"
  description    = "Capture Lambda throttling events"
  event_bus_name = local.event_bus_name

  event_pattern = jsonencode({
    source      = ["aws.lambda"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventName = ["Invoke"]
      errorCode = ["TooManyRequestsException"]
    }
  })

  tags = local.common_tags
}

# ============================================================================
# EventBridge Rules - Step Functions Events
# ============================================================================

# Step Functions Execution State Changes
resource "aws_cloudwatch_event_rule" "step_functions_state_change" {
  count = var.enable_step_functions_events ? 1 : 0

  name           = "${var.project_name}-${var.environment}-sfn-state-change"
  description    = "Capture Step Functions execution state changes"
  event_bus_name = local.event_bus_name

  event_pattern = jsonencode({
    source      = ["aws.states"]
    detail-type = ["Step Functions Execution Status Change"]
    detail = {
      status = ["FAILED", "TIMED_OUT", "ABORTED"]
    }
  })

  tags = local.common_tags
}

# ============================================================================
# EventBridge Rules - CloudTrail Insights
# ============================================================================

# CloudTrail Insights Events
resource "aws_cloudwatch_event_rule" "cloudtrail_insights" {
  count = var.enable_cloudtrail_insights_events ? 1 : 0

  name           = "${var.project_name}-${var.environment}-cloudtrail-insights"
  description    = "Capture CloudTrail Insights anomalies"
  event_bus_name = local.event_bus_name

  event_pattern = jsonencode({
    source      = ["aws.cloudtrail"]
    detail-type = ["AWS CloudTrail Insight"]
  })

  tags = local.common_tags
}

# ============================================================================
# EventBridge Rules - AWS Config
# ============================================================================

# Config Compliance Changes
resource "aws_cloudwatch_event_rule" "config_compliance" {
  count = var.enable_config_compliance_events ? 1 : 0

  name           = "${var.project_name}-${var.environment}-config-compliance"
  description    = "Capture AWS Config compliance changes"
  event_bus_name = local.event_bus_name

  event_pattern = jsonencode({
    source      = ["aws.config"]
    detail-type = ["Config Rules Compliance Change"]
    detail = {
      newEvaluationResult = {
        complianceType = ["NON_COMPLIANT"]
      }
    }
  })

  tags = local.common_tags
}

# ============================================================================
# EventBridge Rules - AWS Health
# ============================================================================

# AWS Health Events
resource "aws_cloudwatch_event_rule" "health_events" {
  count = var.enable_health_events ? 1 : 0

  name           = "${var.project_name}-${var.environment}-health-events"
  description    = "Capture AWS Health events affecting resources"
  event_bus_name = local.event_bus_name

  event_pattern = jsonencode({
    source      = ["aws.health"]
    detail-type = ["AWS Health Event"]
  })

  tags = local.common_tags
}

# ============================================================================
# Custom Event Rules
# ============================================================================

resource "aws_cloudwatch_event_rule" "custom" {
  for_each = var.custom_event_patterns

  name           = "${var.project_name}-${var.environment}-${each.key}"
  description    = each.value.description
  event_bus_name = local.event_bus_name
  event_pattern  = each.value.event_pattern

  tags = local.common_tags
}

# ============================================================================
# Event Targets - SNS
# ============================================================================

resource "aws_cloudwatch_event_target" "bedrock_state_change_sns" {
  count = var.enable_bedrock_state_change_events && var.sns_topic_arn != null ? 1 : 0

  rule           = aws_cloudwatch_event_rule.bedrock_state_change[0].name
  event_bus_name = local.event_bus_name
  arn            = var.sns_topic_arn

  dead_letter_config {
    arn = var.enable_dlq ? aws_sqs_queue.dlq[0].arn : null
  }
}

resource "aws_cloudwatch_event_target" "bedrock_errors_sns" {
  count = var.enable_bedrock_error_events && var.sns_topic_arn != null ? 1 : 0

  rule           = aws_cloudwatch_event_rule.bedrock_errors[0].name
  event_bus_name = local.event_bus_name
  arn            = var.sns_topic_arn

  dead_letter_config {
    arn = var.enable_dlq ? aws_sqs_queue.dlq[0].arn : null
  }
}

resource "aws_cloudwatch_event_target" "lambda_errors_sns" {
  count = var.enable_lambda_error_events && var.sns_topic_arn != null ? 1 : 0

  rule           = aws_cloudwatch_event_rule.lambda_errors[0].name
  event_bus_name = local.event_bus_name
  arn            = var.sns_topic_arn

  dead_letter_config {
    arn = var.enable_dlq ? aws_sqs_queue.dlq[0].arn : null
  }
}

resource "aws_cloudwatch_event_target" "step_functions_sns" {
  count = var.enable_step_functions_events && var.sns_topic_arn != null ? 1 : 0

  rule           = aws_cloudwatch_event_rule.step_functions_state_change[0].name
  event_bus_name = local.event_bus_name
  arn            = var.sns_topic_arn

  dead_letter_config {
    arn = var.enable_dlq ? aws_sqs_queue.dlq[0].arn : null
  }
}

resource "aws_cloudwatch_event_target" "config_compliance_sns" {
  count = var.enable_config_compliance_events && var.sns_topic_arn != null ? 1 : 0

  rule           = aws_cloudwatch_event_rule.config_compliance[0].name
  event_bus_name = local.event_bus_name
  arn            = var.sns_topic_arn

  dead_letter_config {
    arn = var.enable_dlq ? aws_sqs_queue.dlq[0].arn : null
  }
}

resource "aws_cloudwatch_event_target" "cloudtrail_insights_sns" {
  count = var.enable_cloudtrail_insights_events && var.sns_topic_arn != null ? 1 : 0

  rule           = aws_cloudwatch_event_rule.cloudtrail_insights[0].name
  event_bus_name = local.event_bus_name
  arn            = var.sns_topic_arn

  dead_letter_config {
    arn = var.enable_dlq ? aws_sqs_queue.dlq[0].arn : null
  }
}

resource "aws_cloudwatch_event_target" "health_events_sns" {
  count = var.enable_health_events && var.sns_topic_arn != null ? 1 : 0

  rule           = aws_cloudwatch_event_rule.health_events[0].name
  event_bus_name = local.event_bus_name
  arn            = var.sns_topic_arn

  dead_letter_config {
    arn = var.enable_dlq ? aws_sqs_queue.dlq[0].arn : null
  }
}

# ============================================================================
# Event Targets - SQS
# ============================================================================

resource "aws_cloudwatch_event_target" "bedrock_errors_sqs" {
  count = var.enable_bedrock_error_events && var.sqs_queue_arn != null ? 1 : 0

  rule           = aws_cloudwatch_event_rule.bedrock_errors[0].name
  event_bus_name = local.event_bus_name
  arn            = var.sqs_queue_arn

  dead_letter_config {
    arn = var.enable_dlq ? aws_sqs_queue.dlq[0].arn : null
  }
}

# ============================================================================
# Event Targets - Lambda
# ============================================================================

resource "aws_cloudwatch_event_target" "lambda_targets" {
  for_each = var.lambda_function_arns

  rule           = try(aws_cloudwatch_event_rule.bedrock_errors[0].name, aws_cloudwatch_event_rule.lambda_errors[0].name)
  event_bus_name = local.event_bus_name
  arn            = each.value

  dead_letter_config {
    arn = var.enable_dlq ? aws_sqs_queue.dlq[0].arn : null
  }
}

# ============================================================================
# Event Archive
# ============================================================================

resource "aws_cloudwatch_event_archive" "main" {
  count = var.enable_event_archiving ? 1 : 0

  name             = "${var.project_name}-${var.environment}-archive"
  event_source_arn = var.create_custom_event_bus ? aws_cloudwatch_event_bus.custom[0].arn : data.aws_cloudwatch_event_bus.default[0].arn
  retention_days   = var.archive_retention_days

  event_pattern = jsonencode({
    source = [
      "aws.bedrock",
      "aws.lambda",
      "aws.states",
      "aws.config",
      "aws.cloudtrail",
      "aws.health"
    ]
  })

  description = "Archive for ${var.project_name} ${var.environment} events"
}

# ============================================================================
# Data Sources
# ============================================================================

data "aws_cloudwatch_event_bus" "default" {
  count = !var.create_custom_event_bus ? 1 : 0
  name  = "default"
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
