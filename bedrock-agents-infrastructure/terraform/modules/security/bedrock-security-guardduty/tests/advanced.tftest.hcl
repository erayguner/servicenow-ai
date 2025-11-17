# ==============================================================================
# Security GuardDuty Module - Advanced Tests
# ==============================================================================

variables {
  project_name = "advanced-guardduty"
  environment  = "prod"
  enable_guardduty = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"
  enable_kubernetes_protection = true
  enable_malware_protection = true
  tags = { Environment = "prod" }
}

run "verify_kubernetes_protection" {
  command = plan
  assert {
    condition     = can(aws_guardduty_detector.this.datasources[0].kubernetes[0].audit_logs[0].enable == true)
    error_message = "Kubernetes audit logs should be enabled"
  }
}

run "verify_malware_protection" {
  command = plan
  assert {
    condition     = can(aws_guardduty_detector.this.datasources[0].malware_protection[0].scan_ec2_instance_with_findings[0].ebs_volumes[0].enable == true)
    error_message = "Malware protection should be enabled"
  }
}
