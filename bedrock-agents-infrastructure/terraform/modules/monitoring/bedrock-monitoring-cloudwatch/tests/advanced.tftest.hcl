# ==============================================================================
# CloudWatch Monitoring Module - Advanced Tests
# ==============================================================================

variables {
  project_name                     = "advanced-monitoring"
  environment                      = "prod"
  bedrock_agent_id                 = "AGENT456"
  bedrock_agent_alias_id           = "ALIAS456"
  lambda_function_names            = ["func1", "func2", "func3"]
  step_function_state_machine_arns = ["arn:aws:states:us-east-1:123456789012:stateMachine:test"]
  api_gateway_ids                  = ["api123"]
  enable_anomaly_detection         = true
  enable_composite_alarms          = true
  create_dashboard                 = true
  tags                             = { Environment = "prod" }
}

run "verify_anomaly_detection" {
  command = plan
  assert {
    condition     = length(aws_cloudwatch_metric_alarm.bedrock_invocation_anomaly) == 1
    error_message = "Anomaly detection alarm should be created"
  }
}

run "verify_composite_alarm" {
  command = plan
  assert {
    condition     = length(aws_cloudwatch_composite_alarm.bedrock_critical_health) == 1
    error_message = "Composite alarm should be created"
  }
}

run "verify_multiple_lambda_alarms" {
  command = plan
  assert {
    condition     = length(aws_cloudwatch_metric_alarm.lambda_errors) == 3
    error_message = "Should create alarms for all Lambda functions"
  }
}

run "verify_step_functions_alarms" {
  command = plan
  assert {
    condition     = length(aws_cloudwatch_metric_alarm.step_functions_failed) == 1
    error_message = "Step Functions failed executions alarm should be created"
  }
}

run "verify_api_gateway_alarms" {
  command = plan
  assert {
    condition     = length(aws_cloudwatch_metric_alarm.api_gateway_5xx) == 1
    error_message = "API Gateway 5XX alarm should be created"
  }
}
