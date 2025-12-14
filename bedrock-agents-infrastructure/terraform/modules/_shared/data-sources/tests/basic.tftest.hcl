# Basic Terraform tests for Shared Data Sources module
# Tests that data sources are properly configured and return expected values

# ==============================================================================
# Basic Functionality Tests
# ==============================================================================

# Test: AWS caller identity data source is configured
run "test_caller_identity_data_source" {
  command = plan

  assert {
    condition     = data.aws_caller_identity.current.account_id != ""
    error_message = "AWS caller identity data source should return account ID"
  }
}

# Test: AWS region data source is configured
run "test_region_data_source" {
  command = plan

  assert {
    condition     = data.aws_region.current.name != ""
    error_message = "AWS region data source should return region name"
  }
}

# ==============================================================================
# Output Tests
# ==============================================================================

# Test: Account ID output is available
run "test_account_id_output" {
  command = plan

  assert {
    condition     = output.account_id != ""
    error_message = "Account ID output should be available and non-empty"
  }
}

# Test: Caller ARN output is available
run "test_caller_arn_output" {
  command = plan

  assert {
    condition     = output.caller_arn != ""
    error_message = "Caller ARN output should be available and non-empty"
  }
}

# Test: Region name output is available
run "test_region_name_output" {
  command = plan

  assert {
    condition     = output.region_name != ""
    error_message = "Region name output should be available and non-empty"
  }
}

# Test: Region ID output is available
run "test_region_id_output" {
  command = plan

  assert {
    condition     = output.region_id != ""
    error_message = "Region ID output should be available and non-empty"
  }
}
