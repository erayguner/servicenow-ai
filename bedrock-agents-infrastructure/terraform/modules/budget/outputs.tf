# ==============================================================================
# Budget Module Outputs
# ==============================================================================

# ------------------------------------------------------------------------------
# Monthly Cost Budget Outputs
# ------------------------------------------------------------------------------

output "monthly_budget_id" {
  description = "The ID of the monthly cost budget"
  value       = aws_budgets_budget.monthly_cost.id
}

output "monthly_budget_name" {
  description = "The name of the monthly cost budget"
  value       = aws_budgets_budget.monthly_cost.name
}

output "monthly_budget_arn" {
  description = "The ARN of the monthly cost budget"
  value       = aws_budgets_budget.monthly_cost.arn
}

output "monthly_budget_amount" {
  description = "The monthly budget limit amount in USD"
  value       = aws_budgets_budget.monthly_cost.limit_amount
}

# ------------------------------------------------------------------------------
# Bedrock Budget Outputs
# ------------------------------------------------------------------------------

output "bedrock_budget_id" {
  description = "The ID of the Bedrock services budget"
  value       = var.create_bedrock_budget ? aws_budgets_budget.bedrock_services[0].id : null
}

output "bedrock_budget_name" {
  description = "The name of the Bedrock services budget"
  value       = var.create_bedrock_budget ? aws_budgets_budget.bedrock_services[0].name : null
}

output "bedrock_budget_arn" {
  description = "The ARN of the Bedrock services budget"
  value       = var.create_bedrock_budget ? aws_budgets_budget.bedrock_services[0].arn : null
}

# ------------------------------------------------------------------------------
# Lambda Budget Outputs
# ------------------------------------------------------------------------------

output "lambda_budget_id" {
  description = "The ID of the Lambda services budget"
  value       = var.create_lambda_budget ? aws_budgets_budget.lambda_services[0].id : null
}

output "lambda_budget_name" {
  description = "The name of the Lambda services budget"
  value       = var.create_lambda_budget ? aws_budgets_budget.lambda_services[0].name : null
}

# ------------------------------------------------------------------------------
# DynamoDB Budget Outputs
# ------------------------------------------------------------------------------

output "dynamodb_budget_id" {
  description = "The ID of the DynamoDB services budget"
  value       = var.create_dynamodb_budget ? aws_budgets_budget.dynamodb_services[0].id : null
}

output "dynamodb_budget_name" {
  description = "The name of the DynamoDB services budget"
  value       = var.create_dynamodb_budget ? aws_budgets_budget.dynamodb_services[0].name : null
}

# ------------------------------------------------------------------------------
# Daily Budget Outputs
# ------------------------------------------------------------------------------

output "daily_budget_id" {
  description = "The ID of the daily cost budget"
  value       = var.create_daily_budget ? aws_budgets_budget.daily_cost[0].id : null
}

output "daily_budget_name" {
  description = "The name of the daily cost budget"
  value       = var.create_daily_budget ? aws_budgets_budget.daily_cost[0].name : null
}

# ------------------------------------------------------------------------------
# Summary Outputs
# ------------------------------------------------------------------------------

output "all_budget_ids" {
  description = "Map of all created budget IDs"
  value = {
    monthly  = aws_budgets_budget.monthly_cost.id
    bedrock  = var.create_bedrock_budget ? aws_budgets_budget.bedrock_services[0].id : null
    lambda   = var.create_lambda_budget ? aws_budgets_budget.lambda_services[0].id : null
    dynamodb = var.create_dynamodb_budget ? aws_budgets_budget.dynamodb_services[0].id : null
    daily    = var.create_daily_budget ? aws_budgets_budget.daily_cost[0].id : null
  }
}

output "total_budgets_created" {
  description = "Total number of budgets created"
  value = (
    1 +
    (var.create_bedrock_budget ? 1 : 0) +
    (var.create_lambda_budget ? 1 : 0) +
    (var.create_dynamodb_budget ? 1 : 0) +
    (var.create_daily_budget ? 1 : 0)
  )
}

output "budget_configuration_summary" {
  description = "Summary of budget configuration"
  value = {
    monthly_limit           = var.budget_amount
    bedrock_limit           = var.create_bedrock_budget ? var.bedrock_budget_amount : null
    lambda_limit            = var.create_lambda_budget ? var.lambda_budget_amount : null
    dynamodb_limit          = var.create_dynamodb_budget ? var.dynamodb_budget_amount : null
    daily_limit             = var.create_daily_budget ? var.daily_budget_amount : null
    notification_emails     = length(var.email_addresses)
    notification_sns_topics = length(var.sns_topic_arns)
    alert_thresholds = {
      "50_percent"  = var.enable_50_percent_alert
      "80_percent"  = var.enable_80_percent_alert
      "100_percent" = true
      "forecast"    = var.enable_forecast_alert
    }
  }
}
