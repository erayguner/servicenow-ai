# ==============================================================================
# Security KMS Module - Basic Tests
# ==============================================================================

variables {
  project_name            = "test-kms"
  environment             = "test"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  tags                    = { Environment = "test" }
}

run "verify_kms_key_creation" {
  command = plan
  assert {
    condition     = aws_kms_key.bedrock.description != null
    error_message = "KMS key should be created with description"
  }
  assert {
    condition     = aws_kms_key.bedrock.enable_key_rotation == true
    error_message = "Key rotation should be enabled"
  }
}

run "verify_kms_alias" {
  command = plan
  assert {
    condition     = can(regex("alias/test-kms", aws_kms_alias.bedrock.name))
    error_message = "KMS alias should be created"
  }
}

run "verify_key_policy" {
  command = plan
  assert {
    condition     = can(regex("kms:Encrypt", data.aws_iam_policy_document.kms_key_policy.json))
    error_message = "Key policy should include encrypt permissions"
  }
}
