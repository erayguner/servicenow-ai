# ==============================================================================
# AWS Budget Module for Bedrock Agents Infrastructure
# ==============================================================================
# This module creates AWS Budgets to monitor and alert on costs for
# Bedrock AI agent workloads. Supports multiple budget types and
# notification thresholds.
#
# Usage:
#   module "budget" {
#     source = "../../modules/budget"
#
#     project_name   = "bedrock-agents"
#     environment    = "dev"
#     budget_amount  = 20.0
#     email_addresses = ["alerts@example.com"]
#   }
# ==============================================================================

# ------------------------------------------------------------------------------
# Monthly Cost Budget
# ------------------------------------------------------------------------------
resource "aws_budgets_budget" "monthly_cost" {
  name         = "${var.project_name}-${var.environment}-monthly-cost"
  budget_type  = "COST"
  limit_amount = var.budget_amount
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # Optional: Filter by specific services
  dynamic "cost_filter" {
    for_each = var.filter_services != null ? [1] : []
    content {
      name   = "Service"
      values = var.filter_services
    }
  }

  # Optional: Filter by tags
  dynamic "cost_filter" {
    for_each = var.filter_tags != null ? [1] : []
    content {
      name   = "TagKeyValue"
      values = [for k, v in var.filter_tags : "user:${k}$${v}"]
    }
  }

  # 50% threshold notification
  dynamic "notification" {
    for_each = var.enable_50_percent_alert ? [1] : []
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = 50
      threshold_type             = "PERCENTAGE"
      notification_type          = "ACTUAL"
      subscriber_email_addresses = var.email_addresses
      subscriber_sns_topic_arns  = var.sns_topic_arns
    }
  }

  # 80% threshold notification
  dynamic "notification" {
    for_each = var.enable_80_percent_alert ? [1] : []
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = 80
      threshold_type             = "PERCENTAGE"
      notification_type          = "ACTUAL"
      subscriber_email_addresses = var.email_addresses
      subscriber_sns_topic_arns  = var.sns_topic_arns
    }
  }

  # 100% threshold notification
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.email_addresses
    subscriber_sns_topic_arns  = var.sns_topic_arns
  }

  # Forecasted 100% notification
  dynamic "notification" {
    for_each = var.enable_forecast_alert ? [1] : []
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = 100
      threshold_type             = "PERCENTAGE"
      notification_type          = "FORECASTED"
      subscriber_email_addresses = var.email_addresses
      subscriber_sns_topic_arns  = var.sns_topic_arns
    }
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-monthly-cost"
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "budget"
  })
}

# ------------------------------------------------------------------------------
# Bedrock-Specific Budget (Optional)
# ------------------------------------------------------------------------------
resource "aws_budgets_budget" "bedrock_services" {
  count = var.create_bedrock_budget ? 1 : 0

  name         = "${var.project_name}-${var.environment}-bedrock-services"
  budget_type  = "COST"
  limit_amount = var.bedrock_budget_amount
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name = "Service"
    values = [
      "Amazon Bedrock",
      "Amazon Bedrock Runtime",
    ]
  }

  # 80% threshold
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.email_addresses
    subscriber_sns_topic_arns  = var.sns_topic_arns
  }

  # 100% threshold
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.email_addresses
    subscriber_sns_topic_arns  = var.sns_topic_arns
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-bedrock-services"
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "budget"
  })
}

# ------------------------------------------------------------------------------
# Lambda Budget (Optional)
# ------------------------------------------------------------------------------
resource "aws_budgets_budget" "lambda_services" {
  count = var.create_lambda_budget ? 1 : 0

  name         = "${var.project_name}-${var.environment}-lambda-services"
  budget_type  = "COST"
  limit_amount = var.lambda_budget_amount
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name = "Service"
    values = [
      "AWS Lambda",
    ]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.email_addresses
    subscriber_sns_topic_arns  = var.sns_topic_arns
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-lambda-services"
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "budget"
  })
}

# ------------------------------------------------------------------------------
# DynamoDB Budget (Optional)
# ------------------------------------------------------------------------------
resource "aws_budgets_budget" "dynamodb_services" {
  count = var.create_dynamodb_budget ? 1 : 0

  name         = "${var.project_name}-${var.environment}-dynamodb-services"
  budget_type  = "COST"
  limit_amount = var.dynamodb_budget_amount
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name = "Service"
    values = [
      "Amazon DynamoDB",
    ]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.email_addresses
    subscriber_sns_topic_arns  = var.sns_topic_arns
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-dynamodb-services"
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "budget"
  })
}

# ------------------------------------------------------------------------------
# Daily Budget Alert (Optional - for cost anomaly detection)
# ------------------------------------------------------------------------------
resource "aws_budgets_budget" "daily_cost" {
  count = var.create_daily_budget ? 1 : 0

  name         = "${var.project_name}-${var.environment}-daily-cost"
  budget_type  = "COST"
  limit_amount = var.daily_budget_amount
  limit_unit   = "USD"
  time_unit    = "DAILY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.email_addresses
    subscriber_sns_topic_arns  = var.sns_topic_arns
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-daily-cost"
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "budget"
  })
}
