# IAM roles and policies for ServiceNow integration

# Lambda Execution Role
resource "aws_iam_role" "lambda_execution" {
  name = "${local.name_prefix}-lambda-role-${local.resource_id}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-lambda-role"
    }
  )
}

# Lambda execution policy
resource "aws_iam_role_policy" "lambda_execution" {
  name = "${local.name_prefix}-lambda-policy"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # CloudWatch Logs
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:aws:logs:${module.shared_data.region_name}:${module.shared_data.account_id}:log-group:/aws/lambda/${local.name_prefix}*:*"
        ]
      },
      # DynamoDB access
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem"
        ]
        Resource = [
          aws_dynamodb_table.servicenow_state.arn,
          "${aws_dynamodb_table.servicenow_state.arn}/index/*"
        ]
      },
      # Secrets Manager access
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          local.servicenow_credentials_secret_arn
        ]
      },
      # KMS for decryption
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = var.kms_key_id != null ? [var.kms_key_id] : ["*"]
        Condition = var.kms_key_id != null ? {
          StringEquals = {
            "kms:ViaService" = [
              "secretsmanager.${module.shared_data.region_name}.amazonaws.com",
              "dynamodb.${module.shared_data.region_name}.amazonaws.com"
            ]
          }
        } : null
      },
      # EventBridge
      {
        Effect = "Allow"
        Action = [
          "events:PutEvents"
        ]
        Resource = [
          aws_cloudwatch_event_bus.servicenow_events.arn
        ]
      },
      # Step Functions
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution",
          "states:DescribeExecution",
          "states:StopExecution"
        ]
        Resource = [
          aws_sfn_state_machine.incident_workflow.arn,
          "${aws_sfn_state_machine.incident_workflow.arn}:*"
        ]
      },
      # Bedrock agent invocation
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeAgent",
          "bedrock:Retrieve"
        ]
        Resource = [
          "arn:aws:bedrock:${module.shared_data.region_name}:${module.shared_data.account_id}:agent/*",
          "arn:aws:bedrock:${module.shared_data.region_name}:${module.shared_data.account_id}:knowledge-base/*"
        ]
      },
      # X-Ray tracing
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = ["*"]
      },
      # VPC networking (if VPC is configured)
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses"
        ]
        Resource = var.vpc_id != null ? ["*"] : []
      }
    ]
  })
}

# Attach AWS managed policy for basic Lambda execution
resource "aws_iam_role_policy_attachment" "lambda_execution" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Attach VPC execution policy if VPC is configured
resource "aws_iam_role_policy_attachment" "lambda_vpc_execution" {
  count = var.vpc_id != null ? 1 : 0

  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Step Functions Execution Role
resource "aws_iam_role" "step_functions" {
  name = "${local.name_prefix}-stepfunctions-role-${local.resource_id}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-stepfunctions-role"
    }
  )
}

# Step Functions execution policy
resource "aws_iam_role_policy" "step_functions" {
  name = "${local.name_prefix}-stepfunctions-policy"
  role = aws_iam_role.step_functions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Lambda invocation
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          aws_lambda_function.servicenow_integration.arn,
          aws_lambda_function.webhook_processor.arn
        ]
      },
      # DynamoDB access
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query"
        ]
        Resource = [
          aws_dynamodb_table.servicenow_state.arn
        ]
      },
      # SNS for notifications
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = [
          aws_sns_topic.servicenow_notifications.arn
        ]
      },
      # CloudWatch Logs
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      },
      # X-Ray tracing
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets"
        ]
        Resource = ["*"]
      },
      # Bedrock agent invocation
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeAgent"
        ]
        Resource = [
          "arn:aws:bedrock:${module.shared_data.region_name}:${module.shared_data.account_id}:agent/*"
        ]
      }
    ]
  })
}

# API Gateway CloudWatch Logs Role
resource "aws_iam_role" "api_gateway_cloudwatch" {
  count = var.enable_api_gateway_logging ? 1 : 0

  name = "${local.name_prefix}-apigateway-logs-${local.resource_id}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-apigateway-logs-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch" {
  count = var.enable_api_gateway_logging ? 1 : 0

  role       = aws_iam_role.api_gateway_cloudwatch[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

# EventBridge Role
resource "aws_iam_role" "eventbridge" {
  name = "${local.name_prefix}-eventbridge-role-${local.resource_id}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-eventbridge-role"
    }
  )
}

# EventBridge policy to invoke Step Functions
resource "aws_iam_role_policy" "eventbridge" {
  name = "${local.name_prefix}-eventbridge-policy"
  role = aws_iam_role.eventbridge.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution"
        ]
        Resource = [
          aws_sfn_state_machine.incident_workflow.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          aws_lambda_function.webhook_processor.arn
        ]
      }
    ]
  })
}
