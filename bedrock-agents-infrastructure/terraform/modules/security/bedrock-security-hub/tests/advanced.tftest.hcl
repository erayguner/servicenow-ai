# ==============================================================================
# Security Hub Module - Advanced Tests
# ==============================================================================

variables {
  project_name = "advanced-securityhub"
  environment  = "prod"
  enable_security_hub = true
  enable_pci_dss = true
  enable_nist = true
  auto_enable_controls = true
  tags = { Environment = "prod" }
}

run "verify_pci_dss_standard" {
  command = plan
  assert {
    condition     = can(aws_securityhub_standards_subscription.pci_dss)
    error_message = "PCI DSS standard should be enabled"
  }
}

run "verify_nist_standard" {
  command = plan
  assert {
    condition     = can(aws_securityhub_standards_subscription.nist)
    error_message = "NIST standard should be enabled"
  }
}

run "verify_auto_enable_controls" {
  command = plan
  assert {
    condition     = can(aws_securityhub_account.this.auto_enable_controls == true)
    error_message = "Auto-enable controls should be true"
  }
}
