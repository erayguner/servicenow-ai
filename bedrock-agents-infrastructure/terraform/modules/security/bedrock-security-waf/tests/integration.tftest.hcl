# ==============================================================================
# Security WAF Module - Integration Tests
# ==============================================================================

variables {
  project_name      = "integration-waf"
  environment       = "integration"
  scope             = "REGIONAL"
  associate_alb_arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/test-alb/abc123"
  tags              = { Environment = "integration" }
}

run "verify_alb_association" {
  command = plan
  assert {
    condition     = can(aws_wafv2_web_acl_association.alb)
    error_message = "WAF should be associated with ALB"
  }
}
