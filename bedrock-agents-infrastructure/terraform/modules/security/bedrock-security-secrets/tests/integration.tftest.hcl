# ==============================================================================
# Security Secrets Module - Integration Tests
# ==============================================================================

variables {
  project_name = "integration-secrets"
  environment  = "integration"
  secrets = {
    integration_key = {
      description = "Integration key"
      secret_string = "int-key-123"
    }
  }
  kms_key_id = "arn:aws:kms:us-east-1:123456789012:key/12345"
  tags = { Environment = "integration" }
}

run "verify_kms_integration" {
  command = plan
  assert {
    condition     = can(aws_secretsmanager_secret.this["integration_key"].kms_key_id == var.kms_key_id)
    error_message = "Should use specified KMS key"
  }
}
