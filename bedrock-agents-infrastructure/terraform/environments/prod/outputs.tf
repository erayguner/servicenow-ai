# Production Environment Outputs

# Primary Region Outputs
output "primary_agent_id" {
  description = "Primary Bedrock agent ID"
  value       = module.bedrock_agent_primary.agent_id
}

output "primary_agent_arn" {
  description = "Primary Bedrock agent ARN"
  value       = module.bedrock_agent_primary.agent_arn
}

output "primary_agent_name" {
  description = "Primary Bedrock agent name"
  value       = module.bedrock_agent_primary.agent_name
}

output "primary_agent_alias_id" {
  description = "Primary Bedrock agent alias ID"
  value       = module.bedrock_agent_primary.agent_alias_id
}

output "primary_knowledge_base_id" {
  description = "Primary knowledge base ID"
  value       = module.bedrock_agent_primary.knowledge_base_id
}

output "primary_agent_endpoint" {
  description = "Primary agent API endpoint"
  value       = module.bedrock_agent_primary.agent_endpoint
}

# Secondary Region Outputs
output "secondary_agent_id" {
  description = "Secondary Bedrock agent ID"
  value       = module.bedrock_agent_secondary.agent_id
}

output "secondary_agent_arn" {
  description = "Secondary Bedrock agent ARN"
  value       = module.bedrock_agent_secondary.agent_arn
}

output "secondary_agent_endpoint" {
  description = "Secondary agent API endpoint"
  value       = module.bedrock_agent_secondary.agent_endpoint
}

# Global Traffic Manager
output "global_endpoint" {
  description = "Global traffic manager endpoint (primary access point)"
  value       = module.global_traffic_manager.endpoint
  sensitive   = false
}

output "global_endpoint_dns" {
  description = "Global DNS name for multi-region access"
  value       = module.global_traffic_manager.dns_name
}

output "failover_status" {
  description = "Failover configuration status"
  value = {
    enabled           = module.global_traffic_manager.failover_enabled
    primary_healthy   = module.global_traffic_manager.primary_health_status
    secondary_healthy = module.global_traffic_manager.secondary_health_status
    active_endpoint   = module.global_traffic_manager.active_endpoint
  }
}

# IAM Roles
output "primary_agent_role_arn" {
  description = "Primary agent IAM role ARN"
  value       = module.bedrock_agent_primary.agent_role_arn
}

output "secondary_agent_role_arn" {
  description = "Secondary agent IAM role ARN"
  value       = module.bedrock_agent_secondary.agent_role_arn
}

# Monitoring
output "cloudwatch_dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${local.project}-${local.environment}-primary"
}

output "xray_console_url" {
  description = "X-Ray console URL"
  value       = "https://console.aws.amazon.com/xray/home?region=${var.aws_region}#/service-map"
}

output "primary_log_group" {
  description = "Primary CloudWatch log group"
  value       = module.bedrock_agent_primary.cloudwatch_log_group
}

output "secondary_log_group" {
  description = "Secondary CloudWatch log group"
  value       = module.bedrock_agent_secondary.cloudwatch_log_group
}

# Synthetic Monitoring
output "synthetic_canary_name" {
  description = "CloudWatch Synthetics canary name"
  value       = module.synthetic_monitoring.canary_name
}

output "synthetic_monitoring_status" {
  description = "Synthetic monitoring status"
  value = {
    canary_name = module.synthetic_monitoring.canary_name
    schedule    = module.synthetic_monitoring.schedule
    endpoints   = module.synthetic_monitoring.monitored_endpoints
  }
}

# Cost Tracking
output "estimated_monthly_cost" {
  description = "Estimated monthly cost for production environment (USD)"
  value       = "~$2,500-4,000 (HA, multi-region, provisioned throughput)"
}

output "cost_breakdown" {
  description = "Detailed cost breakdown by service"
  value = {
    bedrock_agents_primary   = "$800-1200/month (8 instances, provisioned)"
    bedrock_agents_secondary = "$800-1200/month (8 instances, provisioned)"
    opensearch_provisioned   = "$400-600/month (HA cluster)"
    lambda_provisioned       = "$100-150/month (provisioned concurrency)"
    cloudwatch_logs_metrics  = "$80-120/month (90-day retention)"
    xray_tracing             = "$40-60/month"
    s3_storage_replication   = "$50-80/month"
    data_transfer            = "$100-200/month (multi-region)"
    waf_shield               = "$200-300/month (Shield Advanced)"
    synthetics_monitoring    = "$30-50/month"
    backup_storage           = "$50-100/month"
  }
}

# Performance Metrics
output "performance_configuration" {
  description = "Production performance configuration"
  value = {
    provisioned_units          = local.agent_config.provisioned_units
    min_instances              = local.agent_config.min_instances
    max_instances              = local.agent_config.max_instances
    current_instances          = local.agent_config.desired_instances
    auto_scaling_enabled       = true
    cache_enabled              = true
    cache_ttl                  = "1 hour"
    max_concurrent_invocations = local.orchestration_config.max_concurrent_invocations
  }
}

# API Endpoints
output "api_endpoints" {
  description = "Production API endpoints"
  value = {
    global_endpoint          = module.global_traffic_manager.endpoint
    primary_direct           = "https://bedrock-agent-runtime.${var.aws_region}.amazonaws.com"
    secondary_direct         = "https://bedrock-agent-runtime.${var.secondary_region}.amazonaws.com"
    primary_knowledge_base   = "https://bedrock-agent-runtime.${var.aws_region}.amazonaws.com/knowledgebases/${module.bedrock_agent_primary.knowledge_base_id}"
    secondary_knowledge_base = "https://bedrock-agent-runtime.${var.secondary_region}.amazonaws.com/knowledgebases/${module.bedrock_agent_secondary.knowledge_base_id}"
  }
}

# High Availability Configuration
output "high_availability_config" {
  description = "High availability configuration details"
  value = {
    multi_region_enabled  = true
    primary_region        = var.aws_region
    secondary_region      = var.secondary_region
    dr_region             = var.dr_region
    availability_zones    = 3
    automatic_failover    = true
    health_check_interval = "30 seconds"
    rpo_minutes           = var.business_continuity_config.rpo_minutes
    rto_minutes           = var.business_continuity_config.rto_minutes
  }
}

# Security Configuration
output "security_configuration" {
  description = "Security and compliance configuration"
  value = {
    waf_enabled              = var.security_config.enable_waf
    shield_advanced_enabled  = var.security_config.enable_shield_advanced
    encryption_at_rest       = true
    encryption_in_transit    = true
    kms_key_id               = var.kms_key_id
    compliance_frameworks    = var.compliance_config.frameworks
    audit_logging_enabled    = var.compliance_config.enable_audit_logging
    secrets_rotation_enabled = var.security_config.enable_secrets_rotation
  }
}

# Backup Configuration
output "backup_configuration" {
  description = "Backup and recovery configuration"
  value = {
    backup_enabled           = true
    retention_days           = var.backup_config.retention_days
    backup_schedule          = var.backup_config.schedule
    point_in_time_recovery   = var.backup_config.enable_point_in_time_recovery
    cross_region_replication = true
  }
}

# Operational URLs
output "operational_dashboards" {
  description = "Operational dashboard and monitoring URLs"
  value = {
    cloudwatch_dashboard = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${local.project}-${local.environment}-primary"
    xray_service_map     = "https://console.aws.amazon.com/xray/home?region=${var.aws_region}#/service-map"
    cloudwatch_logs      = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#logsV2:log-groups/log-group/${module.bedrock_agent_primary.cloudwatch_log_group}"
    cloudwatch_alarms    = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#alarmsV2:"
    synthetics_canaries  = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#synthetics:canary/list"
  }
}

# Production Usage Guide
output "production_usage_guide" {
  description = "Production usage and operational guide"
  value       = <<-EOT
    Production Environment - Operational Guide
    ==========================================

    PRIMARY ENDPOINT (Always use this):
    ${module.global_traffic_manager.endpoint}

    AGENT INVOCATION:
    aws bedrock-agent-runtime invoke-agent \
      --agent-id ${module.bedrock_agent_primary.agent_id} \
      --agent-alias-id ${module.bedrock_agent_primary.agent_alias_id} \
      --session-id prod-$(uuidgen) \
      --input-text "Your query" \
      --region ${var.aws_region}

    HEALTH CHECK:
    curl ${module.global_traffic_manager.endpoint}/health

    MONITORING:
    - Primary Dashboard: ${module.bedrock_agent_primary.dashboard_url}
    - X-Ray Traces: https://console.aws.amazon.com/xray/home?region=${var.aws_region}
    - Synthetics: https://console.aws.amazon.com/synthetics

    FAILOVER STATUS:
    aws route53 get-health-check-status \
      --health-check-id ${module.global_traffic_manager.health_check_id}

    ALERTS:
    - Critical: ${var.alert_email}
    - PagerDuty: ${var.enable_pagerduty ? "Enabled" : "Disabled"}
    - Slack: ${var.operational_contacts.slack_channel}

    SLA TARGETS:
    - Availability: 99.9%
    - Latency P99: < 2000ms
    - Error Rate: < 5%

    CHANGE WINDOW:
    - Day: ${var.change_window.day_of_week}
    - Time: ${var.change_window.start_hour}:00 UTC
    - Duration: ${var.change_window.duration_hours} hours

    EMERGENCY CONTACTS:
    - Primary On-call: ${var.operational_contacts.primary_oncall}
    - Secondary On-call: ${var.operational_contacts.secondary_oncall}
    - Escalation: ${var.operational_contacts.escalation_email}
  EOT
}

# Resource Tags
output "resource_tags" {
  description = "Common tags applied to all production resources"
  value       = merge(local.common_tags, var.cost_allocation_tags)
}

# Action Groups
output "enabled_action_groups" {
  description = "List of enabled action groups in production"
  value       = local.action_groups.groups
}

# Compliance Status
output "compliance_status" {
  description = "Compliance and regulatory status"
  value = {
    frameworks         = var.compliance_config.frameworks
    audit_logging      = var.compliance_config.enable_audit_logging
    encryption         = var.compliance_config.enable_encryption
    log_retention_days = var.compliance_config.log_retention_days
    waf_enabled        = var.security_config.enable_waf
    shield_advanced    = var.security_config.enable_shield_advanced
    mfa_required       = var.security_config.mfa_required
    secrets_rotation   = var.security_config.enable_secrets_rotation
  }
}

# Disaster Recovery
output "disaster_recovery_status" {
  description = "Disaster recovery configuration and status"
  value = {
    multi_region_enabled     = var.business_continuity_config.enable_multi_region
    automatic_failover       = var.business_continuity_config.enable_automatic_failover
    rpo_minutes              = var.business_continuity_config.rpo_minutes
    rto_minutes              = var.business_continuity_config.rto_minutes
    cross_region_replication = true
    backup_retention_days    = var.backup_config.retention_days
    point_in_time_recovery   = var.backup_config.enable_point_in_time_recovery
  }
}
