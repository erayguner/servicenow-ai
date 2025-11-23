# ==============================================================================
# Synthetics Monitoring Module - Basic Tests
# ==============================================================================

variables {
  project_name = "test-synthetics"
  environment  = "test"
  canaries = {
    bedrock_api_health = {
      handler             = "apiCanaryBlueprint.handler"
      runtime_version     = "syn-python-selenium-1.0"
      schedule_expression = "rate(5 minutes)"
      endpoint_url        = "https://api.example.com/health"
    }
  }
  tags = { Environment = "test" }
}

run "verify_canary_creation" {
  command = plan
  assert {
    condition     = can(aws_synthetics_canary.this["bedrock_api_health"])
    error_message = "Synthetics canary should be created"
  }
}

run "verify_s3_bucket" {
  command = plan
  assert {
    condition     = aws_s3_bucket.synthetics.bucket != null
    error_message = "S3 bucket for canary artifacts should be created"
  }
}

run "verify_iam_role" {
  command = plan
  assert {
    condition     = aws_iam_role.synthetics.name != null
    error_message = "IAM role for canaries should be created"
  }
}
