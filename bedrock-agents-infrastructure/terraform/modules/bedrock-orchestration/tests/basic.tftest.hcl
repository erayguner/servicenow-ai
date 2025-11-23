# ==============================================================================
# Bedrock Orchestration Module - Basic Tests
# ==============================================================================
# Tests basic Step Functions and DynamoDB orchestration
# ==============================================================================

variables {
  orchestration_name = "test-orchestration"
  agent_arns = [
    "arn:aws:bedrock:us-east-1:123456789012:agent/AGENT123"
  ]

  create_dynamodb_table  = true
  use_default_definition = true
  orchestration_pattern  = "sequential"

  tags = {
    Environment = "test"
  }
}

run "verify_step_functions_creation" {
  command = plan

  assert {
    condition     = aws_sfn_state_machine.this.name == "test-orchestration"
    error_message = "State machine name should match input"
  }

  assert {
    condition     = aws_sfn_state_machine.this.type == "STANDARD"
    error_message = "Default state machine type should be STANDARD"
  }
}

run "verify_dynamodb_table_creation" {
  command = plan

  assert {
    condition     = length(aws_dynamodb_table.state) == 1
    error_message = "Should create one DynamoDB table"
  }

  assert {
    condition     = can(aws_dynamodb_table.state[0].hash_key == "execution_id")
    error_message = "Hash key should be execution_id"
  }

  assert {
    condition     = can(aws_dynamodb_table.state[0].range_key == "timestamp")
    error_message = "Range key should be timestamp"
  }
}

run "verify_iam_role_creation" {
  command = plan

  assert {
    condition     = can(regex("test-orchestration-sfn-role", aws_iam_role.state_machine.name))
    error_message = "IAM role name should match expected format"
  }

  assert {
    condition     = can(regex("states.amazonaws.com", aws_iam_role.state_machine.assume_role_policy))
    error_message = "IAM role should trust Step Functions service"
  }
}

run "verify_bedrock_agent_permissions" {
  command = plan

  assert {
    condition     = can(regex("bedrock:InvokeAgent", data.aws_iam_policy_document.sfn_permissions.json))
    error_message = "Should have permission to invoke Bedrock agents"
  }
}

run "verify_dynamodb_permissions" {
  command = plan

  assert {
    condition     = can(regex("dynamodb:PutItem", data.aws_iam_policy_document.sfn_permissions.json))
    error_message = "Should have DynamoDB write permissions"
  }
}
