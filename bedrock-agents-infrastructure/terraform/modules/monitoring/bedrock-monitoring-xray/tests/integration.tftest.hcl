# ==============================================================================
# X-Ray Monitoring Module - Integration Tests
# ==============================================================================

variables {
  project_name      = "integration-xray"
  environment       = "integration"
  enable_xray       = true
  filter_expression = "service(\"bedrock-agent\") AND responsetime > 5"
  sns_topic_arn     = "arn:aws:sns:us-east-1:123456789012:xray-alerts"
  tags              = { Environment = "integration" }
}

run "verify_filter_expression" {
  command = plan
  assert {
    condition     = aws_xray_group.bedrock.filter_expression == var.filter_expression
    error_message = "Filter expression should match configuration"
  }
}

run "verify_cloudwatch_alarm" {
  command = plan
  assert {
    condition     = can(aws_cloudwatch_metric_alarm.xray_error_rate)
    error_message = "CloudWatch alarm for X-Ray metrics should be created"
  }
}
