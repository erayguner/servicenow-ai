output "table_ids" {
  description = "Map of table names to IDs"
  value       = { for k, v in aws_dynamodb_table.main : k => v.id }
}

output "table_arns" {
  description = "Map of table names to ARNs"
  value       = { for k, v in aws_dynamodb_table.main : k => v.arn }
}

output "table_stream_arns" {
  description = "Map of table names to stream ARNs"
  value       = { for k, v in aws_dynamodb_table.main : k => v.stream_arn if v.stream_enabled }
}
