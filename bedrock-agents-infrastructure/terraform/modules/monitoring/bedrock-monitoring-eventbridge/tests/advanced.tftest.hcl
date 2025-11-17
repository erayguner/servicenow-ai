# ==============================================================================
# EventBridge Monitoring Module - Advanced Tests
# ==============================================================================

variables {
  project_name = "advanced-eventbridge"
  environment  = "prod"
  create_event_bus = true
  enable_archive = true
  archive_retention_days = 90
  enable_cross_account_access = true
  allowed_account_ids = ["123456789012"]
  tags = { Environment = "prod" }
}

run "verify_archive_retention" {
  command = plan
  assert {
    condition     = aws_cloudwatch_event_archive.bedrock.retention_days == 90
    error_message = "Archive retention should match configuration"
  }
}

run "verify_cross_account_permissions" {
  command = plan
  assert {
    condition     = can(aws_cloudwatch_event_bus_policy.cross_account)
    error_message = "Cross-account event bus policy should be created"
  }
}

run "verify_dlq_configuration" {
  command = plan
  assert {
    condition     = can(aws_cloudwatch_event_target.bedrock_sns.dead_letter_config)
    error_message = "Dead letter queue should be configured"
  }
}
