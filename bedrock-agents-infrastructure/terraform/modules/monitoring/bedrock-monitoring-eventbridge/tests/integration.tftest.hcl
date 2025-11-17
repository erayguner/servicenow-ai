# ==============================================================================
# EventBridge Monitoring Module - Integration Tests
# ==============================================================================

variables {
  project_name = "integration-eventbridge"
  environment  = "integration"
  create_event_bus = true
  sns_topic_arn = "arn:aws:sns:us-east-1:123456789012:eventbridge-notifications"
  lambda_function_arns = ["arn:aws:lambda:us-east-1:123456789012:function:event-handler"]
  tags = { Environment = "integration" }
}

run "verify_sns_target" {
  command = plan
  assert {
    condition     = can(aws_cloudwatch_event_target.bedrock_sns.arn == var.sns_topic_arn)
    error_message = "Events should be routed to SNS topic"
  }
}

run "verify_lambda_targets" {
  command = plan
  assert {
    condition     = length(aws_cloudwatch_event_target.lambda) > 0
    error_message = "Lambda targets should be configured"
  }
}
