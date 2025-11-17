# ==============================================================================
# Security GuardDuty Module - Validation Tests
# ==============================================================================

variables {
  project_name     = "validation-guardduty"
  environment      = "validation"
  enable_guardduty = true
  tags             = { Environment = "validation" }
}

run "validate_outputs" {
  command = plan
  assert {
    condition     = output.guardduty_detector_id != null
    error_message = "GuardDuty detector ID should not be null"
  }
  assert {
    condition     = can(regex("^[a-f0-9]+$", output.guardduty_detector_id))
    error_message = "GuardDuty detector ID should be valid format"
  }
}
