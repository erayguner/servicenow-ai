# SQS Dead Letter Queue for Failed Incident Responses
# Captures failed incident response tasks for retry and analysis

resource "aws_sqs_queue" "incident_response_dlq" {
  name                       = "incident-response-dlq-${var.environment}"
  message_retention_seconds  = 1209600 # 14 days
  visibility_timeout_seconds = 300

  tags = {
    Name        = "incident-response-dlq"
    Environment = var.environment
    Purpose     = "Incident Response"
  }
}

# Main incident response queue with DLQ
resource "aws_sqs_queue" "incident_response_queue" {
  name                       = "incident-response-queue-${var.environment}"
  message_retention_seconds  = 345600 # 4 days
  visibility_timeout_seconds = 900    # 15 minutes

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.incident_response_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name        = "incident-response-queue"
    Environment = var.environment
    Purpose     = "Incident Response"
  }
}

# CloudWatch Alarms for DLQ
resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  alarm_name          = "incident-response-dlq-messages-${var.environment}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = "300"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "Alert when incident response DLQ has messages"
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.incident_response_dlq.name
  }

  alarm_actions = [var.incident_response_topic_arn]

  tags = {
    Name        = "dlq-alarm"
    Environment = var.environment
  }
}

# CloudWatch Alarms for failed responses
resource "aws_cloudwatch_metric_alarm" "queue_age" {
  alarm_name          = "incident-response-queue-age-${var.environment}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "ApproximateAgeOfOldestMessage"
  namespace           = "AWS/SQS"
  period              = "300"
  statistic           = "Maximum"
  threshold           = "3600" # 1 hour
  alarm_description   = "Alert when incident response messages are older than 1 hour"
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.incident_response_queue.name
  }

  alarm_actions = [var.incident_response_topic_arn]

  tags = {
    Name        = "queue-age-alarm"
    Environment = var.environment
  }
}

# CloudWatch Dashboard for DLQ Monitoring
resource "aws_cloudwatch_dashboard" "incident_response_dlq" {
  dashboard_name = "incident-response-dlq-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", { stat = "Average" }],
            [".", "ApproximateAgeOfOldestMessage", { stat = "Maximum" }],
            [".", "NumberOfMessagesSent", { stat = "Sum" }],
            [".", "NumberOfMessagesReceived", { stat = "Sum" }],
            [".", "NumberOfMessagesDeleted", { stat = "Sum" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Incident Response DLQ Metrics"
        }
      },
      {
        type = "log"
        properties = {
          query        = "fields @timestamp, @message | filter @message like /ERROR|FAILED/ | stats count() as failures by bin(5m)"
          region       = var.aws_region
          title        = "Failed Incident Responses"
          logGroupName = "/aws/incident-response/main"
        }
      }
    ]
  })
}

# IAM Policy for accessing DLQ
resource "aws_iam_policy" "dlq_access" {
  name        = "incident-response-dlq-access-${var.environment}"
  path        = "/incident-response/"
  description = "Allows incident response services to access DLQ"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SendMessageToDLQ"
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = aws_sqs_queue.incident_response_dlq.arn
      },
      {
        Sid    = "ManageQueue"
        Effect = "Allow"
        Action = [
          "sqs:GetQueueAttributes",
          "sqs:SetQueueAttributes",
          "sqs:PurgeQueue"
        ]
        Resource = [
          aws_sqs_queue.incident_response_queue.arn,
          aws_sqs_queue.incident_response_dlq.arn
        ]
      },
      {
        Sid    = "ReceiveMessages"
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = [
          aws_sqs_queue.incident_response_queue.arn,
          aws_sqs_queue.incident_response_dlq.arn
        ]
      }
    ]
  })

  tags = {
    Name        = "dlq-access-policy"
    Environment = var.environment
  }
}

# EventBridge Rule to send failed responses to DLQ
resource "aws_cloudwatch_event_rule" "response_failure" {
  name        = "incident-response-failure-handler-${var.environment}"
  description = "Handle failed incident response tasks"

  event_pattern = jsonencode({
    source      = ["aws.events"]
    detail-type = ["Step Functions Execution State Change"]
    detail = {
      status          = ["FAILED", "TIMED_OUT", "ABORTED"]
      stateMachineArn = [var.step_functions_state_machine_arn]
    }
  })

  tags = {
    Name        = "response-failure-handler"
    Environment = var.environment
  }
}

# Lambda function to process DLQ messages
resource "aws_lambda_function" "dlq_processor" {
  filename      = "dlq_processor.zip"
  function_name = "incident-response-dlq-processor-${var.environment}"
  role          = var.lambda_responder_role_arn
  handler       = "index.handler"
  timeout       = 60
  memory_size   = 256

  environment {
    variables = {
      DLQ_URL                 = aws_sqs_queue.incident_response_dlq.url
      INCIDENT_RESPONSE_TOPIC = var.incident_response_topic_arn
      INCIDENT_TRACKING_TABLE = var.incident_tracking_table
      ENVIRONMENT             = var.environment
    }
  }

  tags = {
    Name        = "dlq-processor"
    Environment = var.environment
    Purpose     = "Incident Response"
  }
}

# EventBridge Rule to trigger DLQ processor
resource "aws_cloudwatch_event_rule" "process_dlq" {
  name                = "process-incident-response-dlq-${var.environment}"
  description         = "Periodically process incident response DLQ"
  schedule_expression = "rate(5 minutes)"

  tags = {
    Name        = "process-dlq-rule"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_event_target" "dlq_processor_target" {
  rule      = aws_cloudwatch_event_rule.process_dlq.name
  target_id = "DLQProcessorLambda"
  arn       = aws_lambda_function.dlq_processor.arn

  input = jsonencode({
    dlq_url = aws_sqs_queue.incident_response_dlq.url
  })
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dlq_processor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.process_dlq.arn
}

# Variables
variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "incident_response_topic_arn" {
  description = "SNS topic ARN for incident response"
  type        = string
}

variable "lambda_responder_role_arn" {
  description = "IAM role ARN for Lambda functions"
  type        = string
}

variable "step_functions_state_machine_arn" {
  description = "ARN of the incident response Step Functions state machine"
  type        = string
}

variable "incident_tracking_table" {
  description = "DynamoDB table for tracking incidents"
  type        = string
}

# Outputs
output "incident_response_queue_url" {
  value       = aws_sqs_queue.incident_response_queue.url
  description = "URL of the incident response queue"
}

output "incident_response_queue_arn" {
  value       = aws_sqs_queue.incident_response_queue.arn
  description = "ARN of the incident response queue"
}

output "dlq_url" {
  value       = aws_sqs_queue.incident_response_dlq.url
  description = "URL of the incident response DLQ"
}

output "dlq_arn" {
  value       = aws_sqs_queue.incident_response_dlq.arn
  description = "ARN of the incident response DLQ"
}

output "dlq_processor_lambda_arn" {
  value       = aws_lambda_function.dlq_processor.arn
  description = "ARN of the DLQ processor Lambda function"
}
