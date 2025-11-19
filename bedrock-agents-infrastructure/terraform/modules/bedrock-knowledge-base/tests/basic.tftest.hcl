# ==============================================================================
# Bedrock Knowledge Base Module - Basic Tests
# ==============================================================================
# Tests basic functionality of the knowledge base module
# ==============================================================================

variables {
  knowledge_base_name = "test-kb"
  description         = "Test knowledge base"
  create_s3_bucket    = true

  tags = {
    Environment = "test"
  }
}

run "verify_knowledge_base_creation" {
  command = plan

  assert {
    condition     = aws_bedrockagent_knowledge_base.this.name == "test-kb"
    error_message = "Knowledge base name should match input"
  }

  assert {
    condition     = can(aws_bedrockagent_knowledge_base.this.knowledge_base_configuration[0].type == "VECTOR")
    error_message = "Knowledge base should be VECTOR type"
  }
}

run "verify_s3_bucket_creation" {
  command = plan

  assert {
    condition     = length(aws_s3_bucket.documents) == 1
    error_message = "Should create one S3 bucket"
  }

  assert {
    condition     = can(regex("test-kb-documents", aws_s3_bucket.documents[0].bucket))
    error_message = "S3 bucket name should contain knowledge base name"
  }
}

run "verify_opensearch_collection" {
  command = plan

  assert {
    condition     = aws_opensearchserverless_collection.this.type == "VECTORSEARCH"
    error_message = "Collection type should be VECTORSEARCH"
  }

  assert {
    condition     = aws_opensearchserverless_collection.this.standby_replicas == "ENABLED"
    error_message = "Standby replicas should be enabled by default"
  }
}

run "verify_iam_role" {
  command = plan

  assert {
    condition     = can(regex("test-kb-kb-role", aws_iam_role.knowledge_base.name))
    error_message = "IAM role name should match expected format"
  }
}

run "verify_data_source" {
  command = plan

  assert {
    condition     = can(aws_bedrockagent_data_source.this.data_source_configuration[0].type == "S3")
    error_message = "Data source type should be S3"
  }
}
