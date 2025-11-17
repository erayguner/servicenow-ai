# ==============================================================================
# Security Hub Module - Basic Tests
# ==============================================================================

variables {
  project_name = "test-securityhub"
  environment  = "test"
  enable_security_hub = true
  tags = { Environment = "test" }
}

run "verify_security_hub_account" {
  command = plan
  assert {
    condition     = aws_securityhub_account.this.id != null
    error_message = "Security Hub account should be enabled"
  }
}

run "verify_aws_foundational_security_best_practices" {
  command = plan
  assert {
    condition     = can(aws_securityhub_standards_subscription.aws_foundational_security_best_practices)
    error_message = "Should enable AWS Foundational Security Best Practices"
  }
}

run "verify_cis_standard" {
  command = plan
  assert {
    condition     = can(aws_securityhub_standards_subscription.cis)
    error_message = "Should enable CIS AWS Foundations Benchmark"
  }
}
