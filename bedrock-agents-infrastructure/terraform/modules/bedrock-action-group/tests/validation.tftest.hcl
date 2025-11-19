# ==============================================================================
# Bedrock Action Group Module - Validation Tests
# ==============================================================================
# Tests output validation
# ==============================================================================

variables {
  lambda_function_name   = "validation-lambda"
  create_lambda_function = true

  lambda_runtime            = "python3.12"
  lambda_handler            = "index.handler"
  lambda_source_code_inline = "def handler(event, context): return {}"

  api_schema = jsonencode({ openapi = "3.0.0" })

  tags = {
    Environment = "validation"
  }
}

run "validate_lambda_outputs" {
  command = plan

  assert {
    condition     = output.lambda_function_arn != null
    error_message = "Lambda function ARN output should not be null"
  }

  assert {
    condition     = output.lambda_function_name != null
    error_message = "Lambda function name output should not be null"
  }

  assert {
    condition     = can(regex("^arn:aws:lambda:", output.lambda_function_arn))
    error_message = "Lambda ARN should be a valid Lambda ARN"
  }
}

run "validate_iam_outputs" {
  command = plan

  assert {
    condition     = output.lambda_role_arn != null
    error_message = "Lambda role ARN should not be null"
  }

  assert {
    condition     = can(regex("^arn:aws:iam::", output.lambda_role_arn))
    error_message = "IAM role ARN should be valid"
  }
}

run "validate_api_schema_output" {
  command = plan

  assert {
    condition     = output.api_schema != null
    error_message = "API schema output should not be null"
  }

  assert {
    condition     = can(jsondecode(output.api_schema))
    error_message = "API schema should be valid JSON"
  }
}
