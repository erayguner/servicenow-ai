# Development Environment Outputs

output "agent_id" {
  description = "Bedrock agent ID for development environment"
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

output "agent_version" {
  description = "Bedrock agent version"
  value       = module.bedrock_agent.agent_version
}

output "agent_aliases" {
  description = "Bedrock agent aliases"
  value       = module.bedrock_agent.agent_aliases
}

output "agent_alias_id" {
  description = "Bedrock agent 'live' alias ID"
  value       = try(module.bedrock_agent.agent_aliases["live"].agent_alias_id, null)
}

output "agent_alias_arn" {
  description = "Bedrock agent 'live' alias ARN"
  value       = try(module.bedrock_agent.agent_aliases["live"].agent_alias_arn, null)
}

output "knowledge_base_associations" {
  description = "Knowledge base associations"
  value       = module.bedrock_agent.knowledge_base_associations
}

output "agent_role_arn" {
  description = "IAM role ARN for the Bedrock agent"
  value       = module.bedrock_agent.agent_role_arn
}

output "agent_role_name" {
  description = "IAM role name for the Bedrock agent"
  value       = module.bedrock_agent.agent_role_name
}

output "log_group_name" {
  description = "CloudWatch log group name"
  value       = module.bedrock_agent.log_group_name
}

output "log_group_arn" {
  description = "CloudWatch log group ARN"
  value       = module.bedrock_agent.log_group_arn
}

# Cost tracking outputs
output "estimated_monthly_cost" {
  description = "Estimated monthly cost for dev environment (USD)"
  value       = "~$50-100 (single instance, on-demand, auto-shutdown)"
}

output "cost_optimization_enabled" {
  description = "Cost optimization features enabled"
  value = {
    auto_shutdown     = true
    on_demand_pricing = true
    minimal_logging   = true
    no_provisioned    = true
  }
}

# Development-specific outputs
output "api_endpoint" {
  description = "API endpoint for testing"
  value       = "https://bedrock-agent-runtime.${var.aws_region}.amazonaws.com"
}

output "testing_guide" {
  description = "Quick testing guide"
  value       = <<-EOT
    Development Environment Testing:

    1. Invoke Agent:
       aws bedrock-agent-runtime invoke-agent \
         --agent-id ${module.bedrock_agent.agent_id} \
         --agent-alias-id ${try(module.bedrock_agent.agent_aliases["live"].agent_alias_id, "ALIAS_ID")} \
         --session-id test-session-123 \
         --input-text "Your test query" \
         --region ${var.aws_region}

    2. Check Logs:
       aws logs tail ${module.bedrock_agent.log_group_name} --follow

    3. Monitor Agent:
       aws bedrock-agent get-agent \
         --agent-id ${module.bedrock_agent.agent_id}
  EOT
}

output "resource_tags" {
  description = "Common tags applied to all resources"
  value = {
    Environment    = "dev"
    Project        = "servicenow-ai"
    ManagedBy      = "terraform"
    CostCenter     = "development"
    AutoShutdown   = "true"
    BackupRequired = "false"
  }
}
