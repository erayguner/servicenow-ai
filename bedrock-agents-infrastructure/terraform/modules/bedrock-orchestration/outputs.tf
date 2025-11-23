output "state_machine_id" {
  description = "The ID of the Step Functions state machine"
  value       = aws_sfn_state_machine.this.id
}

output "state_machine_arn" {
  description = "The ARN of the Step Functions state machine"
  value       = aws_sfn_state_machine.this.arn
}

output "state_machine_name" {
  description = "The name of the Step Functions state machine"
  value       = aws_sfn_state_machine.this.name
}

output "state_machine_role_arn" {
  description = "The ARN of the IAM role for the Step Functions state machine"
  value       = aws_iam_role.state_machine.arn
}

output "state_machine_creation_date" {
  description = "The creation date of the Step Functions state machine"
  value       = aws_sfn_state_machine.this.creation_date
}

output "dynamodb_table_name" {
  description = "The name of the DynamoDB table for state management"
  value       = var.create_dynamodb_table ? aws_dynamodb_table.state[0].name : null
}

output "dynamodb_table_arn" {
  description = "The ARN of the DynamoDB table for state management"
  value       = var.create_dynamodb_table ? aws_dynamodb_table.state[0].arn : null
}

output "sns_topic_arn" {
  description = "The ARN of the SNS topic for notifications"
  value       = var.enable_sns_notifications ? aws_sns_topic.notifications[0].arn : null
}

output "eventbridge_rule_arn" {
  description = "The ARN of the EventBridge rule for triggering"
  value       = var.enable_eventbridge_trigger ? aws_cloudwatch_event_rule.trigger[0].arn : null
}

output "log_group_name" {
  description = "The name of the CloudWatch log group for the state machine"
  value       = var.enable_logging ? aws_cloudwatch_log_group.state_machine[0].name : null
}

output "log_group_arn" {
  description = "The ARN of the CloudWatch log group for the state machine"
  value       = var.enable_logging ? aws_cloudwatch_log_group.state_machine[0].arn : null
}
