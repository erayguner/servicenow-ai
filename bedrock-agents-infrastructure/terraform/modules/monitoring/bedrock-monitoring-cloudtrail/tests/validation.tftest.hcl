# ==============================================================================
# CloudTrail Monitoring Module - Validation Tests
# ==============================================================================

variables {
  project_name = "validation-cloudtrail"
  environment  = "validation"
  create_trail = true
  tags         = { Environment = "validation" }
}

run "validate_outputs" {
  command = plan
  assert {
    condition     = output.cloudtrail_id != null
    error_message = "CloudTrail ID should not be null"
  }
  assert {
    condition     = output.cloudtrail_arn != null
    error_message = "CloudTrail ARN should not be null"
  }
  assert {
    condition     = output.s3_bucket_name != null
    error_message = "S3 bucket name should not be null"
  }
}
