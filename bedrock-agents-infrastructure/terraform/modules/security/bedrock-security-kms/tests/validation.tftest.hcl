# ==============================================================================
# Security KMS Module - Validation Tests
# ==============================================================================

variables {
  project_name = "validation-kms"
  environment  = "validation"
  enable_key_rotation = true
  tags = { Environment = "validation" }
}

run "validate_outputs" {
  command = plan
  assert {
    condition     = output.kms_key_id != null
    error_message = "KMS key ID output should not be null"
  }
  assert {
    condition     = output.kms_key_arn != null
    error_message = "KMS key ARN output should not be null"
  }
  assert {
    condition     = can(regex("^arn:aws:kms:", output.kms_key_arn))
    error_message = "KMS key ARN should be valid"
  }
}
