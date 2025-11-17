# ==============================================================================
# Security Hub Module - Validation Tests
# ==============================================================================

variables {
  project_name = "validation-securityhub"
  environment  = "validation"
  enable_security_hub = true
  tags = { Environment = "validation" }
}

run "validate_outputs" {
  command = plan
  assert {
    condition     = output.security_hub_account_id != null
    error_message = "Security Hub account ID should not be null"
  }
  assert {
    condition     = output.enabled_standards != null
    error_message = "Enabled standards output should not be null"
  }
}
