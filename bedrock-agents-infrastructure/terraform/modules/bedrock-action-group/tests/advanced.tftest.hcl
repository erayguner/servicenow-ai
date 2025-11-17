# ==============================================================================
# Bedrock Action Group Module - Advanced Tests
# ==============================================================================
# Tests advanced Lambda features including VPC, layers, and environment variables
# ==============================================================================

variables {
  lambda_function_name = "advanced-action-lambda"
  description         = "Advanced action group Lambda"
  create_lambda_function = true

  lambda_runtime     = "python3.12"
  lambda_handler     = "index.handler"
  lambda_timeout     = 60
  lambda_memory_size = 512

  lambda_source_code_inline = "def handler(event, context): return {'statusCode': 200}"

  enable_lambda_vpc = true
  vpc_subnet_ids = ["subnet-12345", "subnet-67890"]
  vpc_security_group_ids = ["sg-12345"]

  enable_xray_tracing = true
  enable_lambda_insights = true

  lambda_environment_variables = {
    ENV = "test"
    LOG_LEVEL = "DEBUG"
  }

  lambda_layers = ["arn:aws:lambda:us-east-1:123456789012:layer:test-layer:1"]

  reserved_concurrent_executions = 10

  api_schema = jsonencode({ openapi = "3.0.0" })

  tags = {
    Environment = "advanced-test"
  }
}

run "verify_vpc_configuration" {
  command = plan

  assert {
    condition     = can(aws_lambda_function.this[0].vpc_config[0])
    error_message = "Lambda should have VPC configuration"
  }

  assert {
    condition     = length(can(aws_lambda_function.this[0].vpc_config[0].subnet_ids)) == 2
    error_message = "Lambda should be in 2 subnets"
  }
}

run "verify_xray_tracing" {
  command = plan

  assert {
    condition     = can(aws_lambda_function.this[0].tracing_config[0].mode == "Active")
    error_message = "X-Ray tracing should be active"
  }
}

run "verify_lambda_insights" {
  command = plan

  assert {
    condition     = length(aws_iam_role_policy_attachment.lambda_insights) == 1
    error_message = "Lambda Insights policy should be attached"
  }
}

run "verify_environment_variables" {
  command = plan

  assert {
    condition     = can(aws_lambda_function.this[0].environment[0].variables["ENV"] == "test")
    error_message = "Environment variable ENV should be set"
  }

  assert {
    condition     = can(aws_lambda_function.this[0].environment[0].variables["LOG_LEVEL"] == "DEBUG")
    error_message = "Environment variable LOG_LEVEL should be set"
  }
}

run "verify_layers" {
  command = plan

  assert {
    condition     = length(can(aws_lambda_function.this[0].layers)) > 0
    error_message = "Lambda should have layers configured"
  }
}

run "verify_concurrency" {
  command = plan

  assert {
    condition     = aws_lambda_function.this[0].reserved_concurrent_executions == 10
    error_message = "Reserved concurrent executions should be 10"
  }
}

run "verify_timeout_and_memory" {
  command = plan

  assert {
    condition     = aws_lambda_function.this[0].timeout == 60
    error_message = "Lambda timeout should be 60 seconds"
  }

  assert {
    condition     = aws_lambda_function.this[0].memory_size == 512
    error_message = "Lambda memory should be 512 MB"
  }
}
