# ==============================================================================
# Security KMS Module - Advanced Tests
# ==============================================================================

variables {
  project_name            = "advanced-kms"
  environment             = "prod"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  multi_region            = true
  tags                    = { Environment = "prod", Critical = "true" }
}

run "verify_multi_region_key" {
  command = plan
  assert {
    condition     = aws_kms_key.bedrock.multi_region == true
    error_message = "Should create multi-region key when enabled"
  }
}

run "verify_deletion_window" {
  command = plan
  assert {
    condition     = aws_kms_key.bedrock.deletion_window_in_days == 7
    error_message = "Deletion window should match configuration"
  }
}
