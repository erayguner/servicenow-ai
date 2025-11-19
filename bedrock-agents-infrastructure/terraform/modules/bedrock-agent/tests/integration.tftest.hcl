# ==============================================================================
# Bedrock Agent Module - Integration Tests
# ==============================================================================
# Tests integration with other AWS services and proper resource dependencies
# ==============================================================================

variables {
  agent_name  = "integration-test-agent"
  instruction = "Integration testing agent"
  description = "Test agent for integration scenarios"

  knowledge_bases = [
    {
      knowledge_base_id = "KB111111"
      description       = "Integration test KB 1"
    },
    {
      knowledge_base_id = "KB222222"
      description       = "Integration test KB 2"
    }
  ]

  action_groups = [
    {
      action_group_name = "action-group-1"
      description       = "First action group"
      lambda_arn        = "arn:aws:lambda:us-east-1:123456789012:function:function-1"
      api_schema        = jsonencode({ openapi = "3.0.0" })
      enabled           = true
    },
    {
      action_group_name = "action-group-2"
      description       = "Second action group"
      lambda_arn        = "arn:aws:lambda:us-east-1:123456789012:function:function-2"
      api_schema        = jsonencode({ openapi = "3.0.0" })
      enabled           = false
    }
  ]

  kms_key_id = "12345678-1234-1234-1234-123456789012"

  tags = {
    Environment = "integration-test"
  }
}

run "verify_multiple_knowledge_bases" {
  command = plan

  assert {
    condition     = length(aws_bedrockagent_agent_knowledge_base_association.this) == 2
    error_message = "Should create two knowledge base associations"
  }
}

run "verify_multiple_action_groups" {
  command = plan

  assert {
    condition     = length(aws_bedrockagent_agent_action_group.this) == 2
    error_message = "Should create two action groups"
  }
}

run "verify_action_group_states" {
  command = plan

  assert {
    condition     = can(aws_bedrockagent_agent_action_group.this[0].action_group_state == "ENABLED")
    error_message = "First action group should be enabled"
  }

  assert {
    condition     = can(aws_bedrockagent_agent_action_group.this[1].action_group_state == "DISABLED")
    error_message = "Second action group should be disabled"
  }
}

run "verify_cloudwatch_log_group_encryption" {
  command = plan

  assert {
    condition     = aws_cloudwatch_log_group.agent.kms_key_id != null
    error_message = "CloudWatch log group should be encrypted with KMS"
  }
}

run "verify_iam_permissions_for_multiple_lambdas" {
  command = plan

  assert {
    condition     = can(regex("function-1", data.aws_iam_policy_document.agent_permissions.json))
    error_message = "IAM policy should include permissions for function-1"
  }

  assert {
    condition     = can(regex("function-2", data.aws_iam_policy_document.agent_permissions.json))
    error_message = "IAM policy should include permissions for function-2"
  }
}

run "verify_iam_permissions_for_multiple_knowledge_bases" {
  command = plan

  assert {
    condition     = can(regex("KB111111", data.aws_iam_policy_document.agent_permissions.json))
    error_message = "IAM policy should include permissions for KB111111"
  }

  assert {
    condition     = can(regex("KB222222", data.aws_iam_policy_document.agent_permissions.json))
    error_message = "IAM policy should include permissions for KB222222"
  }
}

run "verify_resource_dependencies" {
  command = plan

  assert {
    condition     = can(aws_bedrockagent_agent.this.agent_resource_role_arn)
    error_message = "Agent should reference IAM role ARN"
  }
}

run "verify_cloudwatch_logs_permissions" {
  command = plan

  assert {
    condition     = can(regex("logs:CreateLogGroup", data.aws_iam_policy_document.agent_permissions.json))
    error_message = "IAM policy should include CloudWatch Logs permissions"
  }

  assert {
    condition     = can(regex("logs:PutLogEvents", data.aws_iam_policy_document.agent_permissions.json))
    error_message = "IAM policy should include PutLogEvents permission"
  }
}
