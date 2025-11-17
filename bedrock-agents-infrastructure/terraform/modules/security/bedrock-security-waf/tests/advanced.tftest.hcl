# ==============================================================================
# Security WAF Module - Advanced Tests
# ==============================================================================

variables {
  project_name = "advanced-waf"
  environment  = "prod"
  scope = "REGIONAL"
  rate_limit = 1000
  enable_logging = true
  enable_bot_control = true
  tags = { Environment = "prod" }
}

run "verify_rate_limit_configuration" {
  command = plan
  assert {
    condition     = can(regex("1000", jsonencode(aws_wafv2_web_acl.bedrock.rule)))
    error_message = "Rate limit should match configuration"
  }
}

run "verify_bot_control" {
  command = plan
  assert {
    condition     = can(regex("AWSManagedRulesBotControlRuleSet", jsonencode(aws_wafv2_web_acl.bedrock.rule)))
    error_message = "Bot control rule set should be enabled"
  }
}

run "verify_logging_configuration" {
  command = plan
  assert {
    condition     = can(aws_wafv2_web_acl_logging_configuration.bedrock)
    error_message = "WAF logging should be configured"
  }
}
