# ==============================================================================
# Bedrock Action Group Module - Integration Tests
# ==============================================================================
# Tests integration with existing Lambda functions and API schema files
# ==============================================================================

variables {
  lambda_function_name   = "integration-test"
  create_lambda_function = false
  existing_lambda_arn    = "arn:aws:lambda:us-east-1:123456789012:function:existing-function"

  api_schema = jsonencode({
    openapi = "3.0.0"
    info = {
      title   = "Integration Test API"
      version = "1.0.0"
    }
    paths = {
      "/test" = {
        get = {
          description = "Test endpoint"
        }
      }
    }
  })

  tags = {
    Environment = "integration-test"
  }
}

run "verify_existing_lambda_usage" {
  command = plan

  assert {
    condition     = length(aws_lambda_function.this) == 0
    error_message = "Should not create Lambda when using existing"
  }

  assert {
    condition     = local.lambda_arn == "arn:aws:lambda:us-east-1:123456789012:function:existing-function"
    error_message = "Should use existing Lambda ARN"
  }
}

run "verify_no_iam_role_creation" {
  command = plan

  assert {
    condition     = length(aws_iam_role.lambda) == 0
    error_message = "Should not create IAM role when using existing Lambda"
  }
}

run "verify_no_log_group_creation" {
  command = plan

  assert {
    condition     = length(aws_cloudwatch_log_group.lambda) == 0
    error_message = "Should not create log group when using existing Lambda"
  }
}

run "verify_api_schema_content" {
  command = plan

  assert {
    condition     = can(jsondecode(local.api_schema_content).openapi == "3.0.0")
    error_message = "API schema should be valid OpenAPI 3.0.0"
  }

  assert {
    condition     = can(jsondecode(local.api_schema_content).paths["/test"])
    error_message = "API schema should include defined paths"
  }
}
