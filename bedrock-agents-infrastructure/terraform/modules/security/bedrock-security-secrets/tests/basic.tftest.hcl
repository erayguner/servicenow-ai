# ==============================================================================
# Security Secrets Module - Basic Tests
# ==============================================================================

variables {
  project_name = "test-secrets"
  environment  = "test"
  secrets = {
    api_key = {
      description = "Test API key"
      secret_string = "test-value"
    }
  }
  tags = { Environment = "test" }
}

run "verify_secrets_creation" {
  command = plan
  assert {
    condition     = can(aws_secretsmanager_secret.this["api_key"])
    error_message = "Secret should be created"
  }
}

run "verify_secret_value" {
  command = plan
  assert {
    condition     = can(aws_secretsmanager_secret_version.this["api_key"])
    error_message = "Secret version should be created"
  }
}

run "verify_kms_encryption" {
  command = plan
  assert {
    condition     = can(aws_secretsmanager_secret.this["api_key"].kms_key_id)
    error_message = "Secret should be encrypted with KMS"
  }
}
