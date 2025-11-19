# ==============================================================================
# Bedrock Agent Module - Validation Tests
# ==============================================================================
# Tests output validation and data integrity
# ==============================================================================

variables {
  agent_name  = "validation-test-agent"
  instruction = "Agent for output validation testing"
  description = "Validation test agent"

  agent_aliases = {
    prod = {
      description = "Production alias for validation"
      tags        = { Alias = "prod" }
    }
  }

  knowledge_bases = [
    {
      knowledge_base_id = "KBVAL001"
      description       = "Validation test KB"
    }
  ]

  action_groups = [
    {
      action_group_name = "validation-action"
      description       = "Validation action group"
      lambda_arn        = "arn:aws:lambda:us-east-1:123456789012:function:validation-func"
      api_schema        = jsonencode({ openapi = "3.0.0" })
      enabled           = true
    }
  ]

  tags = {
    Environment = "validation"
  }
}

run "validate_agent_outputs" {
  command = plan

  assert {
    condition     = output.agent_id != null
    error_message = "Agent ID output should not be null"
  }

  assert {
    condition     = output.agent_arn != null
    error_message = "Agent ARN output should not be null"
  }

  assert {
    condition     = output.agent_name == "validation-test-agent"
    error_message = "Agent name output should match input variable"
  }

  assert {
    condition     = output.agent_version != null
    error_message = "Agent version output should not be null"
  }
}

run "validate_iam_role_outputs" {
  command = plan

  assert {
    condition     = output.agent_role_arn != null
    error_message = "Agent role ARN output should not be null"
  }

  assert {
    condition     = output.agent_role_name != null
    error_message = "Agent role name output should not be null"
  }

  assert {
    condition     = can(regex("^arn:aws:iam::", output.agent_role_arn))
    error_message = "Agent role ARN should be a valid IAM ARN"
  }
}

run "validate_alias_outputs" {
  command = plan

  assert {
    condition     = length(output.agent_aliases) == 1
    error_message = "Should output one agent alias"
  }

  assert {
    condition     = can(output.agent_aliases["prod"].id)
    error_message = "Alias output should include ID"
  }

  assert {
    condition     = can(output.agent_aliases["prod"].agent_alias_arn)
    error_message = "Alias output should include ARN"
  }

  assert {
    condition     = can(output.agent_aliases["prod"].agent_alias_id)
    error_message = "Alias output should include alias ID"
  }
}

run "validate_knowledge_base_outputs" {
  command = plan

  assert {
    condition     = length(output.knowledge_base_associations) == 1
    error_message = "Should output one knowledge base association"
  }

  assert {
    condition     = can(output.knowledge_base_associations[0].knowledge_base_id == "KBVAL001")
    error_message = "Knowledge base output should include correct ID"
  }

  assert {
    condition     = can(output.knowledge_base_associations[0].state == "ENABLED")
    error_message = "Knowledge base output should include state"
  }
}

run "validate_action_group_outputs" {
  command = plan

  assert {
    condition     = length(output.action_groups) == 1
    error_message = "Should output one action group"
  }

  assert {
    condition     = can(output.action_groups[0].action_group_name == "validation-action")
    error_message = "Action group output should include correct name"
  }

  assert {
    condition     = can(output.action_groups[0].state)
    error_message = "Action group output should include state"
  }
}

run "validate_log_group_outputs" {
  command = plan

  assert {
    condition     = output.log_group_name != null
    error_message = "Log group name output should not be null"
  }

  assert {
    condition     = output.log_group_arn != null
    error_message = "Log group ARN output should not be null"
  }

  assert {
    condition     = can(regex("^/aws/bedrock/agents/", output.log_group_name))
    error_message = "Log group name should follow AWS naming convention"
  }

  assert {
    condition     = can(regex("^arn:aws:logs:", output.log_group_arn))
    error_message = "Log group ARN should be a valid CloudWatch Logs ARN"
  }
}

run "validate_output_types" {
  command = plan

  assert {
    condition     = can(tostring(output.agent_id))
    error_message = "Agent ID should be a string"
  }

  assert {
    condition     = can(tostring(output.agent_arn))
    error_message = "Agent ARN should be a string"
  }

  assert {
    condition     = can(tomap(output.agent_aliases))
    error_message = "Agent aliases should be a map"
  }

  assert {
    condition     = can(tomap(output.knowledge_base_associations))
    error_message = "Knowledge base associations should be a map"
  }

  assert {
    condition     = can(tomap(output.action_groups))
    error_message = "Action groups should be a map"
  }
}
