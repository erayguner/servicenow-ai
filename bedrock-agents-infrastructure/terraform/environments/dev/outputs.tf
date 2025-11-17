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

output "cloudwatch_log_stream" {
  description = "CloudWatch log stream name"
  value       = module.bedrock_agent.cloudwatch_log_stream
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
  value = <<-EOT
    Development Environment Testing:

    1. Invoke Agent:
       aws bedrock-agent-runtime invoke-agent \
         --agent-id ${module.bedrock_agent.agent_id} \
         --agent-alias-id ${module.bedrock_agent.agent_alias_id} \
         --session-id test-session-123 \
         --input-text "Your test query" \
         --region ${var.aws_region}

    2. Check Logs:
       aws logs tail ${module.bedrock_agent.cloudwatch_log_group} --follow

    3. Query Knowledge Base:
       aws bedrock-agent-runtime retrieve \
         --knowledge-base-id ${module.bedrock_agent.knowledge_base_id} \
         --retrieval-query text="Your query"
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
