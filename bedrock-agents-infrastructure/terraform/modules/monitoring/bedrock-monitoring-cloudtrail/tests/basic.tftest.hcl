# ==============================================================================
# CloudTrail Monitoring Module - Basic Tests
# ==============================================================================

variables {
  project_name = "test-cloudtrail"
  environment  = "test"
  create_trail = true
  tags = { Environment = "test" }
}

run "verify_cloudtrail_creation" {
  command = plan
  assert {
    condition     = aws_cloudtrail.bedrock.name != null
    error_message = "CloudTrail should be created"
  }
  assert {
    condition     = aws_cloudtrail.bedrock.enable_logging == true
    error_message = "CloudTrail logging should be enabled"
  }
}

run "verify_s3_bucket" {
  command = plan
  assert {
    condition     = aws_s3_bucket.cloudtrail_logs.bucket != null
    error_message = "S3 bucket for CloudTrail logs should be created"
  }
}

run "verify_log_file_validation" {
  command = plan
  assert {
    condition     = aws_cloudtrail.bedrock.enable_log_file_validation == true
    error_message = "Log file validation should be enabled"
  }
}
