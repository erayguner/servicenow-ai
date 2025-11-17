# ==============================================================================
# CloudTrail Monitoring Module - Integration Tests
# ==============================================================================

variables {
  project_name = "integration-cloudtrail"
  environment  = "integration"
  create_trail = true
  kms_key_id = "arn:aws:kms:us-east-1:123456789012:key/12345"
  sns_topic_arn = "arn:aws:sns:us-east-1:123456789012:cloudtrail-notifications"
  tags = { Environment = "integration" }
}

run "verify_kms_encryption" {
  command = plan
  assert {
    condition     = aws_cloudtrail.bedrock.kms_key_id != null
    error_message = "CloudTrail should use KMS encryption"
  }
}

run "verify_sns_notifications" {
  command = plan
  assert {
    condition     = aws_cloudtrail.bedrock.sns_topic_name != null
    error_message = "SNS notifications should be configured"
  }
}
