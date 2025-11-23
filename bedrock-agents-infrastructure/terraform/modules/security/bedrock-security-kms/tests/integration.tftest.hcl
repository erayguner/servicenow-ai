# ==============================================================================
# Security KMS Module - Integration Tests
# ==============================================================================

variables {
  project_name        = "integration-kms"
  environment         = "integration"
  enable_key_rotation = true
  principal_arns      = ["arn:aws:iam::123456789012:role/test-role"]
  tags                = { Environment = "integration" }
}

run "verify_principal_permissions" {
  command = plan
  assert {
    condition     = can(regex("arn:aws:iam::123456789012:role/test-role", data.aws_iam_policy_document.kms_key_policy.json))
    error_message = "Key policy should grant permissions to specified principals"
  }
}
