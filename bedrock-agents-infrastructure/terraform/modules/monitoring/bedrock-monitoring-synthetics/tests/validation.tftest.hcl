# ==============================================================================
# Synthetics Monitoring Module - Validation Tests
# ==============================================================================

variables {
  project_name = "validation-synthetics"
  environment  = "validation"
  canaries = {
    validation_canary = {
      handler = "index.handler"
      runtime_version = "syn-python-selenium-1.0"
      schedule_expression = "rate(5 minutes)"
      endpoint_url = "https://validation.example.com"
    }
  }
  tags = { Environment = "validation" }
}

run "validate_outputs" {
  command = plan
  assert {
    condition     = output.canary_ids["validation_canary"] != null
    error_message = "Canary ID should not be null"
  }
  assert {
    condition     = output.canary_arns["validation_canary"] != null
    error_message = "Canary ARN should not be null"
  }
  assert {
    condition     = can(regex("^arn:aws:synthetics:", output.canary_arns["validation_canary"]))
    error_message = "Canary ARN should be valid"
  }
}
