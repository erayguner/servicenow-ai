# Advanced Terraform tests for AWS Budget module
# Tests complex configurations and all budget types

variables {
  project_name           = "advanced-budget"
  environment            = "prod"
  budget_amount          = 100.0
  bedrock_budget_amount  = 50.0
  lambda_budget_amount   = 20.0
  dynamodb_budget_amount = 15.0
  daily_budget_amount    = 5.0

  email_addresses = ["admin@example.com", "ops@example.com"]
  sns_topic_arns  = []

  enable_50_percent_alert = true
  enable_80_percent_alert = true
  enable_forecast_alert   = true

  create_bedrock_budget  = true
  create_lambda_budget   = true
  create_dynamodb_budget = true
  create_daily_budget    = true

  tags = {
    Team       = "platform"
    CostCenter = "engineering"
  }
}

# ==============================================================================
# All Budgets Enabled Tests
# ==============================================================================

# Test: Monthly budget is created
run "test_monthly_budget_prod" {
  command = plan

  assert {
    condition     = aws_budgets_budget.monthly_cost.name == "advanced-budget-prod-monthly-cost"
    error_message = "Monthly budget should be created for prod"
  }

  assert {
    condition     = aws_budgets_budget.monthly_cost.limit_amount == "100"
    error_message = "Monthly budget amount should be 100 USD"
  }
}

# Test: Bedrock budget is created
run "test_bedrock_budget_created" {
  command = plan

  assert {
    condition     = length(aws_budgets_budget.bedrock_services) == 1
    error_message = "Bedrock budget should be created"
  }

  assert {
    condition     = aws_budgets_budget.bedrock_services[0].limit_amount == "50"
    error_message = "Bedrock budget amount should be 50 USD"
  }

  assert {
    condition     = aws_budgets_budget.bedrock_services[0].name == "advanced-budget-prod-bedrock-services"
    error_message = "Bedrock budget should follow naming convention"
  }
}

# Test: Lambda budget is created
run "test_lambda_budget_created" {
  command = plan

  assert {
    condition     = length(aws_budgets_budget.lambda_services) == 1
    error_message = "Lambda budget should be created"
  }

  assert {
    condition     = aws_budgets_budget.lambda_services[0].limit_amount == "20"
    error_message = "Lambda budget amount should be 20 USD"
  }
}

# Test: DynamoDB budget is created
run "test_dynamodb_budget_created" {
  command = plan

  assert {
    condition     = length(aws_budgets_budget.dynamodb_services) == 1
    error_message = "DynamoDB budget should be created"
  }

  assert {
    condition     = aws_budgets_budget.dynamodb_services[0].limit_amount == "15"
    error_message = "DynamoDB budget amount should be 15 USD"
  }
}

# Test: Daily budget is created
run "test_daily_budget_created" {
  command = plan

  assert {
    condition     = length(aws_budgets_budget.daily_cost) == 1
    error_message = "Daily budget should be created"
  }

  assert {
    condition     = aws_budgets_budget.daily_cost[0].limit_amount == "5"
    error_message = "Daily budget amount should be 5 USD"
  }

  assert {
    condition     = aws_budgets_budget.daily_cost[0].time_unit == "DAILY"
    error_message = "Daily budget time unit should be DAILY"
  }
}

# ==============================================================================
# Custom Tags Tests
# ==============================================================================

# Test: Custom tags are applied to monthly budget
run "test_custom_tags_monthly" {
  command = plan

  assert {
    condition     = aws_budgets_budget.monthly_cost.tags["Team"] == "platform"
    error_message = "Team tag should be applied to monthly budget"
  }

  assert {
    condition     = aws_budgets_budget.monthly_cost.tags["CostCenter"] == "engineering"
    error_message = "CostCenter tag should be applied to monthly budget"
  }
}

# Test: Custom tags are applied to Bedrock budget
run "test_custom_tags_bedrock" {
  command = plan

  assert {
    condition     = aws_budgets_budget.bedrock_services[0].tags["Team"] == "platform"
    error_message = "Team tag should be applied to Bedrock budget"
  }
}

# ==============================================================================
# Service Filter Tests
# ==============================================================================

# Test: Bedrock budget filters by Bedrock services
run "test_bedrock_service_filter" {
  command = plan

  assert {
    condition     = length(aws_budgets_budget.bedrock_services[0].cost_filter) > 0
    error_message = "Bedrock budget should have service filter"
  }
}

# Test: Lambda budget filters by Lambda service
run "test_lambda_service_filter" {
  command = plan

  assert {
    condition     = length(aws_budgets_budget.lambda_services[0].cost_filter) > 0
    error_message = "Lambda budget should have service filter"
  }
}

# ==============================================================================
# Output Tests
# ==============================================================================

# Test: Total budgets created output
run "test_total_budgets_output" {
  command = plan

  assert {
    condition     = output.total_budgets_created == 5
    error_message = "Total budgets created should be 5"
  }
}

# Test: All budget IDs output contains all budgets
run "test_all_budget_ids_output" {
  command = plan

  assert {
    condition     = output.all_budget_ids.monthly != null
    error_message = "Monthly budget ID should be in output"
  }

  assert {
    condition     = output.all_budget_ids.bedrock != null
    error_message = "Bedrock budget ID should be in output"
  }

  assert {
    condition     = output.all_budget_ids.lambda != null
    error_message = "Lambda budget ID should be in output"
  }

  assert {
    condition     = output.all_budget_ids.dynamodb != null
    error_message = "DynamoDB budget ID should be in output"
  }

  assert {
    condition     = output.all_budget_ids.daily != null
    error_message = "Daily budget ID should be in output"
  }
}
