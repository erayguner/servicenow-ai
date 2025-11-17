# Staging Environment Outputs

output "agent_id" {
  description = "Bedrock agent ID for staging environment"
  value       = module.bedrock_agent.agent_id
}

output "agent_arn" {
  description = "Bedrock agent ARN"
  value       = module.bedrock_agent.agent_arn
}

output "agent_name" {
  description = "Bedrock agent name"
  value       = module.bedrock_agent.agent_name
}

output "agent_alias_id" {
  description = "Bedrock agent alias ID"
  value       = module.bedrock_agent.agent_alias_id
}

output "agent_alias_arn" {
  description = "Bedrock agent alias ARN"
  value       = module.bedrock_agent.agent_alias_arn
}

output "knowledge_base_id" {
  description = "Knowledge base ID"
  value       = module.bedrock_agent.knowledge_base_id
}

output "knowledge_base_arn" {
  description = "Knowledge base ARN"
  value       = module.bedrock_agent.knowledge_base_arn
}

output "data_source_id" {
  description = "Data source ID"
  value       = module.bedrock_agent.data_source_id
}

output "agent_role_arn" {
  description = "IAM role ARN for the Bedrock agent"
  value       = module.bedrock_agent.agent_role_arn
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group name"
  value       = module.bedrock_agent.cloudwatch_log_group
}

output "xray_trace_group" {
  description = "X-Ray trace group name"
  value       = module.bedrock_agent.xray_trace_group
}

# Orchestration outputs
output "orchestrator_endpoint" {
  description = "Agent orchestrator API endpoint"
  value       = module.agent_orchestrator.api_endpoint
}

output "orchestrator_status" {
  description = "Orchestrator configuration status"
  value = {
    max_agents      = module.agent_orchestrator.max_agents
    auto_scaling    = module.agent_orchestrator.auto_scaling_enabled
    current_agents  = module.agent_orchestrator.current_agent_count
  }
}

# Testing outputs
output "load_testing_endpoint" {
  description = "Load testing endpoint"
  value       = "https://bedrock-agent-runtime.${var.aws_region}.amazonaws.com/agents/${module.bedrock_agent.agent_id}/aliases/${module.bedrock_agent.agent_alias_id}"
}

output "testing_configuration" {
  description = "Testing configuration details"
  value = {
    load_testing_enabled     = var.enable_load_testing
    chaos_testing_enabled    = var.enable_chaos_testing
    ab_testing_enabled       = var.enable_ab_testing
    synthetic_monitoring     = var.enable_synthetic_monitoring
  }
}

# Cost tracking outputs
output "estimated_monthly_cost" {
  description = "Estimated monthly cost for staging environment (USD)"
  value       = "~$300-500 (3 instances, enhanced monitoring, testing tools)"
}

output "cost_breakdown" {
  description = "Cost breakdown by service"
  value = {
    bedrock_agents        = "$150-250/month (3 instances)"
    opensearch_serverless = "$80-120/month"
    lambda_executions     = "$20-40/month"
    cloudwatch_logs       = "$20-30/month"
    xray_tracing          = "$10-20/month"
    s3_storage            = "$10-15/month"
    data_transfer         = "$10-25/month"
  }
}

# Monitoring outputs
output "monitoring_dashboards" {
  description = "CloudWatch dashboard URLs"
  value = {
    agent_performance = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${local.project}-agent-${local.environment}"
    xray_traces      = "https://console.aws.amazon.com/xray/home?region=${var.aws_region}#/traces"
    logs             = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#logsV2:log-groups/log-group/${module.bedrock_agent.cloudwatch_log_group}"
  }
}

# API endpoints
output "api_endpoints" {
  description = "API endpoints for testing"
  value = {
    agent_runtime     = "https://bedrock-agent-runtime.${var.aws_region}.amazonaws.com"
    knowledge_base    = "https://bedrock-agent-runtime.${var.aws_region}.amazonaws.com/knowledgebases/${module.bedrock_agent.knowledge_base_id}"
    orchestrator      = module.agent_orchestrator.api_endpoint
  }
}

output "testing_guide" {
  description = "Staging testing guide"
  value = <<-EOT
    Staging Environment Testing Guide:

    1. Functional Testing:
       aws bedrock-agent-runtime invoke-agent \
         --agent-id ${module.bedrock_agent.agent_id} \
         --agent-alias-id ${module.bedrock_agent.agent_alias_id} \
         --session-id staging-test-$(date +%s) \
         --input-text "Your test query" \
         --region ${var.aws_region}

    2. Load Testing:
       artillery run load-test.yml \
         --target ${module.agent_orchestrator.api_endpoint}

    3. Monitor Performance:
       aws cloudwatch get-metric-statistics \
         --namespace AWS/Bedrock \
         --metric-name Invocations \
         --dimensions Name=AgentId,Value=${module.bedrock_agent.agent_id}

    4. View X-Ray Traces:
       aws xray get-trace-summaries \
         --start-time $(date -u -d '1 hour ago' +%s) \
         --end-time $(date +%s)

    5. Check Orchestration:
       curl ${module.agent_orchestrator.api_endpoint}/status
  EOT
}

output "resource_tags" {
  description = "Common tags applied to all resources"
  value = {
    Environment        = "staging"
    Project            = "servicenow-ai"
    ManagedBy          = "terraform"
    CostCenter         = "qa-testing"
    BackupRequired     = "true"
    Compliance         = "sox-compliant"
    DataClassification = "confidential"
  }
}

# Action groups
output "enabled_action_groups" {
  description = "List of enabled action groups"
  value       = local.action_groups.groups
}

# Compliance outputs
output "compliance_status" {
  description = "Compliance and security configuration"
  value = {
    audit_logging_enabled = var.enable_audit_logging
    compliance_framework  = var.compliance_framework
    backup_enabled        = true
    encryption_enabled    = true
    xray_tracing          = true
  }
}
