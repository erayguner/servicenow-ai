# ==============================================================================
# Bedrock Orchestration Module - Validation Tests
# ==============================================================================
# Tests output validation
# ==============================================================================

variables {
  orchestration_name = "validation-orchestration"
  agent_arns         = ["arn:aws:bedrock:us-east-1:123456789012:agent/VAL123"]

  create_dynamodb_table    = true
  enable_sns_notifications = true

  tags = {
    Environment = "validation"
  }
}

run "validate_state_machine_outputs" {
  command = plan

  assert {
    condition     = output.state_machine_arn != null
    error_message = "State machine ARN output should not be null"
  }

  assert {
    condition     = output.state_machine_name != null
    error_message = "State machine name output should not be null"
  }

  assert {
    condition     = can(regex("^arn:aws:states:", output.state_machine_arn))
    error_message = "State machine ARN should be a valid Step Functions ARN"
  }
}

run "validate_dynamodb_outputs" {
  command = plan

  assert {
    condition     = output.dynamodb_table_name != null
    error_message = "DynamoDB table name output should not be null"
  }

  assert {
    condition     = output.dynamodb_table_arn != null
    error_message = "DynamoDB table ARN output should not be null"
  }

  assert {
    condition     = can(regex("^arn:aws:dynamodb:", output.dynamodb_table_arn))
    error_message = "DynamoDB ARN should be valid"
  }
}

run "validate_sns_outputs" {
  command = plan

  assert {
    condition     = output.sns_topic_arn != null
    error_message = "SNS topic ARN output should not be null"
  }

  assert {
    condition     = can(regex("^arn:aws:sns:", output.sns_topic_arn))
    error_message = "SNS topic ARN should be valid"
  }
}

run "validate_iam_role_outputs" {
  command = plan

  assert {
    condition     = output.state_machine_role_arn != null
    error_message = "State machine role ARN should not be null"
  }

  assert {
    condition     = can(regex("^arn:aws:iam::", output.state_machine_role_arn))
    error_message = "IAM role ARN should be valid"
  }
}
