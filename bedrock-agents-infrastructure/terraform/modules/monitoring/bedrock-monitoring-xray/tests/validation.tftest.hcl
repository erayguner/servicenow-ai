# ==============================================================================
# X-Ray Monitoring Module - Validation Tests
# ==============================================================================

variables {
  project_name = "validation-xray"
  environment  = "validation"
  enable_xray  = true
  tags         = { Environment = "validation" }
}

run "validate_outputs" {
  command = plan
  assert {
    condition     = output.xray_group_arn != null
    error_message = "X-Ray group ARN should not be null"
  }
  assert {
    condition     = output.sampling_rule_arn != null
    error_message = "Sampling rule ARN should not be null"
  }
  assert {
    condition     = can(regex("^arn:aws:xray:", output.xray_group_arn))
    error_message = "X-Ray group ARN should be valid"
  }
}
