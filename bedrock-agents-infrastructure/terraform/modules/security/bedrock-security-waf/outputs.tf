# ==============================================================================
# Bedrock Security WAF Module - Outputs
# ==============================================================================

# ==============================================================================
# WAF Web ACL
# ==============================================================================

output "web_acl_id" {
  description = "ID of the WAF Web ACL"
  value       = aws_wafv2_web_acl.main.id
}

output "web_acl_arn" {
  description = "ARN of the WAF Web ACL"
  value       = aws_wafv2_web_acl.main.arn
}

output "web_acl_name" {
  description = "Name of the WAF Web ACL"
  value       = aws_wafv2_web_acl.main.name
}

output "web_acl_capacity" {
  description = "Web ACL capacity units used"
  value       = aws_wafv2_web_acl.main.capacity
}

# ==============================================================================
# IP Sets
# ==============================================================================

output "whitelist_ip_set_arn" {
  description = "ARN of the whitelist IP set"
  value       = length(var.allowed_ip_addresses) > 0 ? aws_wafv2_ip_set.whitelist[0].arn : null
}

output "blacklist_ip_set_arn" {
  description = "ARN of the blacklist IP set"
  value       = length(var.blocked_ip_addresses) > 0 ? aws_wafv2_ip_set.blacklist[0].arn : null
}

output "whitelist_ip_set_id" {
  description = "ID of the whitelist IP set"
  value       = length(var.allowed_ip_addresses) > 0 ? aws_wafv2_ip_set.whitelist[0].id : null
}

output "blacklist_ip_set_id" {
  description = "ID of the blacklist IP set"
  value       = length(var.blocked_ip_addresses) > 0 ? aws_wafv2_ip_set.blacklist[0].id : null
}

# ==============================================================================
# WAF Association
# ==============================================================================

output "api_gateway_association_id" {
  description = "ID of the API Gateway WAF association"
  value       = var.api_gateway_arn != "" ? aws_wafv2_web_acl_association.api_gateway[0].id : null
}

# ==============================================================================
# Logging
# ==============================================================================

output "waf_log_group_name" {
  description = "Name of the WAF CloudWatch log group"
  value       = var.enable_waf_logging ? aws_cloudwatch_log_group.waf_logs[0].name : null
}

output "waf_log_group_arn" {
  description = "ARN of the WAF CloudWatch log group"
  value       = var.enable_waf_logging ? aws_cloudwatch_log_group.waf_logs[0].arn : null
}

# ==============================================================================
# CloudWatch Alarms
# ==============================================================================

output "blocked_requests_alarm_arn" {
  description = "ARN of the blocked requests CloudWatch alarm"
  value       = aws_cloudwatch_metric_alarm.blocked_requests.arn
}

output "rate_limit_alarm_arn" {
  description = "ARN of the rate limit exceeded CloudWatch alarm"
  value       = aws_cloudwatch_metric_alarm.rate_limit_exceeded.arn
}

output "sql_injection_alarm_arn" {
  description = "ARN of the SQL injection attempts CloudWatch alarm"
  value       = aws_cloudwatch_metric_alarm.sql_injection_attempts.arn
}

# ==============================================================================
# EventBridge Rule
# ==============================================================================

output "waf_blocked_requests_rule_arn" {
  description = "ARN of the WAF blocked requests EventBridge rule"
  value       = aws_cloudwatch_event_rule.waf_blocked_requests.arn
}

# ==============================================================================
# Configuration Details
# ==============================================================================

output "waf_scope" {
  description = "Scope of the WAF (REGIONAL or CLOUDFRONT)"
  value       = var.waf_scope
}

output "rate_limit" {
  description = "Configured rate limit per 5 minutes"
  value       = var.rate_limit
}

output "blocked_countries" {
  description = "List of blocked country codes"
  value       = var.blocked_countries
}

output "anonymous_ip_blocking_enabled" {
  description = "Whether anonymous IP blocking is enabled"
  value       = var.enable_anonymous_ip_list
}

output "waf_logging_enabled" {
  description = "Whether WAF logging is enabled"
  value       = var.enable_waf_logging
}

# ==============================================================================
# Protection Features
# ==============================================================================

output "enabled_protection_features" {
  description = "Map of enabled WAF protection features"
  value = {
    rate_limiting         = true
    sql_injection         = true
    xss_protection        = true
    ip_reputation         = true
    known_bad_inputs      = true
    anonymous_ip_blocking = var.enable_anonymous_ip_list
    geo_blocking          = length(var.blocked_countries) > 0
    ip_whitelist          = length(var.allowed_ip_addresses) > 0
    ip_blacklist          = length(var.blocked_ip_addresses) > 0
    api_key_validation    = var.require_api_key_header
  }
}

# ==============================================================================
# Module Information
# ==============================================================================

output "module_version" {
  description = "Version of the bedrock-security-waf module"
  value       = "1.0.0"
}
