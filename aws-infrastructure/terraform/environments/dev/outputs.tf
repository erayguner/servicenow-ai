output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = module.rds.db_instance_endpoint
  sensitive   = true
}

output "redis_endpoint" {
  description = "ElastiCache Redis endpoint"
  value       = module.elasticache.redis_endpoint
  sensitive   = true
}

output "s3_bucket_arns" {
  description = "S3 bucket ARNs"
  value       = module.s3.bucket_arns
}

output "dynamodb_table_arns" {
  description = "DynamoDB table ARNs"
  value       = module.dynamodb.table_arns
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "estimated_monthly_cost" {
  description = "Estimated monthly cost in USD"
  value       = "~$50-80/month (with Spot instances and minimal usage)"
}
