# ==============================================================================
# Bedrock Agent Module - Advanced Tests
# ==============================================================================
# Tests advanced features including knowledge bases, action groups, and aliases
# ==============================================================================

variables {
  agent_name  = "advanced-test-agent"
  instruction = "Advanced testing agent with all features enabled"
  description = "Advanced test scenario"

  knowledge_bases = [
    {
      knowledge_base_id = "KB123456"
      description       = "Test knowledge base"
    }
  ]

  action_groups = [
    {
      action_group_name = "test-action-group"
      description       = "Test action group"
      lambda_arn        = "arn:aws:lambda:us-east-1:123456789012:function:test-function"
      api_schema = jsonencode({
        openapi = "3.0.0"
        info = {
          title   = "Test API"
          version = "1.0.0"
        }
      })
      enabled = true
    }
  ]

  agent_aliases = {
    production = {
      description = "Production alias"
      tags        = {}
    }
    staging = {
      description = "Staging alias"
      tags        = { Stage = "staging" }
    }
  }

  customer_encryption_key_arn = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"

  tags = {
    Environment = "test"
    Advanced    = "true"
  }
}

run "verify_knowledge_base_association" {
  command = plan

  assert {
    condition     = length(aws_bedrockagent_agent_knowledge_base_association.this) == 1
    error_message = "Should create one knowledge base association"
  }

  assert {
    condition     = can(aws_bedrockagent_agent_knowledge_base_association.this[0].knowledge_base_state == "ENABLED")
    error_message = "Knowledge base should be enabled"
  }
}

run "verify_action_group_creation" {
  command = plan

  assert {
    condition     = length(aws_bedrockagent_agent_action_group.this) == 1
    error_message = "Should create one action group"
  }

  assert {
    condition     = can(aws_bedrockagent_agent_action_group.this[0].action_group_state == "ENABLED")
    error_message = "Action group should be enabled"
  }

  assert {
    condition     = can(aws_bedrockagent_agent_action_group.this[0].agent_version == "DRAFT")
    error_message = "Action group should be attached to DRAFT version"
  }
}

run "verify_agent_aliases" {
  command = plan

  assert {
    condition     = length(aws_bedrockagent_agent_alias.this) == 2
    error_message = "Should create two agent aliases"
  }

  assert {
    condition     = can(aws_bedrockagent_agent_alias.this["production"].agent_alias_name == "production")
    error_message = "Production alias should exist"
  }

  assert {
    condition     = can(aws_bedrockagent_agent_alias.this["staging"].agent_alias_name == "staging")
    error_message = "Staging alias should exist"
  }
}

run "verify_kms_encryption" {
  command = plan

  assert {
    condition     = aws_bedrockagent_agent.this.customer_encryption_key_arn != null
    error_message = "KMS encryption should be configured"
  }

  assert {
    condition     = can(regex("kms:Decrypt", data.aws_iam_policy_document.agent_permissions.json))
    error_message = "IAM policy should include KMS decrypt permissions"
  }
}

run "verify_lambda_invocation_permissions" {
  command = plan

  assert {
    condition     = can(regex("lambda:InvokeFunction", data.aws_iam_policy_document.agent_permissions.json))
    error_message = "IAM policy should include Lambda invocation permissions"
  }
}

run "verify_knowledge_base_permissions" {
  command = plan

  assert {
    condition     = can(regex("bedrock:Retrieve", data.aws_iam_policy_document.agent_permissions.json))
    error_message = "IAM policy should include knowledge base retrieve permissions"
  }

  assert {
    condition     = can(regex("bedrock:RetrieveAndGenerate", data.aws_iam_policy_document.agent_permissions.json))
    error_message = "IAM policy should include RetrieveAndGenerate permissions"
  }
}
