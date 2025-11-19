# Integration tests for ServiceNow integration module

variables {
  servicenow_instance_url = "https://integration-test.service-now.com"
  servicenow_auth_type    = "oauth"
  environment             = "staging"
  name_prefix             = "integration-test"

  # Enable all features for integration testing
  enable_incident_automation = true
  enable_ticket_triage       = true
  enable_change_management   = true
  enable_problem_management  = true
  enable_knowledge_sync      = true
  enable_sla_monitoring      = true

  auto_assignment_enabled              = true
  auto_assignment_confidence_threshold = 0.85
  sla_breach_threshold                 = 80

  enable_enhanced_monitoring = true
  alarm_notification_emails  = ["test@example.com"]

  knowledge_base_ids      = []
  knowledge_sync_schedule = "cron(0 2 * * ? *)"

  incident_escalation_timeout_minutes = 30
  change_approval_timeout_minutes     = 240

  tags = {
    Environment = "integration-test"
    Purpose     = "terraform-integration-test"
  }
}

# Test: All 6 agents are created with full feature set
run "test_all_agents_created" {
  command = plan

  assert {
    condition     = length(local.enabled_agents) == 6
    error_message = "All 6 agents should be enabled: ${jsonencode(keys(local.enabled_agents))}"
  }

  assert {
    condition = alltrue([
      contains(keys(local.enabled_agents), "incident"),
      contains(keys(local.enabled_agents), "triage"),
      contains(keys(local.enabled_agents), "change"),
      contains(keys(local.enabled_agents), "problem"),
      contains(keys(local.enabled_agents), "knowledge"),
      contains(keys(local.enabled_agents), "sla")
    ])
    error_message = "All agent types should be present in enabled agents"
  }
}

# Test: All workflows are created
run "test_all_workflows_created" {
  command = plan

  assert {
    condition     = aws_sfn_state_machine.incident_workflow.name != ""
    error_message = "Incident workflow should be created"
  }

  assert {
    condition     = length(aws_sfn_state_machine.change_workflow) == 1
    error_message = "Change workflow should be created when change management is enabled"
  }
}

# Test: All EventBridge rules are created
run "test_all_eventbridge_rules" {
  command = plan

  assert {
    condition     = length(aws_cloudwatch_event_rule.incident_created) == 1
    error_message = "Incident created rule should exist"
  }

  assert {
    condition     = length(aws_cloudwatch_event_rule.incident_updated) == 1
    error_message = "Incident updated rule should exist"
  }

  assert {
    condition     = length(aws_cloudwatch_event_rule.sla_breach_warning) == 1
    error_message = "SLA breach warning rule should exist"
  }

  assert {
    condition     = length(aws_cloudwatch_event_rule.change_created) == 1
    error_message = "Change created rule should exist"
  }

  assert {
    condition     = length(aws_cloudwatch_event_rule.problem_detected) == 1
    error_message = "Problem detected rule should exist"
  }

  assert {
    condition     = length(aws_cloudwatch_event_rule.knowledge_sync_schedule) == 1
    error_message = "Knowledge sync schedule rule should exist"
  }
}

# Test: Knowledge sync Lambda is created
run "test_knowledge_sync_lambda" {
  command = plan

  assert {
    condition     = length(aws_lambda_function.knowledge_sync) == 1
    error_message = "Knowledge sync Lambda should be created when enabled"
  }

  assert {
    condition     = aws_lambda_function.knowledge_sync[0].timeout == 900
    error_message = "Knowledge sync Lambda timeout should be 900 seconds (15 minutes)"
  }

  assert {
    condition     = aws_lambda_function.knowledge_sync[0].memory_size == 1024
    error_message = "Knowledge sync Lambda should have 1024 MB memory"
  }
}

# Test: Monitoring alarms are created
run "test_monitoring_alarms_created" {
  command = plan

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.lambda_errors) == 1
    error_message = "Lambda error alarm should be created"
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.api_gateway_5xx) == 1
    error_message = "API Gateway 5xx alarm should be created"
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.step_functions_failed) == 1
    error_message = "Step Functions failure alarm should be created"
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.sla_breach_alarm) == 1
    error_message = "SLA breach alarm should be created"
  }
}

# Test: CloudWatch dashboard is created
run "test_cloudwatch_dashboard" {
  command = plan

  assert {
    condition     = length(aws_cloudwatch_dashboard.servicenow_integration) == 1
    error_message = "CloudWatch dashboard should be created when enhanced monitoring is enabled"
  }
}

# Test: Composite alarm is created
run "test_composite_alarm" {
  command = plan

  assert {
    condition     = length(aws_cloudwatch_composite_alarm.critical_issues) == 1
    error_message = "Composite alarm should be created for critical issues"
  }
}

# Test: SNS email subscriptions are created
run "test_sns_subscriptions" {
  command = plan

  assert {
    condition     = length(aws_sns_topic_subscription.email_notifications) == 1
    error_message = "SNS email subscription should be created for notification email"
  }
}

# Test: Agent action groups are properly configured
run "test_agent_action_groups" {
  command = plan

  # Verify incident agent has action groups
  assert {
    condition = length([
      for agent_key, agent_config in local.enabled_agents :
      agent_key if agent_key == "incident"
    ]) > 0
    error_message = "Incident agent should be configured"
  }

  # Verify triage agent has action groups
  assert {
    condition = length([
      for agent_key, agent_config in local.enabled_agents :
      agent_key if agent_key == "triage"
    ]) > 0
    error_message = "Triage agent should be configured"
  }

  # Verify knowledge agent has action groups
  assert {
    condition = length([
      for agent_key, agent_config in local.enabled_agents :
      agent_key if agent_key == "knowledge"
    ]) > 0
    error_message = "Knowledge agent should be configured"
  }
}

# Test: API Gateway has all required endpoints
run "test_api_gateway_complete_endpoints" {
  command = plan

  assert {
    condition     = aws_api_gateway_resource.incident.path_part == "incident"
    error_message = "Incident endpoint should exist"
  }

  assert {
    condition     = aws_api_gateway_resource.change.path_part == "change"
    error_message = "Change endpoint should exist"
  }

  assert {
    condition     = aws_api_gateway_resource.problem.path_part == "problem"
    error_message = "Problem endpoint should exist"
  }
}

# Test: API Gateway CORS is configured
run "test_api_gateway_cors" {
  command = plan

  assert {
    condition     = aws_api_gateway_method.incident_options.http_method == "OPTIONS"
    error_message = "CORS OPTIONS method should be configured"
  }

  assert {
    condition     = aws_api_gateway_integration.incident_options.type == "MOCK"
    error_message = "CORS integration should be MOCK type"
  }
}

# Test: API Gateway usage plan and API key
run "test_api_gateway_usage_plan" {
  command = plan

  assert {
    condition     = aws_api_gateway_usage_plan.servicenow_webhooks.name != ""
    error_message = "Usage plan should be created"
  }

  assert {
    condition     = aws_api_gateway_api_key.servicenow_webhooks.enabled == true
    error_message = "API key should be enabled"
  }

  assert {
    condition     = aws_api_gateway_usage_plan_key.servicenow_webhooks.key_type == "API_KEY"
    error_message = "API key should be associated with usage plan"
  }
}

# Test: EventBridge targets are properly configured
run "test_eventbridge_targets" {
  command = plan

  assert {
    condition     = length(aws_cloudwatch_event_target.incident_workflow) == 1
    error_message = "Incident workflow target should be configured"
  }

  assert {
    condition     = length(aws_cloudwatch_event_target.change_workflow) == 1
    error_message = "Change workflow target should be configured"
  }

  assert {
    condition     = length(aws_cloudwatch_event_target.sla_notification) == 1
    error_message = "SLA notification target should be configured"
  }
}

# Test: Lambda permissions are properly set
run "test_lambda_permissions" {
  command = plan

  # Check Bedrock agent permissions
  assert {
    condition     = length(aws_lambda_permission.bedrock_agent_invoke) == 6
    error_message = "Should have Lambda permissions for all 6 Bedrock agents"
  }

  # Check API Gateway permission
  assert {
    condition     = aws_lambda_permission.api_gateway_invoke.principal == "apigateway.amazonaws.com"
    error_message = "API Gateway should have permission to invoke Lambda"
  }

  # Check EventBridge permission for knowledge sync
  assert {
    condition     = length(aws_lambda_permission.eventbridge_knowledge_sync) == 1
    error_message = "EventBridge should have permission to invoke knowledge sync Lambda"
  }
}

# Test: IAM policies have required permissions
run "test_iam_policies_complete" {
  command = plan

  assert {
    condition     = aws_iam_role.lambda_execution.name != ""
    error_message = "Lambda execution role should exist"
  }

  assert {
    condition     = aws_iam_role.step_functions.name != ""
    error_message = "Step Functions role should exist"
  }

  assert {
    condition     = aws_iam_role.eventbridge.name != ""
    error_message = "EventBridge role should exist"
  }
}

# Test: DynamoDB streams are enabled
run "test_dynamodb_streams" {
  command = plan

  assert {
    condition     = aws_dynamodb_table.servicenow_state.stream_enabled == true
    error_message = "DynamoDB streams should be enabled"
  }

  assert {
    condition     = aws_dynamodb_table.servicenow_state.stream_view_type == "NEW_AND_OLD_IMAGES"
    error_message = "DynamoDB stream should capture both new and old images"
  }
}

# Test: DynamoDB has TTL enabled
run "test_dynamodb_ttl" {
  command = plan

  assert {
    condition     = aws_dynamodb_table.servicenow_state.ttl[0].enabled == true
    error_message = "DynamoDB TTL should be enabled"
  }

  assert {
    condition     = aws_dynamodb_table.servicenow_state.ttl[0].attribute_name == "expirationTime"
    error_message = "DynamoDB TTL attribute should be expirationTime"
  }
}

# Test: Point-in-time recovery is enabled
run "test_dynamodb_pitr" {
  command = plan

  assert {
    condition     = aws_dynamodb_table.servicenow_state.point_in_time_recovery[0].enabled == true
    error_message = "DynamoDB point-in-time recovery should be enabled"
  }
}

# Test: Incident workflow has all required states
run "test_incident_workflow_states" {
  command = plan

  locals {
    workflow_def = jsondecode(aws_sfn_state_machine.incident_workflow.definition)
  }

  assert {
    condition = alltrue([
      contains(keys(local.workflow_def.States), "AnalyzeIncident"),
      contains(keys(local.workflow_def.States), "CheckSeverity"),
      contains(keys(local.workflow_def.States), "EscalateImmediately"),
      contains(keys(local.workflow_def.States), "AssignToTeam"),
      contains(keys(local.workflow_def.States), "TriageTicket"),
      contains(keys(local.workflow_def.States), "StartSLAMonitor"),
      contains(keys(local.workflow_def.States), "UpdateState"),
      contains(keys(local.workflow_def.States), "CaptureKnowledge")
    ])
    error_message = "Incident workflow should have all required states"
  }
}

# Test: Change workflow has all required states
run "test_change_workflow_states" {
  command = plan

  locals {
    change_workflow_def = jsondecode(aws_sfn_state_machine.change_workflow[0].definition)
  }

  assert {
    condition = alltrue([
      contains(keys(local.change_workflow_def.States), "AnalyzeChange"),
      contains(keys(local.change_workflow_def.States), "AssessRisk"),
      contains(keys(local.change_workflow_def.States), "RequireCABApproval"),
      contains(keys(local.change_workflow_def.States), "AutoApprove"),
      contains(keys(local.change_workflow_def.States), "ScheduleChange")
    ])
    error_message = "Change workflow should have all required states"
  }
}

# Test: Event archive is created
run "test_event_archive" {
  command = plan

  assert {
    condition     = aws_cloudwatch_event_archive.servicenow_events.retention_days == 90
    error_message = "Event archive should retain events for 90 days"
  }
}

# Test: API destination is configured
run "test_api_destination" {
  command = plan

  assert {
    condition     = aws_cloudwatch_event_api_destination.servicenow.http_method == "POST"
    error_message = "API destination should use POST method"
  }

  assert {
    condition     = aws_cloudwatch_event_api_destination.servicenow.invocation_rate_limit_per_second == 10
    error_message = "API destination should have rate limit of 10 per second"
  }
}

# Test: All outputs are properly defined
run "test_all_outputs" {
  command = plan

  assert {
    condition = alltrue([
      output.bedrock_agents != null,
      output.webhook_endpoints != null,
      output.incident_workflow_arn != null,
      output.change_workflow_arn != null,
      output.state_table_name != null,
      output.notification_topic_arn != null,
      output.api_gateway_url != null,
      output.configuration != null,
      output.integration_instructions != null
    ])
    error_message = "All expected outputs should be defined"
  }
}

# Test: Configuration output has all feature flags
run "test_configuration_output" {
  command = plan

  assert {
    condition = alltrue([
      output.configuration.incident_automation_enabled == true,
      output.configuration.ticket_triage_enabled == true,
      output.configuration.change_management_enabled == true,
      output.configuration.problem_management_enabled == true,
      output.configuration.knowledge_sync_enabled == true,
      output.configuration.sla_monitoring_enabled == true
    ])
    error_message = "Configuration output should reflect all enabled features"
  }
}

# Test: Integration instructions are complete
run "test_integration_instructions" {
  command = plan

  assert {
    condition = alltrue([
      contains(keys(output.integration_instructions), "step_1"),
      contains(keys(output.integration_instructions), "step_2"),
      contains(keys(output.integration_instructions), "step_3"),
      contains(keys(output.integration_instructions), "step_4"),
      contains(keys(output.integration_instructions), "step_5"),
      contains(keys(output.integration_instructions), "step_6")
    ])
    error_message = "Integration instructions should have all 6 steps"
  }
}
