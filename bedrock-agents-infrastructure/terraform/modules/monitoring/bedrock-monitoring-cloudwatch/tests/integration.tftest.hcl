# ==============================================================================
# CloudWatch Monitoring Module - Integration Tests
# ==============================================================================

variables {
  project_name = "integration-monitoring"
  environment  = "integration"
  bedrock_agent_id = "AGENT789"
  bedrock_agent_alias_id = "ALIAS789"
  lambda_function_names = ["integration-func"]
  log_group_names = ["/aws/lambda/integration-func"]
  create_sns_topic = false
  alarm_sns_topic_arn = "arn:aws:sns:us-east-1:123456789012:existing-topic"
  tags = { Environment = "integration" }
}

run "verify_existing_sns_topic_usage" {
  command = plan
  assert {
    condition     = length(aws_sns_topic.alarms) == 0
    error_message = "Should not create SNS topic when using existing"
  }
}

run "verify_metric_filters" {
  command = plan
  assert {
    condition     = length(aws_cloudwatch_log_metric_filter.bedrock_errors) == 1
    error_message = "Bedrock errors metric filter should be created"
  }
}
