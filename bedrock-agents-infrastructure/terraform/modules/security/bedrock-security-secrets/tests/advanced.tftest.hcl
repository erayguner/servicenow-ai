# ==============================================================================
# Security Secrets Module - Advanced Tests
# ==============================================================================

variables {
  project_name = "advanced-secrets"
  environment  = "prod"
  secrets = {
    db_password = {
      description             = "Database password"
      secret_string           = "supersecret"
      recovery_window_in_days = 7
    }
    api_token = {
      description             = "API token"
      secret_string           = "token123"
      recovery_window_in_days = 30
    }
  }
  enable_rotation     = true
  rotation_lambda_arn = "arn:aws:lambda:us-east-1:123456789012:function:rotation"
  tags                = { Environment = "prod" }
}

run "verify_multiple_secrets" {
  command = plan
  assert {
    condition     = length(aws_secretsmanager_secret.this) == 2
    error_message = "Should create two secrets"
  }
}

run "verify_rotation_configuration" {
  command = plan
  assert {
    condition     = can(aws_secretsmanager_secret_rotation.this["db_password"])
    error_message = "Secret rotation should be configured"
  }
}

run "verify_recovery_window" {
  command = plan
  assert {
    condition     = can(aws_secretsmanager_secret.this["db_password"].recovery_window_in_days == 7)
    error_message = "Recovery window should match configuration"
  }
}
