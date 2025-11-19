output "lambda_function_arn" {
  description = "The ARN of the Lambda function"
  value       = var.create_lambda_function ? aws_lambda_function.this[0].arn : var.existing_lambda_arn
}

output "lambda_function_name" {
  description = "The name of the Lambda function"
  value       = var.create_lambda_function ? aws_lambda_function.this[0].function_name : null
}

output "lambda_function_invoke_arn" {
  description = "The invoke ARN of the Lambda function"
  value       = var.create_lambda_function ? aws_lambda_function.this[0].invoke_arn : null
}

output "lambda_function_qualified_arn" {
  description = "The qualified ARN of the Lambda function"
  value       = var.create_lambda_function ? aws_lambda_function.this[0].qualified_arn : null
}

output "lambda_function_version" {
  description = "The version of the Lambda function"
  value       = var.create_lambda_function ? aws_lambda_function.this[0].version : null
}

output "lambda_role_arn" {
  description = "The ARN of the Lambda function's IAM role"
  value       = var.create_lambda_function && var.lambda_role_arn == null ? aws_iam_role.lambda[0].arn : var.lambda_role_arn
}

output "lambda_role_name" {
  description = "The name of the Lambda function's IAM role"
  value       = var.create_lambda_function && var.lambda_role_arn == null ? aws_iam_role.lambda[0].name : null
}

output "cloudwatch_log_group_name" {
  description = "The name of the CloudWatch log group for the Lambda function"
  value       = var.create_lambda_function ? aws_cloudwatch_log_group.lambda[0].name : null
}

output "cloudwatch_log_group_arn" {
  description = "The ARN of the CloudWatch log group for the Lambda function"
  value       = var.create_lambda_function ? aws_cloudwatch_log_group.lambda[0].arn : null
}

output "action_group_name" {
  description = "The name of the action group"
  value       = var.action_group_name
}

output "api_schema" {
  description = "The API schema for the action group"
  value       = local.api_schema_content
  sensitive   = true
}
