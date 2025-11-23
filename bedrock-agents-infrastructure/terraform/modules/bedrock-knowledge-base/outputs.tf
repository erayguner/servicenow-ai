output "knowledge_base_id" {
  description = "The ID of the knowledge base"
  value       = aws_bedrockagent_knowledge_base.this.id
}

output "knowledge_base_arn" {
  description = "The ARN of the knowledge base"
  value       = aws_bedrockagent_knowledge_base.this.arn
}

output "knowledge_base_name" {
  description = "The name of the knowledge base"
  value       = aws_bedrockagent_knowledge_base.this.name
}

output "knowledge_base_role_arn" {
  description = "The ARN of the IAM role for the knowledge base"
  value       = aws_iam_role.knowledge_base.arn
}

output "opensearch_collection_arn" {
  description = "The ARN of the OpenSearch Serverless collection"
  value       = aws_opensearchserverless_collection.this.arn
}

output "opensearch_collection_endpoint" {
  description = "The endpoint of the OpenSearch Serverless collection"
  value       = aws_opensearchserverless_collection.this.collection_endpoint
}

output "opensearch_dashboard_endpoint" {
  description = "The dashboard endpoint of the OpenSearch Serverless collection"
  value       = aws_opensearchserverless_collection.this.dashboard_endpoint
}

output "s3_bucket_name" {
  description = "The name of the S3 bucket for documents"
  value       = var.create_s3_bucket ? aws_s3_bucket.documents[0].id : null
}

output "s3_bucket_arn" {
  description = "The ARN of the S3 bucket for documents"
  value       = local.s3_bucket_arn
}

output "data_source_id" {
  description = "The ID of the data source"
  value       = aws_bedrockagent_data_source.this.id
}

output "data_source_status" {
  description = "The status of the data source"
  value       = aws_bedrockagent_data_source.this.data_source_status
}

output "vector_index_name" {
  description = "The name of the vector index in OpenSearch"
  value       = var.opensearch_index_name
}

output "embedding_model_arn" {
  description = "The ARN of the embedding model"
  value       = local.embedding_model_arn
}
