# Validation Terraform tests for Shared Data Sources module
# Tests output formats and data integrity

# ==============================================================================
# Account ID Validation Tests
# ==============================================================================

# Test: Account ID format is valid (12 digits)
run "test_account_id_format" {
  command = plan

  assert {
    condition     = can(regex("^[0-9]{12}$", output.account_id))
    error_message = "Account ID should be exactly 12 digits"
  }
}

# ==============================================================================
# Caller ARN Validation Tests
# ==============================================================================

# Test: Caller ARN is valid ARN format
run "test_caller_arn_format" {
  command = plan

  assert {
    condition     = can(regex("^arn:aws", output.caller_arn))
    error_message = "Caller ARN should start with 'arn:aws'"
  }
}

# Test: Caller ARN contains account ID
run "test_caller_arn_contains_account" {
  command = plan

  assert {
    condition     = can(regex(":[0-9]{12}:", output.caller_arn))
    error_message = "Caller ARN should contain the 12-digit account ID"
  }
}

# ==============================================================================
# Region Validation Tests
# ==============================================================================

# Test: Region name format is valid
run "test_region_name_format" {
  command = plan

  assert {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", output.region_name))
    error_message = "Region name should match AWS region format (e.g., eu-west-2)"
  }
}

# Test: Region ID matches region name
run "test_region_id_matches_name" {
  command = plan

  assert {
    condition     = output.region_id == output.region_name
    error_message = "Region ID should match region name"
  }
}

# ==============================================================================
# Data Source Consistency Tests
# ==============================================================================

# Test: Account ID in caller ARN matches account ID output
run "test_account_id_consistency" {
  command = plan

  assert {
    condition     = can(regex(output.account_id, output.caller_arn))
    error_message = "Account ID in caller ARN should match account_id output"
  }
}

# Test: All outputs are non-empty strings
run "test_outputs_non_empty" {
  command = plan

  assert {
    condition     = length(output.account_id) > 0
    error_message = "Account ID should not be empty"
  }

  assert {
    condition     = length(output.caller_arn) > 0
    error_message = "Caller ARN should not be empty"
  }

  assert {
    condition     = length(output.region_name) > 0
    error_message = "Region name should not be empty"
  }

  assert {
    condition     = length(output.region_id) > 0
    error_message = "Region ID should not be empty"
  }
}
