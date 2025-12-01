# Lambda Function Source Code (if inline code is provided)
data "archive_file" "lambda" {
  count       = var.create_lambda_function && var.lambda_source_code_inline != null ? 1 : 0
  type        = "zip"
  output_path = "${path.module}/lambda_function.zip"

  source {
    content  = var.lambda_source_code_inline
    filename = "index.${local.file_extension}"
  }
}

# IAM Role for Lambda Function
resource "aws_iam_role" "lambda" {
  count              = var.create_lambda_function && var.lambda_role_arn == null ? 1 : 0
  name               = "${var.lambda_function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json

  tags = merge(
    var.tags,
    {
      Name      = "${var.lambda_function_name}-role"
      ManagedBy = "Terraform"
      Component = "BedrockActionGroup"
    }
  )
}

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# Lambda Basic Execution Policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  count      = var.create_lambda_function && var.lambda_role_arn == null ? 1 : 0
  role       = aws_iam_role.lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# VPC Execution Policy (if VPC is enabled)
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  count      = var.create_lambda_function && var.lambda_role_arn == null && var.enable_lambda_vpc ? 1 : 0
  role       = aws_iam_role.lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Lambda Insights Policy (if enabled)
resource "aws_iam_role_policy_attachment" "lambda_insights" {
  count      = var.create_lambda_function && var.lambda_role_arn == null && var.enable_lambda_insights ? 1 : 0
  role       = aws_iam_role.lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLambdaInsightsExecutionRolePolicy"
}

# Additional Lambda Policies
resource "aws_iam_role_policy_attachment" "lambda_additional" {
  for_each = var.create_lambda_function && var.lambda_role_arn == null ? toset(var.additional_lambda_policies) : []

  role       = aws_iam_role.lambda[0].name
  policy_arn = each.value
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda" {
  count             = var.create_lambda_function ? 1 : 0
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = var.cloudwatch_logs_retention_days
  kms_key_id        = var.kms_key_id

  tags = merge(
    var.tags,
    {
      Name      = "${var.lambda_function_name}-logs"
      ManagedBy = "Terraform"
      Component = "BedrockActionGroup"
    }
  )
}

# Lambda Function
resource "aws_lambda_function" "this" {
  count = var.create_lambda_function ? 1 : 0

  function_name = var.lambda_function_name
  description   = var.description
  role          = var.lambda_role_arn != null ? var.lambda_role_arn : aws_iam_role.lambda[0].arn

  filename         = local.lambda_filename
  source_code_hash = local.lambda_source_hash

  handler     = var.lambda_handler
  runtime     = var.lambda_runtime
  timeout     = var.lambda_timeout
  memory_size = var.lambda_memory_size

  layers = concat(
    var.lambda_layers,
    var.enable_lambda_insights ? [
      "arn:aws:lambda:${data.aws_region.current.region}:580247275435:layer:LambdaInsightsExtension:21"
    ] : []
  )

  reserved_concurrent_executions = var.reserved_concurrent_executions

  dynamic "environment" {
    for_each = length(var.lambda_environment_variables) > 0 ? [1] : []
    content {
      variables = var.lambda_environment_variables
    }
  }

  dynamic "vpc_config" {
    for_each = var.enable_lambda_vpc ? [1] : []
    content {
      subnet_ids         = var.vpc_subnet_ids
      security_group_ids = var.vpc_security_group_ids
    }
  }

  dynamic "tracing_config" {
    for_each = var.enable_xray_tracing ? [1] : []
    content {
      mode = "Active"
    }
  }

  kms_key_arn = var.kms_key_id != null ? "arn:aws:kms:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:key/${var.kms_key_id}" : null

  tags = merge(
    var.tags,
    {
      Name      = var.lambda_function_name
      ManagedBy = "Terraform"
      Component = "BedrockActionGroup"
    }
  )

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy_attachment.lambda_vpc,
    aws_iam_role_policy_attachment.lambda_insights
  ]
}

# Lambda Permission for Bedrock Agent
resource "aws_lambda_permission" "bedrock_agent" {
  count = var.create_lambda_function ? 1 : 0

  statement_id  = "AllowBedrockAgentInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this[0].function_name
  principal     = "bedrock.amazonaws.com"

  source_account = data.aws_caller_identity.current.account_id
  source_arn     = "arn:aws:bedrock:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:agent/*"
}

# Read API Schema from file if specified
data "local_file" "api_schema" {
  count    = var.api_schema_is_file ? 1 : 0
  filename = var.api_schema
}

# Locals
locals {
  lambda_filename = var.lambda_source_code_inline != null ? data.archive_file.lambda[0].output_path : var.lambda_source_code_path

  lambda_source_hash = var.lambda_source_code_inline != null ? data.archive_file.lambda[0].output_base64sha256 : (
    var.lambda_source_code_path != null ? filebase64sha256(var.lambda_source_code_path) : null
  )

  file_extension = var.lambda_runtime == "python3.12" || var.lambda_runtime == "python3.11" ? "py" : "js"

  api_schema_content = var.api_schema_is_file ? data.local_file.api_schema[0].content : var.api_schema
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
