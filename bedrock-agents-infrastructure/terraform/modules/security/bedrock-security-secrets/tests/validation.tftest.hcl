# ==============================================================================
# Security Secrets Module - Validation Tests
# ==============================================================================

variables {
  project_name = "validation-secrets"
  environment  = "validation"
  secrets = {
    validation_secret = {
      description   = "Validation secret"
      secret_string = "validation"
    }
  }
  tags = { Environment = "validation" }
}

run "validate_outputs" {
  command = plan
  assert {
    condition     = output.secret_arns["validation_secret"] != null
    error_message = "Secret ARN should not be null"
  }
  assert {
    condition     = can(regex("^arn:aws:secretsmanager:", output.secret_arns["validation_secret"]))
    error_message = "Secret ARN should be valid"
  }
}
