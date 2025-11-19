output "agent_id" {
  description = "The ID of the Bedrock agent"
  value       = aws_bedrockagent_agent.this.id
}

output "agent_arn" {
  description = "The ARN of the Bedrock agent"
  value       = aws_bedrockagent_agent.this.agent_arn
}

output "agent_name" {
  description = "The name of the Bedrock agent"
  value       = aws_bedrockagent_agent.this.agent_name
}

output "agent_version" {
  description = "The version of the Bedrock agent"
  value       = aws_bedrockagent_agent.this.agent_version
}

output "agent_role_arn" {
  description = "The ARN of the IAM role for the Bedrock agent"
  value       = aws_iam_role.agent.arn
}

output "agent_role_name" {
  description = "The name of the IAM role for the Bedrock agent"
  value       = aws_iam_role.agent.name
}

output "agent_aliases" {
  description = "Map of agent alias names to their ARNs"
  value = {
    for k, v in aws_bedrockagent_agent_alias.this : k => {
      id              = v.id
      agent_alias_arn = v.agent_alias_arn
      agent_alias_id  = v.agent_alias_id
    }
  }
}

output "knowledge_base_associations" {
  description = "Map of knowledge base associations"
  value = {
    for k, v in aws_bedrockagent_agent_knowledge_base_association.this : k => {
      id                = v.id
      knowledge_base_id = v.knowledge_base_id
      state             = v.knowledge_base_state
    }
  }
}

output "action_groups" {
  description = "Map of action groups"
  value = {
    for k, v in aws_bedrockagent_agent_action_group.this : k => {
      id                = v.id
      action_group_id   = v.action_group_id
      action_group_name = v.action_group_name
      state             = v.action_group_state
    }
  }
}

output "log_group_name" {
  description = "The name of the CloudWatch log group for the agent"
  value       = aws_cloudwatch_log_group.agent.name
}

output "log_group_arn" {
  description = "The ARN of the CloudWatch log group for the agent"
  value       = aws_cloudwatch_log_group.agent.arn
}
