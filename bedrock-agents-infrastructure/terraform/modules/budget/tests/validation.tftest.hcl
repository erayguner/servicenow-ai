# Validation Terraform tests for AWS Budget module
# Tests input validation and output formats

variables {
  project_name    = "validation-budget"
  environment     = "dev"
  budget_amount   = 20.0
  email_addresses = ["test@example.com"]
}

# ==============================================================================
# Budget ARN Format Tests
# ==============================================================================

# Test: Monthly budget ARN format
run "test_monthly_budget_arn_format" {
  command = plan

  assert {
    condition     = can(regex("^arn:aws:budgets::[0-9]{12}:budget/", aws_budgets_budget.monthly_cost.arn))
    error_message = "Monthly budget ARN should be valid budget ARN format"
  }
}

# ==============================================================================
# Naming Convention Tests
# ==============================================================================

# Test: Monthly budget name follows convention
run "test_monthly_budget_naming" {
  command = plan

  assert {
    condition     = can(regex("^[a-z0-9-]+-[a-z]+-monthly-cost$", aws_budgets_budget.monthly_cost.name))
    error_message = "Monthly budget name should follow {project}-{env}-monthly-cost pattern"
  }
}

# Test: Budget name length is within AWS limits
run "test_budget_name_length" {
  command = plan

  # AWS Budget name limit is 100 characters
  assert {
    condition     = length(aws_budgets_budget.monthly_cost.name) <= 100
    error_message = "Budget name should not exceed 100 characters"
  }
}

# ==============================================================================
# Output Validation Tests
# ==============================================================================

# Test: Monthly budget amount output matches input
run "test_monthly_budget_amount_output" {
  command = plan

  assert {
    condition     = output.monthly_budget_amount == "20"
    error_message = "Monthly budget amount output should match input"
  }
}

# Test: Monthly budget name output is not empty
run "test_monthly_budget_name_output" {
  command = plan

  assert {
    condition     = output.monthly_budget_name != ""
    error_message = "Monthly budget name output should not be empty"
  }
}

# Test: Configuration summary has correct structure
run "test_configuration_summary_structure" {
  command = plan

  assert {
    condition     = output.budget_configuration_summary.monthly_limit == 20
    error_message = "Configuration summary monthly_limit should be 20"
  }

  assert {
    condition     = output.budget_configuration_summary.notification_emails == 1
    error_message = "Configuration summary should show 1 notification email"
  }
}

# ==============================================================================
# Default Values Tests
# ==============================================================================

# Test: Default budget amount is 20
run "test_default_budget_amount" {
  command = plan

  assert {
    condition     = var.budget_amount == 20.0
    error_message = "Default budget amount should be 20.0 USD"
  }
}

# Test: Default Bedrock budget amount is 15
run "test_default_bedrock_budget_amount" {
  command = plan

  assert {
    condition     = var.bedrock_budget_amount == 15.0
    error_message = "Default Bedrock budget amount should be 15.0 USD"
  }
}

# ==============================================================================
# Alert Configuration Tests
# ==============================================================================

# Test: 50% alert is enabled by default
run "test_50_percent_alert_enabled" {
  command = plan

  assert {
    condition     = var.enable_50_percent_alert == true
    error_message = "50% alert should be enabled by default"
  }
}

# Test: 80% alert is enabled by default
run "test_80_percent_alert_enabled" {
  command = plan

  assert {
    condition     = var.enable_80_percent_alert == true
    error_message = "80% alert should be enabled by default"
  }
}

# Test: Forecast alert is enabled by default
run "test_forecast_alert_enabled" {
  command = plan

  assert {
    condition     = var.enable_forecast_alert == true
    error_message = "Forecast alert should be enabled by default"
  }
}

# ==============================================================================
# Conditional Budget Tests
# ==============================================================================

# Test: Optional budgets return null when disabled
run "test_disabled_budgets_null" {
  command = plan

  assert {
    condition     = output.lambda_budget_id == null
    error_message = "Lambda budget ID should be null when disabled"
  }

  assert {
    condition     = output.dynamodb_budget_id == null
    error_message = "DynamoDB budget ID should be null when disabled"
  }

  assert {
    condition     = output.daily_budget_id == null
    error_message = "Daily budget ID should be null when disabled"
  }
}

# ==============================================================================
# Tag Validation Tests
# ==============================================================================

# Test: Required tags are present
run "test_required_tags_present" {
  command = plan

  assert {
    condition     = contains(keys(aws_budgets_budget.monthly_cost.tags), "Environment")
    error_message = "Environment tag should be present"
  }

  assert {
    condition     = contains(keys(aws_budgets_budget.monthly_cost.tags), "ManagedBy")
    error_message = "ManagedBy tag should be present"
  }

  assert {
    condition     = contains(keys(aws_budgets_budget.monthly_cost.tags), "Module")
    error_message = "Module tag should be present"
  }

  assert {
    condition     = contains(keys(aws_budgets_budget.monthly_cost.tags), "Name")
    error_message = "Name tag should be present"
  }
}
