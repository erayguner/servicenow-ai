# ==============================================================================
# CloudWatch Monitoring Module - Basic Tests
# ==============================================================================

variables {
  project_name           = "test-monitoring"
  environment            = "test"
  bedrock_agent_id       = "AGENT123"
  bedrock_agent_alias_id = "ALIAS123"
  lambda_function_names  = ["test-function"]
  tags                   = { Environment = "test" }
}

run "verify_sns_topic" {
  command = plan
  assert {
    condition     = length(aws_sns_topic.alarms) == 1
    error_message = "SNS topic for alarms should be created"
  }
}

run "verify_bedrock_invocation_errors_alarm" {
  command = plan
  assert {
    condition     = length(aws_cloudwatch_metric_alarm.bedrock_invocation_errors) == 1
    error_message = "Bedrock invocation errors alarm should be created"
  }
}

run "verify_lambda_errors_alarm" {
  command = plan
  assert {
    condition     = length(aws_cloudwatch_metric_alarm.lambda_errors) == 1
    error_message = "Lambda errors alarm should be created"
  }
}

run "verify_dashboard" {
  command = plan
  assert {
    condition     = length(aws_cloudwatch_dashboard.main) == 1
    error_message = "CloudWatch dashboard should be created"
  }
}
