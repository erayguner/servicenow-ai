# ==============================================================================
# Security WAF Module - Basic Tests
# ==============================================================================

variables {
  project_name = "test-waf"
  environment  = "test"
  scope        = "REGIONAL"
  tags         = { Environment = "test" }
}

run "verify_waf_web_acl" {
  command = plan
  assert {
    condition     = aws_wafv2_web_acl.bedrock.name != null
    error_message = "WAF WebACL should be created"
  }
  assert {
    condition     = aws_wafv2_web_acl.bedrock.scope == "REGIONAL"
    error_message = "WAF scope should match input"
  }
}

run "verify_managed_rules" {
  command = plan
  assert {
    condition     = can(aws_wafv2_web_acl.bedrock.rule)
    error_message = "WAF should include managed rules"
  }
}

run "verify_rate_limiting" {
  command = plan
  assert {
    condition     = can(regex("RateLimitRule", jsonencode(aws_wafv2_web_acl.bedrock.rule)))
    error_message = "Should include rate limiting rule"
  }
}
