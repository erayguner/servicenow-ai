# ==============================================================================
# Security WAF Module - Validation Tests
# ==============================================================================

variables {
  project_name = "validation-waf"
  environment  = "validation"
  scope = "REGIONAL"
  tags = { Environment = "validation" }
}

run "validate_outputs" {
  command = plan
  assert {
    condition     = output.web_acl_id != null
    error_message = "Web ACL ID should not be null"
  }
  assert {
    condition     = output.web_acl_arn != null
    error_message = "Web ACL ARN should not be null"
  }
  assert {
    condition     = can(regex("^arn:aws:wafv2:", output.web_acl_arn))
    error_message = "Web ACL ARN should be valid"
  }
}
