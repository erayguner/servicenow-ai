# ==============================================================================
# EventBridge Monitoring Module - Validation Tests
# ==============================================================================

variables {
  project_name = "validation-eventbridge"
  environment  = "validation"
  create_event_bus = true
  tags = { Environment = "validation" }
}

run "validate_outputs" {
  command = plan
  assert {
    condition     = output.event_bus_name != null
    error_message = "Event bus name should not be null"
  }
  assert {
    condition     = output.event_bus_arn != null
    error_message = "Event bus ARN should not be null"
  }
  assert {
    condition     = can(regex("^arn:aws:events:", output.event_bus_arn))
    error_message = "Event bus ARN should be valid"
  }
}
