# ==============================================================================
# Shared Data Sources Outputs
# ==============================================================================

output "account_id" {
  description = "The AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "caller_arn" {
  description = "The ARN of the AWS caller identity"
  value       = data.aws_caller_identity.current.arn
}

output "region_name" {
  description = "The AWS Region name"
  value = data.aws_region.current.region
}

output "region_id" {
  description = "The AWS Region ID (same as name)"
  value       = data.aws_region.current.id
}
