# ==============================================================================
# Bedrock Agent Module - Basic Tests
# ==============================================================================
# Tests basic functionality of the Bedrock agent module
# ==============================================================================

variables {
  agent_name  = "test-bedrock-agent"
  instruction = "You are a helpful assistant for testing purposes."
  description = "Test Bedrock agent for unit testing"

  tags = {
    Environment = "test"
    Purpose     = "testing"
  }
}

run "verify_agent_creation" {
  command = plan

  assert {
    condition     = aws_bedrockagent_agent.this.agent_name == "test-bedrock-agent"
    error_message = "Agent name does not match expected value"
  }

  assert {
    condition     = aws_bedrockagent_agent.this.foundation_model == "anthropic.claude-3-5-sonnet-20241022-v2:0"
    error_message = "Foundation model should default to Claude 3.5 Sonnet"
  }

  assert {
    condition     = aws_bedrockagent_agent.this.prepare_agent == true
    error_message = "Agent should be prepared by default"
  }
}

run "verify_iam_role_creation" {
  command = plan

  assert {
    condition     = aws_iam_role.agent.name == "test-bedrock-agent-agent-role"
    error_message = "IAM role name does not match expected format"
  }

  assert {
    condition     = can(regex("bedrock.amazonaws.com", aws_iam_role.agent.assume_role_policy))
    error_message = "IAM role should trust bedrock.amazonaws.com"
  }
}

run "verify_cloudwatch_log_group" {
  command = plan

  assert {
    condition     = aws_cloudwatch_log_group.agent.name == "/aws/bedrock/agents/test-bedrock-agent"
    error_message = "CloudWatch log group name does not match expected format"
  }

  assert {
    condition     = aws_cloudwatch_log_group.agent.retention_in_days == 30
    error_message = "Log retention should be 30 days"
  }
}

run "verify_tags_applied" {
  command = plan

  assert {
    condition     = aws_bedrockagent_agent.this.tags["Environment"] == "test"
    error_message = "Tags should be applied to the agent"
  }

  assert {
    condition     = aws_bedrockagent_agent.this.tags["ManagedBy"] == "Terraform"
    error_message = "ManagedBy tag should be set to Terraform"
  }
}

run "verify_session_ttl_default" {
  command = plan

  assert {
    condition     = aws_bedrockagent_agent.this.idle_session_ttl_in_seconds == 600
    error_message = "Default session TTL should be 600 seconds"
  }
}
