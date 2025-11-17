# SNS Topics for Incident Response Notifications

# Main incident response topic
resource "aws_sns_topic" "incident_response" {
  name              = "incident-response-notifications-${var.environment}"
  display_name      = "Incident Response Notifications"
  kms_master_key_id = "alias/aws/sns"

  tags = {
    Name        = "incident-response-topic"
    Environment = var.environment
    Purpose     = "Incident Response"
  }
}

# Topic policy to allow EventBridge to publish
resource "aws_sns_topic_policy" "incident_response_policy" {
  arn = aws_sns_topic.incident_response.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventBridgePublish"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = [
          "SNS:Publish"
        ]
        Resource = aws_sns_topic.incident_response.arn
      },
      {
        Sid    = "AllowLambdaPublish"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = [
          "SNS:Publish"
        ]
        Resource = aws_sns_topic.incident_response.arn
      },
      {
        Sid    = "AllowStepFunctionsPublish"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
        Action = [
          "SNS:Publish"
        ]
        Resource = aws_sns_topic.incident_response.arn
      }
    ]
  })
}

# Security team notification topic
resource "aws_sns_topic" "security_team" {
  name              = "security-team-notifications-${var.environment}"
  display_name      = "Security Team Notifications"
  kms_master_key_id = "alias/aws/sns"

  tags = {
    Name        = "security-team-topic"
    Environment = var.environment
  }
}

# Incident commander notification topic
resource "aws_sns_topic" "incident_commander" {
  name              = "incident-commander-notifications-${var.environment}"
  display_name      = "Incident Commander Notifications"
  kms_master_key_id = "alias/aws/sns"

  tags = {
    Name        = "incident-commander-topic"
    Environment = var.environment
  }
}

# Forensics team notification topic
resource "aws_sns_topic" "forensics_team" {
  name              = "forensics-team-notifications-${var.environment}"
  display_name      = "Forensics Team Notifications"
  kms_master_key_id = "alias/aws/sns"

  tags = {
    Name        = "forensics-team-topic"
    Environment = var.environment
  }
}

# Customer notification topic (for filtered notifications)
resource "aws_sns_topic" "customer_notifications" {
  name              = "customer-notifications-${var.environment}"
  display_name      = "Customer Notifications"
  kms_master_key_id = "alias/aws/sns"

  tags = {
    Name        = "customer-topic"
    Environment = var.environment
  }
}

# Executive escalation topic
resource "aws_sns_topic" "executive_escalation" {
  name              = "executive-escalation-${var.environment}"
  display_name      = "Executive Escalation"
  kms_master_key_id = "alias/aws/sns"

  tags = {
    Name        = "executive-escalation-topic"
    Environment = var.environment
  }
}

# SNS subscriptions for Slack integration
resource "aws_sns_topic_subscription" "security_team_slack" {
  topic_arn              = aws_sns_topic.security_team.arn
  protocol               = "https"
  endpoint               = var.security_team_slack_webhook
  endpoint_auto_confirms = true

  filter_policy = jsonencode({
    severity = ["P1", "P2"]
  })
}

resource "aws_sns_topic_subscription" "incident_commander_slack" {
  topic_arn              = aws_sns_topic.incident_commander.arn
  protocol               = "https"
  endpoint               = var.incident_commander_slack_webhook
  endpoint_auto_confirms = true
}

resource "aws_sns_topic_subscription" "forensics_slack" {
  topic_arn              = aws_sns_topic.forensics_team.arn
  protocol               = "https"
  endpoint               = var.forensics_team_slack_webhook
  endpoint_auto_confirms = true
}

# SNS subscriptions for email
resource "aws_sns_topic_subscription" "security_team_email" {
  topic_arn = aws_sns_topic.security_team.arn
  protocol  = "email"
  endpoint  = var.security_team_email

  depends_on = [aws_sns_topic.security_team]
}

resource "aws_sns_topic_subscription" "incident_commander_email" {
  topic_arn = aws_sns_topic.incident_commander.arn
  protocol  = "email"
  endpoint  = var.incident_commander_email

  depends_on = [aws_sns_topic.incident_commander]
}

resource "aws_sns_topic_subscription" "executive_email" {
  topic_arn = aws_sns_topic.executive_escalation.arn
  protocol  = "email"
  endpoint  = var.executive_email

  depends_on = [aws_sns_topic.executive_escalation]
}

# SNS subscriptions for Lambda processors
resource "aws_sns_topic_subscription" "incident_logger" {
  topic_arn              = aws_sns_topic.incident_response.arn
  protocol               = "lambda"
  endpoint               = var.incident_logger_lambda_arn
  endpoint_auto_confirms = true
}

resource "aws_sns_topic_subscription" "incident_tracker" {
  topic_arn              = aws_sns_topic.incident_response.arn
  protocol               = "lambda"
  endpoint               = var.incident_tracker_lambda_arn
  endpoint_auto_confirms = true
}

# SNS subscriptions for SQS
resource "aws_sns_topic_subscription" "response_queue" {
  topic_arn            = aws_sns_topic.incident_response.arn
  protocol             = "sqs"
  endpoint             = var.incident_response_queue_arn
  raw_message_delivery = true

  filter_policy = jsonencode({
    eventSource = ["aws.guardduty", "aws.securityhub", "custom.dlp"]
  })
}

# CloudWatch Alarms for SNS topics
resource "aws_cloudwatch_metric_alarm" "topic_publish_failure" {
  alarm_name          = "incident-response-publish-failure-${var.environment}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "PublishSize"
  namespace           = "AWS/SNS"
  period              = "300"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "Alert when SNS publish failures occur"
  treat_missing_data  = "notBreaching"

  dimensions = {
    TopicName = aws_sns_topic.incident_response.name
  }

  tags = {
    Name        = "topic-publish-alarm"
    Environment = var.environment
  }
}

# SNS Topic for DLQ notifications
resource "aws_sns_topic" "dlq_notifications" {
  name              = "incident-response-dlq-notifications-${var.environment}"
  display_name      = "DLQ Notifications"
  kms_master_key_id = "alias/aws/sns"

  tags = {
    Name        = "dlq-notifications-topic"
    Environment = var.environment
  }
}

resource "aws_sns_topic_subscription" "dlq_security_team" {
  topic_arn              = aws_sns_topic.dlq_notifications.arn
  protocol               = "https"
  endpoint               = var.security_team_slack_webhook
  endpoint_auto_confirms = true
}

# Variables
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "security_team_slack_webhook" {
  description = "Security team Slack webhook URL"
  type        = string
  sensitive   = true
}

variable "incident_commander_slack_webhook" {
  description = "Incident commander Slack webhook URL"
  type        = string
  sensitive   = true
}

variable "forensics_team_slack_webhook" {
  description = "Forensics team Slack webhook URL"
  type        = string
  sensitive   = true
}

variable "security_team_email" {
  description = "Security team email address"
  type        = string
}

variable "incident_commander_email" {
  description = "Incident commander email address"
  type        = string
}

variable "executive_email" {
  description = "Executive email address for escalations"
  type        = string
}

variable "incident_logger_lambda_arn" {
  description = "ARN of incident logger Lambda function"
  type        = string
}

variable "incident_tracker_lambda_arn" {
  description = "ARN of incident tracker Lambda function"
  type        = string
}

variable "incident_response_queue_arn" {
  description = "ARN of incident response SQS queue"
  type        = string
}

# Outputs
output "incident_response_topic_arn" {
  value       = aws_sns_topic.incident_response.arn
  description = "ARN of main incident response SNS topic"
}

output "security_team_topic_arn" {
  value       = aws_sns_topic.security_team.arn
  description = "ARN of security team SNS topic"
}

output "incident_commander_topic_arn" {
  value       = aws_sns_topic.incident_commander.arn
  description = "ARN of incident commander SNS topic"
}

output "forensics_team_topic_arn" {
  value       = aws_sns_topic.forensics_team.arn
  description = "ARN of forensics team SNS topic"
}

output "executive_escalation_topic_arn" {
  value       = aws_sns_topic.executive_escalation.arn
  description = "ARN of executive escalation SNS topic"
}

output "dlq_notifications_topic_arn" {
  value       = aws_sns_topic.dlq_notifications.arn
  description = "ARN of DLQ notifications SNS topic"
}
