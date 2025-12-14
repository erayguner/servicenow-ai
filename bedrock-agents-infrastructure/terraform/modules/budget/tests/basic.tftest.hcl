# Basic Terraform tests for AWS Budget module
# Tests basic functionality and default configuration

variables {
  project_name    = "test-budget"
  environment     = "dev"
  budget_amount   = 20.0
  email_addresses = ["test@example.com"]
}

# ==============================================================================
# Basic Functionality Tests
# ==============================================================================

# Test: Monthly budget is created with correct name
run "test_monthly_budget_created" {
  command = plan

  assert {
    condition     = aws_budgets_budget.monthly_cost.name == "test-budget-dev-monthly-cost"
    error_message = "Monthly budget name should follow naming convention"
  }
}

# Test: Budget amount is set correctly
run "test_budget_amount" {
  command = plan

  assert {
    condition     = aws_budgets_budget.monthly_cost.limit_amount == "20"
    error_message = "Budget amount should be 20 USD"
  }
}

# Test: Budget type is COST
run "test_budget_type" {
  command = plan

  assert {
    condition     = aws_budgets_budget.monthly_cost.budget_type == "COST"
    error_message = "Budget type should be COST"
  }
}

# Test: Budget time unit is MONTHLY
run "test_budget_time_unit" {
  command = plan

  assert {
    condition     = aws_budgets_budget.monthly_cost.time_unit == "MONTHLY"
    error_message = "Budget time unit should be MONTHLY"
  }
}

# Test: Budget currency is USD
run "test_budget_currency" {
  command = plan

  assert {
    condition     = aws_budgets_budget.monthly_cost.limit_unit == "USD"
    error_message = "Budget currency should be USD"
  }
}

# ==============================================================================
# Tag Tests
# ==============================================================================

# Test: Environment tag is set
run "test_environment_tag" {
  command = plan

  assert {
    condition     = aws_budgets_budget.monthly_cost.tags["Environment"] == "dev"
    error_message = "Environment tag should be 'dev'"
  }
}

# Test: ManagedBy tag is set
run "test_managed_by_tag" {
  command = plan

  assert {
    condition     = aws_budgets_budget.monthly_cost.tags["ManagedBy"] == "terraform"
    error_message = "ManagedBy tag should be 'terraform'"
  }
}

# Test: Module tag is set
run "test_module_tag" {
  command = plan

  assert {
    condition     = aws_budgets_budget.monthly_cost.tags["Module"] == "budget"
    error_message = "Module tag should be 'budget'"
  }
}

# ==============================================================================
# Default Configuration Tests
# ==============================================================================

# Test: Bedrock budget is created by default
run "test_bedrock_budget_created_by_default" {
  command = plan

  assert {
    condition     = length(aws_budgets_budget.bedrock_services) == 1
    error_message = "Bedrock budget should be created by default"
  }
}

# Test: Lambda budget is not created by default
run "test_lambda_budget_not_created_by_default" {
  command = plan

  assert {
    condition     = length(aws_budgets_budget.lambda_services) == 0
    error_message = "Lambda budget should not be created by default"
  }
}

# Test: DynamoDB budget is not created by default
run "test_dynamodb_budget_not_created_by_default" {
  command = plan

  assert {
    condition     = length(aws_budgets_budget.dynamodb_services) == 0
    error_message = "DynamoDB budget should not be created by default"
  }
}

# Test: Daily budget is not created by default
run "test_daily_budget_not_created_by_default" {
  command = plan

  assert {
    condition     = length(aws_budgets_budget.daily_cost) == 0
    error_message = "Daily budget should not be created by default"
  }
}
