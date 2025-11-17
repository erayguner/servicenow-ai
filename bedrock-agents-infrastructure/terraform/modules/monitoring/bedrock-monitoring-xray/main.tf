# X-Ray Distributed Tracing for Bedrock Agents
# Provides end-to-end tracing across all services

locals {
  common_tags = merge(
    var.tags,
    {
      Module      = "bedrock-monitoring-xray"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )

  default_groups = var.create_groups ? {
    bedrock_errors = {
      filter_expression = "service(\"AWS::Bedrock::Agent\") AND error = true"
    }
    bedrock_slow = {
      filter_expression = "service(\"AWS::Bedrock::Agent\") AND responsetime > 10"
    }
    lambda_errors = {
      filter_expression = "service(\"AWS::Lambda\") AND error = true"
    }
    lambda_cold_start = {
      filter_expression = "service(\"AWS::Lambda\") AND annotation.aws.lambda.cold_start = true"
    }
    api_gateway_errors = {
      filter_expression = "service(\"AWS::ApiGateway\") AND http.status >= 500"
    }
    high_latency = {
      filter_expression = "responsetime > 5"
    }
  } : {}

  all_groups = merge(local.default_groups, var.group_definitions)
}

# ============================================================================
# X-Ray Encryption Configuration
# ============================================================================

resource "aws_xray_encryption_config" "main" {
  count = var.enable_xray_tracing && var.kms_key_id != null ? 1 : 0

  type   = "KMS"
  key_id = var.kms_key_id
}

# ============================================================================
# X-Ray Sampling Rules
# ============================================================================

# Default sampling rule for all services
resource "aws_xray_sampling_rule" "default" {
  count = var.enable_xray_tracing ? 1 : 0

  rule_name      = "${var.project_name}-${var.environment}-default"
  priority       = var.sampling_rule_priority + 100
  version        = 1
  reservoir_size = var.sampling_reservoir_size
  fixed_rate     = var.sampling_fixed_rate
  url_path       = "*"
  host           = "*"
  http_method    = "*"
  service_type   = "*"
  service_name   = "*"
  resource_arn   = "*"

  tags = local.common_tags
}

# Bedrock-specific sampling rule
resource "aws_xray_sampling_rule" "bedrock" {
  count = var.enable_xray_tracing ? 1 : 0

  rule_name      = "${var.project_name}-${var.environment}-bedrock"
  priority       = var.sampling_rule_priority
  version        = 1
  reservoir_size = var.sampling_reservoir_size
  fixed_rate     = var.bedrock_sampling_rate
  url_path       = "*"
  host           = "*"
  http_method    = "*"
  service_type   = "AWS::Bedrock::*"
  service_name   = "*"
  resource_arn   = "*"

  tags = local.common_tags
}

# Lambda-specific sampling rule
resource "aws_xray_sampling_rule" "lambda" {
  count = var.enable_xray_tracing ? 1 : 0

  rule_name      = "${var.project_name}-${var.environment}-lambda"
  priority       = var.sampling_rule_priority + 10
  version        = 1
  reservoir_size = var.sampling_reservoir_size
  fixed_rate     = var.lambda_sampling_rate
  url_path       = "*"
  host           = "*"
  http_method    = "*"
  service_type   = "AWS::Lambda"
  service_name   = "*"
  resource_arn   = "*"

  tags = local.common_tags
}

# API Gateway-specific sampling rule
resource "aws_xray_sampling_rule" "api_gateway" {
  count = var.enable_xray_tracing ? 1 : 0

  rule_name      = "${var.project_name}-${var.environment}-api-gateway"
  priority       = var.sampling_rule_priority + 20
  version        = 1
  reservoir_size = var.sampling_reservoir_size
  fixed_rate     = var.api_gateway_sampling_rate
  url_path       = "*"
  host           = "*"
  http_method    = "*"
  service_type   = "AWS::ApiGateway"
  service_name   = "*"
  resource_arn   = "*"

  tags = local.common_tags
}

# High-priority sampling for errors (sample all errors)
resource "aws_xray_sampling_rule" "errors" {
  count = var.enable_xray_tracing ? 1 : 0

  rule_name      = "${var.project_name}-${var.environment}-errors"
  priority       = 1
  version        = 1
  reservoir_size = 10
  fixed_rate     = 1.0 # Sample all errors
  url_path       = "*"
  host           = "*"
  http_method    = "*"
  service_type   = "*"
  service_name   = "*"
  resource_arn   = "*"

  attributes = {
    error = "true"
  }

  tags = local.common_tags
}

# ============================================================================
# X-Ray Groups
# ============================================================================

resource "aws_xray_group" "groups" {
  for_each = local.all_groups

  group_name        = "${var.project_name}-${var.environment}-${each.key}"
  filter_expression = each.value.filter_expression

  insights_configuration {
    insights_enabled      = var.enable_insights
    notifications_enabled = var.insights_notifications_enabled
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-${each.key}"
    }
  )
}

# ============================================================================
# X-Ray Insights Configuration
# ============================================================================

# EventBridge rule for X-Ray Insights notifications
resource "aws_cloudwatch_event_rule" "xray_insights" {
  count = var.enable_insights && var.insights_notifications_enabled && var.sns_topic_arn != null ? 1 : 0

  name        = "${var.project_name}-${var.environment}-xray-insights"
  description = "Capture X-Ray Insights events"

  event_pattern = jsonencode({
    source      = ["aws.xray"]
    detail-type = ["X-Ray Insight"]
  })

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "xray_insights_sns" {
  count = var.enable_insights && var.insights_notifications_enabled && var.sns_topic_arn != null ? 1 : 0

  rule      = aws_cloudwatch_event_rule.xray_insights[0].name
  target_id = "SendToSNS"
  arn       = var.sns_topic_arn

  input_transformer {
    input_paths = {
      insightId            = "$.detail.InsightId"
      state                = "$.detail.State"
      summary              = "$.detail.Summary"
      startTime            = "$.detail.StartTime"
      endTime              = "$.detail.EndTime"
      rootCauseServiceName = "$.detail.RootCauseServiceName"
    }

    input_template = <<EOF
{
  "insight_id": "<insightId>",
  "state": "<state>",
  "summary": "<summary>",
  "start_time": "<startTime>",
  "end_time": "<endTime>",
  "root_cause_service": "<rootCauseServiceName>",
  "message": "X-Ray Insight detected: <summary>"
}
EOF
  }
}

# ============================================================================
# Data Sources
# ============================================================================

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
