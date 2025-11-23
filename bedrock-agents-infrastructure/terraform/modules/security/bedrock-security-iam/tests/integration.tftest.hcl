# ==============================================================================
# Security IAM Module - Integration Tests
# ==============================================================================

variables {
  project_name = "integration-project"
  environment  = "integration"
  aws_region   = "us-east-1"

  allowed_bedrock_models    = ["arn:aws:bedrock:us-east-1::foundation-model/*"]
  knowledge_base_arns       = ["arn:aws:bedrock:us-east-1:123456789012:knowledge-base/KB1", "arn:aws:bedrock:us-east-1:123456789012:knowledge-base/KB2"]
  dynamodb_table_arns       = ["arn:aws:dynamodb:us-east-1:123456789012:table/table1"]
  kms_key_arns              = ["arn:aws:kms:us-east-1:123456789012:key/key1"]
  sns_topic_arn             = "arn:aws:sns:us-east-1:123456789012:topic"
  cloudtrail_log_group_name = "/aws/cloudtrail/integration"

  enable_step_functions = true

  tags = {
    Environment = "integration"
  }
}

run "verify_knowledge_base_permissions" {
  command = plan

  assert {
    condition     = can(regex("bedrock:Retrieve", data.aws_iam_policy_document.bedrock_agent_base.json))
    error_message = "Should have knowledge base retrieve permissions"
  }
}

run "verify_lambda_dynamodb_access" {
  command = plan

  assert {
    condition     = can(regex("dynamodb:GetItem", data.aws_iam_policy_document.lambda_bedrock_access.json))
    error_message = "Lambda should have DynamoDB access"
  }
}

run "verify_metric_filters" {
  command = plan

  assert {
    condition     = aws_cloudwatch_log_metric_filter.unauthorized_api_calls.name != null
    error_message = "Should create unauthorized API calls metric filter"
  }

  assert {
    condition     = aws_cloudwatch_log_metric_filter.iam_policy_changes.name != null
    error_message = "Should create IAM policy changes metric filter"
  }
}
