# ==============================================================================
# Security GuardDuty Module - Basic Tests
# ==============================================================================

variables {
  project_name     = "test-guardduty"
  environment      = "test"
  enable_guardduty = true
  tags             = { Environment = "test" }
}

run "verify_guardduty_detector" {
  command = plan
  assert {
    condition     = aws_guardduty_detector.this.enable == true
    error_message = "GuardDuty detector should be enabled"
  }
}

run "verify_finding_publishing" {
  command = plan
  assert {
    condition     = can(aws_guardduty_detector.this.datasources[0].s3_logs[0].enable == true)
    error_message = "S3 logs should be enabled"
  }
}
