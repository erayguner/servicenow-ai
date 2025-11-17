# ==============================================================================
# CloudTrail Monitoring Module - Advanced Tests
# ==============================================================================

variables {
  project_name = "advanced-cloudtrail"
  environment  = "prod"
  create_trail = true
  enable_cloudwatch_logs = true
  enable_s3_data_events = true
  enable_lambda_data_events = true
  is_multi_region_trail = true
  is_organization_trail = true
  tags = { Environment = "prod" }
}

run "verify_multi_region_trail" {
  command = plan
  assert {
    condition     = aws_cloudtrail.bedrock.is_multi_region_trail == true
    error_message = "Should be multi-region trail"
  }
}

run "verify_organization_trail" {
  command = plan
  assert {
    condition     = aws_cloudtrail.bedrock.is_organization_trail == true
    error_message = "Should be organization trail"
  }
}

run "verify_cloudwatch_logs_integration" {
  command = plan
  assert {
    condition     = aws_cloudtrail.bedrock.cloud_watch_logs_group_arn != null
    error_message = "CloudWatch Logs integration should be configured"
  }
}

run "verify_data_events" {
  command = plan
  assert {
    condition     = can(aws_cloudtrail.bedrock.event_selector)
    error_message = "Data events should be configured"
  }
}
