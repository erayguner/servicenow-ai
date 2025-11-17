# AWS SNS + SQS Module - 2025 Best Practices
# Equivalent to GCP Pub/Sub

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# SNS Topics (equivalent to Pub/Sub topics)
resource "aws_sns_topic" "main" {
  for_each = { for topic in var.topics : topic.name => topic }

  name              = each.value.name
  kms_master_key_id = var.kms_key_arn
  fifo_topic        = each.value.fifo

  tags = merge(var.tags, { Name = each.value.name })
}

# SQS Queues (subscribers to SNS topics)
resource "aws_sqs_queue" "main" {
  for_each = { for topic in var.topics : topic.name => topic }

  name                              = "${each.value.name}-queue"
  delay_seconds                     = 0
  max_message_size                  = 262144
  message_retention_seconds         = each.value.message_retention_seconds
  receive_wait_time_seconds         = 20
  fifo_queue                        = each.value.fifo
  kms_master_key_id                 = var.kms_key_arn
  kms_data_key_reuse_period_seconds = 300

  tags = merge(var.tags, { Name = "${each.value.name}-queue" })
}

# Dead Letter Queue
resource "aws_sqs_queue" "dlq" {
  name                      = "dead-letter-queue"
  message_retention_seconds = 1209600
  kms_master_key_id         = var.kms_key_arn

  tags = merge(var.tags, { Name = "dead-letter-queue" })
}

# Subscribe SQS to SNS
resource "aws_sns_topic_subscription" "main" {
  for_each = { for topic in var.topics : topic.name => topic }

  topic_arn = aws_sns_topic.main[each.key].arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.main[each.key].arn
}

# SQS Queue Policy to allow SNS
resource "aws_sqs_queue_policy" "main" {
  for_each = { for topic in var.topics : topic.name => topic }

  queue_url = aws_sqs_queue.main[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "sns.amazonaws.com"
      }
      Action   = "sqs:SendMessage"
      Resource = aws_sqs_queue.main[each.key].arn
      Condition = {
        ArnEquals = {
          "aws:SourceArn" = aws_sns_topic.main[each.key].arn
        }
      }
    }]
  })
}
