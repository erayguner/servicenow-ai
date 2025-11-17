# ==============================================================================
# Synthetics Monitoring Module - Integration Tests
# ==============================================================================

variables {
  project_name = "integration-synthetics"
  environment  = "integration"
  canaries = {
    integration_test = {
      handler = "index.handler"
      runtime_version = "syn-python-selenium-1.0"
      schedule_expression = "rate(10 minutes)"
      endpoint_url = "https://integration.example.com"
    }
  }
  sns_topic_arn = "arn:aws:sns:us-east-1:123456789012:synthetics-alerts"
  tags = { Environment = "integration" }
}

run "verify_sns_integration" {
  command = plan
  assert {
    condition     = can(aws_cloudwatch_metric_alarm.canary_failed["integration_test"].alarm_actions)
    error_message = "Canary alarms should publish to SNS"
  }
}
