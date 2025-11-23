# ==============================================================================
# Security IAM Module - Basic Tests
# ==============================================================================

variables {
  project_name = "test-project"
  environment  = "test"
  aws_region   = "us-east-1"

  allowed_bedrock_models    = ["arn:aws:bedrock:us-east-1::foundation-model/*"]
  knowledge_base_arns       = []
  dynamodb_table_arns       = []
  kms_key_arns              = []
  sns_topic_arn             = "arn:aws:sns:us-east-1:123456789012:test-topic"
  cloudtrail_log_group_name = "/aws/cloudtrail/test"

  tags = {
    Environment = "test"
  }
}

run "verify_bedrock_agent_role" {
  command = plan

  assert {
    condition     = can(regex("test-project-bedrock-agent-execution-test", aws_iam_role.bedrock_agent_execution.name))
    error_message = "Bedrock agent execution role should be created"
  }
}

run "verify_lambda_execution_role" {
  command = plan

  assert {
    condition     = can(regex("test-project-bedrock-lambda-execution-test", aws_iam_role.lambda_execution.name))
    error_message = "Lambda execution role should be created"
  }
}

run "verify_bedrock_permissions" {
  command = plan

  assert {
    condition     = can(regex("bedrock:InvokeModel", data.aws_iam_policy_document.bedrock_agent_base.json))
    error_message = "Should have Bedrock model invocation permissions"
  }
}

run "verify_cloudwatch_alarms" {
  command = plan

  assert {
    condition     = aws_cloudwatch_metric_alarm.unauthorized_api_calls.alarm_name != null
    error_message = "Should create unauthorized API calls alarm"
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.iam_policy_changes.alarm_name != null
    error_message = "Should create IAM policy changes alarm"
  }
}
