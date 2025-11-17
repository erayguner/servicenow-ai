# ==============================================================================
# Security Hub Module - Integration Tests
# ==============================================================================

variables {
  project_name        = "integration-securityhub"
  environment         = "integration"
  enable_security_hub = true
  sns_topic_arn       = "arn:aws:sns:us-east-1:123456789012:security-alerts"
  tags                = { Environment = "integration" }
}

run "verify_eventbridge_rule" {
  command = plan
  assert {
    condition     = can(aws_cloudwatch_event_rule.security_hub_findings)
    error_message = "EventBridge rule for Security Hub findings should be created"
  }
}

run "verify_sns_target" {
  command = plan
  assert {
    condition     = can(aws_cloudwatch_event_target.security_hub_sns.arn == var.sns_topic_arn)
    error_message = "Security Hub findings should publish to SNS"
  }
}
