# ==============================================================================
# X-Ray Monitoring Module - Advanced Tests
# ==============================================================================

variables {
  project_name = "advanced-xray"
  environment  = "prod"
  enable_xray = true
  sampling_rate = 0.1
  enable_insights = true
  enable_insights_notifications = true
  kms_key_id = "arn:aws:kms:us-east-1:123456789012:key/12345"
  tags = { Environment = "prod" }
}

run "verify_sampling_rate" {
  command = plan
  assert {
    condition     = aws_xray_sampling_rule.bedrock.fixed_rate == 0.1
    error_message = "Sampling rate should match configuration"
  }
}

run "verify_insights" {
  command = plan
  assert {
    condition     = can(aws_xray_group.bedrock.insights_configuration[0].insights_enabled == true)
    error_message = "X-Ray Insights should be enabled"
  }

  assert {
    condition     = can(aws_xray_group.bedrock.insights_configuration[0].notifications_enabled == true)
    error_message = "Insights notifications should be enabled"
  }
}

run "verify_kms_encryption" {
  command = plan
  assert {
    condition     = aws_xray_encryption_config.bedrock.type == "KMS"
    error_message = "Should use KMS encryption"
  }

  assert {
    condition     = aws_xray_encryption_config.bedrock.key_id == var.kms_key_id
    error_message = "Should use specified KMS key"
  }
}
