# ==============================================================================
# AWS Config Monitoring Module - Basic Tests
# ==============================================================================

variables {
  project_name = "test-config"
  environment  = "test"
  enable_config = true
  tags = { Environment = "test" }
}

run "verify_config_recorder" {
  command = plan
  assert {
    condition     = aws_config_configuration_recorder.bedrock.name != null
    error_message = "Config recorder should be created"
  }
}

run "verify_delivery_channel" {
  command = plan
  assert {
    condition     = aws_config_delivery_channel.bedrock.name != null
    error_message = "Delivery channel should be created"
  }
}

run "verify_s3_bucket" {
  command = plan
  assert {
    condition     = aws_s3_bucket.config.bucket != null
    error_message = "S3 bucket for Config should be created"
  }
}

run "verify_iam_role" {
  command = plan
  assert {
    condition     = aws_iam_role.config.name != null
    error_message = "IAM role for Config should be created"
  }
}
