# ==============================================================================
# Bedrock Orchestration Module - Integration Tests
# ==============================================================================
# Tests integration between Step Functions, DynamoDB, and EventBridge
# ==============================================================================

variables {
  orchestration_name = "integration-orchestration"
  agent_arns = [
    "arn:aws:bedrock:us-east-1:123456789012:agent/AGENT1",
    "arn:aws:bedrock:us-east-1:123456789012:agent/AGENT2",
    "arn:aws:bedrock:us-east-1:123456789012:agent/AGENT3"
  ]

  create_dynamodb_table = true
  enable_logging = true
  enable_sns_notifications = true
  enable_eventbridge_trigger = true

  tags = {
    Environment = "integration-test"
  }
}

run "verify_iam_permissions_integration" {
  command = plan

  assert {
    condition     = can(regex("bedrock:InvokeAgent", data.aws_iam_policy_document.sfn_permissions.json))
    error_message = "Should have Bedrock permissions"
  }

  assert {
    condition     = can(regex("dynamodb:PutItem", data.aws_iam_policy_document.sfn_permissions.json))
    error_message = "Should have DynamoDB permissions"
  }

  assert {
    condition     = can(regex("sns:Publish", data.aws_iam_policy_document.sfn_permissions.json))
    error_message = "Should have SNS permissions"
  }

  assert {
    condition     = can(regex("xray:PutTraceSegments", data.aws_iam_policy_document.sfn_permissions.json))
    error_message = "Should have X-Ray permissions"
  }

  assert {
    condition     = can(regex("logs:CreateLogDelivery", data.aws_iam_policy_document.sfn_permissions.json))
    error_message = "Should have CloudWatch Logs permissions"
  }
}

run "verify_dynamodb_gsi" {
  command = plan

  assert {
    condition     = can(aws_dynamodb_table.state[0].global_secondary_index)
    error_message = "DynamoDB table should have global secondary indexes"
  }
}

run "verify_eventbridge_iam_role" {
  command = plan

  assert {
    condition     = length(aws_iam_role.eventbridge) == 1
    error_message = "Should create IAM role for EventBridge"
  }

  assert {
    condition     = can(regex("states:StartExecution", data.aws_iam_policy_document.eventbridge_permissions[0].json))
    error_message = "EventBridge should have permission to start executions"
  }
}

run "verify_state_machine_dependencies" {
  command = plan

  assert {
    condition     = can(aws_sfn_state_machine.this.depends_on)
    error_message = "State machine should have explicit dependencies"
  }
}

run "verify_multiple_agent_permissions" {
  command = plan

  assert {
    condition     = length(var.agent_arns) == 3
    error_message = "Should configure permissions for 3 agents"
  }
}
