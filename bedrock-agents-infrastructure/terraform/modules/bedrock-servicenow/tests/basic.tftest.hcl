# Basic Terraform tests for ServiceNow integration module

variables {
  servicenow_instance_url = "https://test-instance.service-now.com"
  servicenow_auth_type    = "oauth"
  environment             = "dev"
  name_prefix             = "test-servicenow"

  # Disable optional features for basic test
  enable_incident_automation = true
  enable_ticket_triage      = true
  enable_change_management  = false
  enable_problem_management = false
  enable_knowledge_sync     = false
  enable_sla_monitoring     = true

  enable_enhanced_monitoring = false

  tags = {
    Environment = "test"
    Purpose     = "terraform-test"
  }
}

# Test: Module creates required resources
run "test_module_creates_resources" {
  command = plan

  assert {
    condition     = length(module.bedrock_agents) > 0
    error_message = "Module should create at least one Bedrock agent"
  }

  assert {
    condition     = aws_lambda_function.servicenow_integration.function_name != ""
    error_message = "ServiceNow integration Lambda function should be created"
  }

  assert {
    condition     = aws_api_gateway_rest_api.servicenow_webhooks.name != ""
    error_message = "API Gateway REST API should be created"
  }

  assert {
    condition     = aws_dynamodb_table.servicenow_state.name != ""
    error_message = "DynamoDB state table should be created"
  }

  assert {
    condition     = aws_sfn_state_machine.incident_workflow.name != ""
    error_message = "Incident workflow state machine should be created"
  }
}

# Test: Incident agent is created when enabled
run "test_incident_agent_creation" {
  command = plan

  assert {
    condition     = contains(keys(local.enabled_agents), "incident")
    error_message = "Incident agent should be in enabled agents list"
  }

  assert {
    condition     = length([for k, v in module.bedrock_agents : k if k == "incident"]) == 1
    error_message = "Incident agent module should be created"
  }
}

# Test: Triage agent is created when enabled
run "test_triage_agent_creation" {
  command = plan

  assert {
    condition     = contains(keys(local.enabled_agents), "triage")
    error_message = "Triage agent should be in enabled agents list"
  }
}

# Test: SLA agent is created when monitoring enabled
run "test_sla_agent_creation" {
  command = plan

  assert {
    condition     = contains(keys(local.enabled_agents), "sla")
    error_message = "SLA agent should be in enabled agents list when SLA monitoring is enabled"
  }
}

# Test: Change agent NOT created when disabled
run "test_change_agent_not_created" {
  command = plan

  assert {
    condition     = !contains(keys(local.enabled_agents), "change")
    error_message = "Change agent should not be created when change management is disabled"
  }
}

# Test: Lambda functions have correct configuration
run "test_lambda_configuration" {
  command = plan

  assert {
    condition     = aws_lambda_function.servicenow_integration.runtime == "python3.12"
    error_message = "Lambda runtime should be python3.12"
  }

  assert {
    condition     = aws_lambda_function.servicenow_integration.timeout == 300
    error_message = "Lambda timeout should be 300 seconds"
  }

  assert {
    condition     = aws_lambda_function.servicenow_integration.memory_size == 512
    error_message = "Lambda memory should be 512 MB"
  }
}

# Test: API Gateway has webhook resources
run "test_api_gateway_resources" {
  command = plan

  assert {
    condition     = aws_api_gateway_resource.webhooks.path_part == "webhooks"
    error_message = "API Gateway should have /webhooks resource"
  }

  assert {
    condition     = aws_api_gateway_resource.incident.path_part == "incident"
    error_message = "API Gateway should have /webhooks/incident resource"
  }

  assert {
    condition     = aws_api_gateway_method.incident_post.http_method == "POST"
    error_message = "Incident webhook should support POST method"
  }
}

# Test: DynamoDB table has correct indexes
run "test_dynamodb_indexes" {
  command = plan

  assert {
    condition     = aws_dynamodb_table.servicenow_state.hash_key == "ticketId"
    error_message = "DynamoDB table hash key should be ticketId"
  }

  assert {
    condition     = aws_dynamodb_table.servicenow_state.range_key == "timestamp"
    error_message = "DynamoDB table range key should be timestamp"
  }

  assert {
    condition     = length(aws_dynamodb_table.servicenow_state.global_secondary_index) == 2
    error_message = "DynamoDB table should have 2 global secondary indexes"
  }
}

# Test: IAM roles are created with correct trust policies
run "test_iam_roles" {
  command = plan

  assert {
    condition     = aws_iam_role.lambda_execution.name != ""
    error_message = "Lambda execution role should be created"
  }

  assert {
    condition     = aws_iam_role.step_functions.name != ""
    error_message = "Step Functions execution role should be created"
  }

  assert {
    condition     = aws_iam_role.eventbridge.name != ""
    error_message = "EventBridge role should be created"
  }
}

# Test: EventBridge rules are created for enabled features
run "test_eventbridge_rules" {
  command = plan

  assert {
    condition     = length(aws_cloudwatch_event_rule.incident_created) == 1
    error_message = "Incident created EventBridge rule should exist when incident automation is enabled"
  }

  assert {
    condition     = length(aws_cloudwatch_event_rule.sla_breach_warning) == 1
    error_message = "SLA breach EventBridge rule should exist when SLA monitoring is enabled"
  }

  assert {
    condition     = length(aws_cloudwatch_event_rule.change_created) == 0
    error_message = "Change created EventBridge rule should not exist when change management is disabled"
  }
}

# Test: Secrets Manager secret is created
run "test_secrets_manager" {
  command = plan

  assert {
    condition     = length(aws_secretsmanager_secret.servicenow_credentials) == 1
    error_message = "ServiceNow credentials secret should be created when not provided"
  }

  assert {
    condition     = aws_secretsmanager_secret.servicenow_credentials[0].recovery_window_in_days == 7
    error_message = "Secret recovery window should be 7 days"
  }
}

# Test: SNS topic is created
run "test_sns_topic" {
  command = plan

  assert {
    condition     = aws_sns_topic.servicenow_notifications.name != ""
    error_message = "SNS notification topic should be created"
  }
}

# Test: CloudWatch log groups are created
run "test_cloudwatch_log_groups" {
  command = plan

  assert {
    condition     = aws_cloudwatch_log_group.api_gateway.retention_in_days == 30
    error_message = "API Gateway log group should have 30 day retention"
  }

  assert {
    condition     = aws_cloudwatch_log_group.lambda_integration.retention_in_days == 30
    error_message = "Lambda log group should have 30 day retention"
  }
}

# Test: Tags are applied correctly
run "test_resource_tags" {
  command = plan

  assert {
    condition     = aws_dynamodb_table.servicenow_state.tags["Environment"] == "test"
    error_message = "DynamoDB table should have correct tags"
  }

  assert {
    condition     = contains(keys(aws_lambda_function.servicenow_integration.tags), "ManagedBy")
    error_message = "Lambda function should have ManagedBy tag"
  }
}

# Test: Step Functions workflow has correct states
run "test_workflow_definition" {
  command = plan

  assert {
    condition     = can(jsondecode(aws_sfn_state_machine.incident_workflow.definition))
    error_message = "Incident workflow definition should be valid JSON"
  }

  assert {
    condition     = jsondecode(aws_sfn_state_machine.incident_workflow.definition).StartAt == "AnalyzeIncident"
    error_message = "Incident workflow should start with AnalyzeIncident state"
  }
}

# Test: Outputs are defined
run "test_outputs_defined" {
  command = plan

  assert {
    condition     = output.api_gateway_url != null
    error_message = "API Gateway URL output should be defined"
  }

  assert {
    condition     = output.state_table_name != null
    error_message = "State table name output should be defined"
  }

  assert {
    condition     = output.integration_instructions != null
    error_message = "Integration instructions output should be defined"
  }
}
