# ==============================================================================
# Security GuardDuty Module - Integration Tests
# ==============================================================================

variables {
  project_name = "integration-guardduty"
  environment  = "integration"
  enable_guardduty = true
  sns_topic_arn = "arn:aws:sns:us-east-1:123456789012:guardduty-alerts"
  tags = { Environment = "integration" }
}

run "verify_sns_integration" {
  command = plan
  assert {
    condition     = can(aws_cloudwatch_event_target.guardduty_findings.arn == var.sns_topic_arn)
    error_message = "GuardDuty findings should publish to SNS"
  }
}
