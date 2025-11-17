# ==============================================================================
# X-Ray Monitoring Module - Basic Tests
# ==============================================================================

variables {
  project_name = "test-xray"
  environment  = "test"
  enable_xray = true
  tags = { Environment = "test" }
}

run "verify_xray_group" {
  command = plan
  assert {
    condition     = aws_xray_group.bedrock.group_name != null
    error_message = "X-Ray group should be created"
  }
}

run "verify_sampling_rule" {
  command = plan
  assert {
    condition     = aws_xray_sampling_rule.bedrock.rule_name != null
    error_message = "X-Ray sampling rule should be created"
  }
}

run "verify_encryption" {
  command = plan
  assert {
    condition     = can(aws_xray_encryption_config.bedrock.type)
    error_message = "X-Ray encryption should be configured"
  }
}
