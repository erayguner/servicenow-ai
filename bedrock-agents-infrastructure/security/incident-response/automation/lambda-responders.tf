# Lambda Functions for Automated Incident Response

# Lambda function to log incidents
resource "aws_lambda_function" "incident_logger" {
  filename      = "incident_logger.zip"
  function_name = "incident-response-logger-${var.environment}"
  role          = aws_iam_role.lambda_responder_role.arn
  handler       = "index.handler"
  timeout       = 60
  memory_size   = 256

  environment {
    variables = {
      LOG_GROUP   = aws_cloudwatch_log_group.incident_response_logs.name
      ENVIRONMENT = var.environment
    }
  }

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.security_group_id]
  }

  tags = {
    Name        = "incident-logger"
    Environment = var.environment
    Purpose     = "Incident Response"
  }
}

# Lambda function to track incidents
resource "aws_lambda_function" "incident_tracker" {
  filename      = "incident_tracker.zip"
  function_name = "incident-response-tracker-${var.environment}"
  role          = aws_iam_role.lambda_responder_role.arn
  handler       = "index.handler"
  timeout       = 60
  memory_size   = 256

  environment {
    variables = {
      DYNAMODB_TABLE = var.incident_tracking_table
      ENVIRONMENT    = var.environment
    }
  }

  tags = {
    Name        = "incident-tracker"
    Environment = var.environment
    Purpose     = "Incident Response"
  }
}

# Lambda function to isolate compromised resources
resource "aws_lambda_function" "resource_isolator" {
  filename      = "resource_isolator.zip"
  function_name = "incident-response-isolator-${var.environment}"
  role          = aws_iam_role.lambda_responder_role.arn
  handler       = "index.handler"
  timeout       = 300
  memory_size   = 512

  environment {
    variables = {
      STEP_FUNCTIONS_ARN = var.step_functions_state_machine_arn
      ENVIRONMENT        = var.environment
    }
  }

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.security_group_id]
  }

  tags = {
    Name        = "resource-isolator"
    Environment = var.environment
    Purpose     = "Incident Response"
  }
}

# Lambda function to trigger forensics
resource "aws_lambda_function" "forensics_trigger" {
  filename      = "forensics_trigger.zip"
  function_name = "incident-response-forensics-${var.environment}"
  role          = aws_iam_role.lambda_responder_role.arn
  handler       = "index.handler"
  timeout       = 300
  memory_size   = 512

  environment {
    variables = {
      FORENSICS_BUCKET   = var.forensics_s3_bucket
      FORENSICS_ROLE_ARN = aws_iam_role.lambda_responder_role.arn
      ENVIRONMENT        = var.environment
    }
  }

  tags = {
    Name        = "forensics-trigger"
    Environment = var.environment
    Purpose     = "Incident Response"
  }
}

# Lambda function to notify stakeholders
resource "aws_lambda_function" "stakeholder_notifier" {
  filename      = "stakeholder_notifier.zip"
  function_name = "incident-response-notifier-${var.environment}"
  role          = aws_iam_role.lambda_responder_role.arn
  handler       = "index.handler"
  timeout       = 60
  memory_size   = 256

  environment {
    variables = {
      SECURITY_TOPIC_ARN           = var.security_team_topic_arn
      INCIDENT_COMMANDER_TOPIC_ARN = var.incident_commander_topic_arn
      EXECUTIVE_ESCALATION_TOPIC   = var.executive_escalation_topic_arn
      ENVIRONMENT                  = var.environment
    }
  }

  tags = {
    Name        = "stakeholder-notifier"
    Environment = var.environment
    Purpose     = "Incident Response"
  }
}

# IAM Role for Lambda responder functions
resource "aws_iam_role" "lambda_responder_role" {
  name = "incident-response-lambda-role-${var.environment}"
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

  tags = {
    Name        = "lambda-responder-role"
    Environment = var.environment
  }
}

# IAM Policy for Lambda responder functions
resource "aws_iam_role_policy" "lambda_responder_policy" {
  name = "incident-response-lambda-policy-${var.environment}"
  role = aws_iam_role.lambda_responder_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:*"
      },
      {
        Sid    = "EC2Isolation"
        Effect = "Allow"
        Action = [
          "ec2:ModifyInstanceAttribute",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups"
        ]
        Resource = "*"
      },
      {
        Sid    = "IAMAccess"
        Effect = "Allow"
        Action = [
          "iam:ListAccessKeys",
          "iam:DeleteAccessKey",
          "iam:UpdateAccessKey",
          "iam:AttachUserPolicy",
          "iam:DetachUserPolicy"
        ]
        Resource = "*"
      },
      {
        Sid    = "DynamoDBAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:GetItem",
          "dynamodb:Query"
        ]
        Resource = "arn:aws:dynamodb:${var.aws_region}:${var.aws_account_id}:table/${var.incident_tracking_table}"
      },
      {
        Sid    = "SNSPublish"
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = [
          var.security_team_topic_arn,
          var.incident_commander_topic_arn,
          var.executive_escalation_topic_arn
        ]
      },
      {
        Sid    = "S3ForensicsAccess"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.forensics_s3_bucket}/*",
          "arn:aws:s3:::${var.forensics_s3_bucket}"
        ]
      },
      {
        Sid    = "StepFunctionsAccess"
        Effect = "Allow"
        Action = [
          "states:StartExecution",
          "states:DescribeExecution"
        ]
        Resource = var.step_functions_state_machine_arn
      }
    ]
  })
}

# CloudWatch Log Group for incident response logs
resource "aws_cloudwatch_log_group" "incident_response_logs" {
  name              = "/aws/incident-response/${var.environment}"
  retention_in_days = 90

  tags = {
    Name        = "incident-response-logs"
    Environment = var.environment
  }
}

# Lambda permission for SNS to invoke logger
resource "aws_lambda_permission" "sns_invoke_logger" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.incident_logger.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = var.incident_response_topic_arn
}

# Lambda permission for SNS to invoke tracker
resource "aws_lambda_permission" "sns_invoke_tracker" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.incident_tracker.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = var.incident_response_topic_arn
}

# Lambda permission for EventBridge to invoke isolator
resource "aws_lambda_permission" "eventbridge_invoke_isolator" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.resource_isolator.function_name
  principal     = "events.amazonaws.com"
}

# Variables
variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "subnet_ids" {
  description = "VPC subnet IDs for Lambda functions"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for Lambda functions"
  type        = string
}

variable "incident_tracking_table" {
  description = "DynamoDB table for tracking incidents"
  type        = string
}

variable "forensics_s3_bucket" {
  description = "S3 bucket for forensic evidence"
  type        = string
}

variable "step_functions_state_machine_arn" {
  description = "ARN of the incident response Step Functions state machine"
  type        = string
}

variable "security_team_topic_arn" {
  description = "ARN of security team SNS topic"
  type        = string
}

variable "incident_commander_topic_arn" {
  description = "ARN of incident commander SNS topic"
  type        = string
}

variable "executive_escalation_topic_arn" {
  description = "ARN of executive escalation SNS topic"
  type        = string
}

variable "incident_response_topic_arn" {
  description = "ARN of main incident response SNS topic"
  type        = string
}

# Outputs
output "incident_logger_lambda_arn" {
  value       = aws_lambda_function.incident_logger.arn
  description = "ARN of incident logger Lambda function"
}

output "incident_tracker_lambda_arn" {
  value       = aws_lambda_function.incident_tracker.arn
  description = "ARN of incident tracker Lambda function"
}

output "resource_isolator_lambda_arn" {
  value       = aws_lambda_function.resource_isolator.arn
  description = "ARN of resource isolator Lambda function"
}

output "forensics_trigger_lambda_arn" {
  value       = aws_lambda_function.forensics_trigger.arn
  description = "ARN of forensics trigger Lambda function"
}

output "stakeholder_notifier_lambda_arn" {
  value       = aws_lambda_function.stakeholder_notifier.arn
  description = "ARN of stakeholder notifier Lambda function"
}

output "lambda_responder_role_arn" {
  value       = aws_iam_role.lambda_responder_role.arn
  description = "ARN of Lambda responder IAM role"
}

output "incident_response_log_group" {
  value       = aws_cloudwatch_log_group.incident_response_logs.name
  description = "CloudWatch Log Group for incident response"
}
