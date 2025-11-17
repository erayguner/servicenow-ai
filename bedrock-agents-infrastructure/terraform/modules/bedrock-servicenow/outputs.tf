# Outputs for ServiceNow integration module

# Agent Outputs
output "bedrock_agents" {
  description = "Details of all created Bedrock agents"
  value = {
    for key, agent in module.bedrock_agents : key => {
      agent_id      = agent.agent_id
      agent_arn     = agent.agent_arn
      agent_name    = agent.agent_name
      agent_version = agent.agent_version
      aliases       = agent.agent_aliases
    }
  }
}

output "incident_agent_id" {
  description = "ID of the incident management agent"
  value       = try(module.bedrock_agents["incident"].agent_id, null)
}

output "triage_agent_id" {
  description = "ID of the ticket triage agent"
  value       = try(module.bedrock_agents["triage"].agent_id, null)
}

output "change_agent_id" {
  description = "ID of the change management agent"
  value       = try(module.bedrock_agents["change"].agent_id, null)
}

output "problem_agent_id" {
  description = "ID of the problem management agent"
  value       = try(module.bedrock_agents["problem"].agent_id, null)
}

output "knowledge_agent_id" {
  description = "ID of the knowledge base agent"
  value       = try(module.bedrock_agents["knowledge"].agent_id, null)
}

output "sla_agent_id" {
  description = "ID of the SLA monitoring agent"
  value       = try(module.bedrock_agents["sla"].agent_id, null)
}

# Lambda Outputs
output "integration_lambda_arn" {
  description = "ARN of the ServiceNow integration Lambda function"
  value       = aws_lambda_function.servicenow_integration.arn
}

output "integration_lambda_name" {
  description = "Name of the ServiceNow integration Lambda function"
  value       = aws_lambda_function.servicenow_integration.function_name
}

output "webhook_processor_lambda_arn" {
  description = "ARN of the webhook processor Lambda function"
  value       = aws_lambda_function.webhook_processor.arn
}

output "webhook_processor_lambda_name" {
  description = "Name of the webhook processor Lambda function"
  value       = aws_lambda_function.webhook_processor.function_name
}

output "knowledge_sync_lambda_arn" {
  description = "ARN of the knowledge sync Lambda function"
  value       = var.enable_knowledge_sync ? aws_lambda_function.knowledge_sync[0].arn : null
}

# API Gateway Outputs
output "api_gateway_id" {
  description = "ID of the API Gateway REST API"
  value       = aws_api_gateway_rest_api.servicenow_webhooks.id
}

output "api_gateway_url" {
  description = "Base URL of the API Gateway"
  value       = aws_api_gateway_stage.servicenow_webhooks.invoke_url
}

output "webhook_endpoints" {
  description = "Webhook endpoint URLs for ServiceNow"
  value = {
    incident = "${aws_api_gateway_stage.servicenow_webhooks.invoke_url}/webhooks/incident"
    change   = "${aws_api_gateway_stage.servicenow_webhooks.invoke_url}/webhooks/change"
    problem  = "${aws_api_gateway_stage.servicenow_webhooks.invoke_url}/webhooks/problem"
  }
}

output "api_key_id" {
  description = "ID of the API Gateway API key"
  value       = aws_api_gateway_api_key.servicenow_webhooks.id
}

output "api_key_value" {
  description = "Value of the API Gateway API key (sensitive)"
  value       = aws_api_gateway_api_key.servicenow_webhooks.value
  sensitive   = true
}

# Step Functions Outputs
output "incident_workflow_arn" {
  description = "ARN of the incident workflow state machine"
  value       = aws_sfn_state_machine.incident_workflow.arn
}

output "incident_workflow_name" {
  description = "Name of the incident workflow state machine"
  value       = aws_sfn_state_machine.incident_workflow.name
}

output "change_workflow_arn" {
  description = "ARN of the change workflow state machine"
  value       = var.enable_change_management ? aws_sfn_state_machine.change_workflow[0].arn : null
}

output "change_workflow_name" {
  description = "Name of the change workflow state machine"
  value       = var.enable_change_management ? aws_sfn_state_machine.change_workflow[0].name : null
}

# EventBridge Outputs
output "event_bus_arn" {
  description = "ARN of the ServiceNow event bus"
  value       = aws_cloudwatch_event_bus.servicenow_events.arn
}

output "event_bus_name" {
  description = "Name of the ServiceNow event bus"
  value       = aws_cloudwatch_event_bus.servicenow_events.name
}

# DynamoDB Outputs
output "state_table_name" {
  description = "Name of the DynamoDB state tracking table"
  value       = aws_dynamodb_table.servicenow_state.name
}

output "state_table_arn" {
  description = "ARN of the DynamoDB state tracking table"
  value       = aws_dynamodb_table.servicenow_state.arn
}

output "state_table_stream_arn" {
  description = "ARN of the DynamoDB stream"
  value       = aws_dynamodb_table.servicenow_state.stream_arn
}

# Secrets Manager Outputs
output "credentials_secret_arn" {
  description = "ARN of the ServiceNow credentials secret"
  value       = local.servicenow_credentials_secret_arn
}

output "credentials_secret_name" {
  description = "Name of the ServiceNow credentials secret"
  value       = var.servicenow_credentials_secret_arn != null ? null : aws_secretsmanager_secret.servicenow_credentials[0].name
}

# IAM Outputs
output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution.arn
}

output "lambda_execution_role_name" {
  description = "Name of the Lambda execution role"
  value       = aws_iam_role.lambda_execution.name
}

output "step_functions_role_arn" {
  description = "ARN of the Step Functions execution role"
  value       = aws_iam_role.step_functions.arn
}

output "step_functions_role_name" {
  description = "Name of the Step Functions execution role"
  value       = aws_iam_role.step_functions.name
}

# SNS Outputs
output "notification_topic_arn" {
  description = "ARN of the SNS notification topic"
  value       = aws_sns_topic.servicenow_notifications.arn
}

output "notification_topic_name" {
  description = "Name of the SNS notification topic"
  value       = aws_sns_topic.servicenow_notifications.name
}

# CloudWatch Outputs
output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = var.enable_enhanced_monitoring ? aws_cloudwatch_dashboard.servicenow_integration[0].dashboard_name : null
}

output "log_groups" {
  description = "Map of CloudWatch log group names"
  value = {
    api_gateway       = aws_cloudwatch_log_group.api_gateway.name
    step_functions    = aws_cloudwatch_log_group.step_functions.name
    lambda_integration = aws_cloudwatch_log_group.lambda_integration.name
    lambda_webhook    = aws_cloudwatch_log_group.lambda_webhook.name
    lambda_knowledge  = var.enable_knowledge_sync ? aws_cloudwatch_log_group.lambda_knowledge_sync[0].name : null
  }
}

# Configuration Summary
output "configuration" {
  description = "Summary of ServiceNow integration configuration"
  value = {
    instance_url                = var.servicenow_instance_url
    auth_type                   = var.servicenow_auth_type
    environment                 = var.environment
    incident_automation_enabled = var.enable_incident_automation
    ticket_triage_enabled       = var.enable_ticket_triage
    change_management_enabled   = var.enable_change_management
    problem_management_enabled  = var.enable_problem_management
    knowledge_sync_enabled      = var.enable_knowledge_sync
    sla_monitoring_enabled      = var.enable_sla_monitoring
    auto_assignment_enabled     = var.auto_assignment_enabled
    auto_assignment_threshold   = var.auto_assignment_confidence_threshold
    sla_breach_threshold        = var.sla_breach_threshold
    enhanced_monitoring_enabled = var.enable_enhanced_monitoring
    agents_deployed             = keys(local.enabled_agents)
  }
}

# Integration Instructions
output "integration_instructions" {
  description = "Instructions for completing ServiceNow integration setup"
  value = {
    step_1 = "Update ServiceNow credentials in Secrets Manager: ${local.servicenow_credentials_secret_arn}"
    step_2 = "Configure ServiceNow webhook endpoints: ${aws_api_gateway_stage.servicenow_webhooks.invoke_url}/webhooks/*"
    step_3 = "Use API Key for webhook authentication: ${aws_api_gateway_api_key.servicenow_webhooks.id}"
    step_4 = "Subscribe to SNS topic for notifications: ${aws_sns_topic.servicenow_notifications.arn}"
    step_5 = "Monitor integration via CloudWatch dashboard: ${var.enable_enhanced_monitoring ? aws_cloudwatch_dashboard.servicenow_integration[0].dashboard_name : "Enable enhanced monitoring to create dashboard"}"
    step_6 = "Test agents using AWS Bedrock console or CLI with agent IDs from 'bedrock_agents' output"
  }
}
