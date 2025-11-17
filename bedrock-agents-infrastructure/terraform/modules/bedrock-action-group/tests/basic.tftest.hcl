# ==============================================================================
# Bedrock Action Group Module - Basic Tests
# ==============================================================================
# Tests basic Lambda function creation for action groups
# ==============================================================================

variables {
  lambda_function_name = "test-action-lambda"
  description         = "Test action group Lambda"
  create_lambda_function = true

  lambda_runtime = "python3.12"
  lambda_handler = "index.handler"

  lambda_source_code_inline = <<-EOT
    def handler(event, context):
        return {'statusCode': 200, 'body': 'Test'}
  EOT

  api_schema = jsonencode({
    openapi = "3.0.0"
    info = {
      title   = "Test Action Group API"
      version = "1.0.0"
    }
  })

  tags = {
    Environment = "test"
  }
}

run "verify_lambda_creation" {
  command = plan

  assert {
    condition     = length(aws_lambda_function.this) == 1
    error_message = "Should create one Lambda function"
  }

  assert {
    condition     = can(aws_lambda_function.this[0].function_name == "test-action-lambda")
    error_message = "Lambda function name should match input"
  }

  assert {
    condition     = can(aws_lambda_function.this[0].runtime == "python3.12")
    error_message = "Lambda runtime should be python3.12"
  }
}

run "verify_iam_role_creation" {
  command = plan

  assert {
    condition     = length(aws_iam_role.lambda) == 1
    error_message = "Should create IAM role for Lambda"
  }

  assert {
    condition     = can(regex("lambda.amazonaws.com", aws_iam_role.lambda[0].assume_role_policy))
    error_message = "IAM role should trust lambda service"
  }
}

run "verify_bedrock_permission" {
  command = plan

  assert {
    condition     = length(aws_lambda_permission.bedrock_agent) == 1
    error_message = "Should create Lambda permission for Bedrock"
  }

  assert {
    condition     = can(aws_lambda_permission.bedrock_agent[0].principal == "bedrock.amazonaws.com")
    error_message = "Permission should allow Bedrock to invoke Lambda"
  }
}

run "verify_cloudwatch_log_group" {
  command = plan

  assert {
    condition     = length(aws_cloudwatch_log_group.lambda) == 1
    error_message = "Should create CloudWatch log group"
  }

  assert {
    condition     = can(regex("^/aws/lambda/", aws_cloudwatch_log_group.lambda[0].name))
    error_message = "Log group name should follow AWS convention"
  }
}
