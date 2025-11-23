# ==============================================================================
# AWS Config Monitoring Module - Validation Tests
# ==============================================================================

variables {
  project_name  = "validation-config"
  environment   = "validation"
  enable_config = true
  tags          = { Environment = "validation" }
}

run "validate_outputs" {
  command = plan
  assert {
    condition     = output.config_recorder_id != null
    error_message = "Config recorder ID should not be null"
  }
  assert {
    condition     = output.s3_bucket_name != null
    error_message = "S3 bucket name should not be null"
  }
}
