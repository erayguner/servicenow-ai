# ==============================================================================
# Security IAM Module - Validation Tests
# ==============================================================================

variables {
  project_name = "validation-project"
  environment  = "validation"
  aws_region   = "us-east-1"

  allowed_bedrock_models = ["arn:aws:bedrock:us-east-1::foundation-model/*"]
  knowledge_base_arns    = []
  dynamodb_table_arns    = []
  kms_key_arns          = []
  sns_topic_arn         = "arn:aws:sns:us-east-1:123456789012:validation"
  cloudtrail_log_group_name = "/aws/cloudtrail/validation"

  tags = {
    Environment = "validation"
  }
}

run "validate_role_outputs" {
  command = plan

  assert {
    condition     = output.bedrock_agent_role_arn != null
    error_message = "Bedrock agent role ARN output should not be null"
  }

  assert {
    condition     = output.lambda_execution_role_arn != null
    error_message = "Lambda execution role ARN output should not be null"
  }

  assert {
    condition     = can(regex("^arn:aws:iam::", output.bedrock_agent_role_arn))
    error_message = "Role ARN should be valid IAM ARN"
  }
}

run "validate_alarm_outputs" {
  command = plan

  assert {
    condition     = output.unauthorized_api_calls_alarm_arn != null
    error_message = "Alarm ARN output should not be null"
  }
}
