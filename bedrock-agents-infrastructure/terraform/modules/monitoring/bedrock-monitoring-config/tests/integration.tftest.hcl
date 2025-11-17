# ==============================================================================
# AWS Config Monitoring Module - Integration Tests
# ==============================================================================

variables {
  project_name  = "integration-config"
  environment   = "integration"
  enable_config = true
  kms_key_id    = "arn:aws:kms:us-east-1:123456789012:key/12345"
  sns_topic_arn = "arn:aws:sns:us-east-1:123456789012:config-notifications"
  tags          = { Environment = "integration" }
}

run "verify_kms_encryption" {
  command = plan
  assert {
    condition     = can(aws_s3_bucket_server_side_encryption_configuration.config.rule[0].apply_server_side_encryption_by_default[0].kms_master_key_id)
    error_message = "S3 bucket should use KMS encryption"
  }
}

run "verify_sns_integration" {
  command = plan
  assert {
    condition     = aws_config_delivery_channel.bedrock.sns_topic_arn == var.sns_topic_arn
    error_message = "Should use specified SNS topic"
  }
}
