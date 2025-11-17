output "sns_topic_arns" {
  value = { for k, v in aws_sns_topic.main : k => v.arn }
}

output "sqs_queue_urls" {
  value = { for k, v in aws_sqs_queue.main : k => v.url }
}

output "sqs_queue_arns" {
  value = { for k, v in aws_sqs_queue.main : k => v.arn }
}

output "dlq_url" {
  value = aws_sqs_queue.dlq.url
}
