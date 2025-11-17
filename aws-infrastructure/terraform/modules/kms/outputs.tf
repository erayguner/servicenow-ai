output "key_ids" {
  description = "Map of key names to key IDs"
  value       = { for k, v in aws_kms_key.main : k => v.key_id }
}

output "key_arns" {
  description = "Map of key names to key ARNs"
  value       = { for k, v in aws_kms_key.main : k => v.arn }
}
