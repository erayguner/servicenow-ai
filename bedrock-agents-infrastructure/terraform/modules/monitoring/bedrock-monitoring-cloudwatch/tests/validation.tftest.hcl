# ==============================================================================
# CloudWatch Monitoring Module - Validation Tests
# ==============================================================================

variables {
  project_name           = "validation-monitoring"
  environment            = "validation"
  bedrock_agent_id       = "AGENTVAL"
  bedrock_agent_alias_id = "ALIASVAL"
  lambda_function_names  = []
  tags                   = { Environment = "validation" }
}

run "validate_outputs" {
  command = plan
  assert {
    condition     = output.sns_topic_arn != null
    error_message = "SNS topic ARN output should not be null"
  }
  assert {
    condition     = output.dashboard_name != null
    error_message = "Dashboard name output should not be null"
  }
  assert {
    condition     = can(regex("^arn:aws:sns:", output.sns_topic_arn))
    error_message = "SNS topic ARN should be valid"
  }
}
