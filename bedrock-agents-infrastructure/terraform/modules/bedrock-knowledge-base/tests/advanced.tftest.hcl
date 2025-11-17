# ==============================================================================
# Bedrock Knowledge Base Module - Advanced Tests
# ==============================================================================
# Tests advanced features including encryption, VPC, and chunking strategies
# ==============================================================================

variables {
  knowledge_base_name = "advanced-kb"
  description         = "Advanced knowledge base with custom configuration"
  create_s3_bucket    = true

  enable_versioning            = true
  enable_server_side_encryption = true
  kms_key_id                   = "12345678-1234-1234-1234-123456789012"

  chunking_strategy    = "FIXED_SIZE"
  max_tokens          = 512
  overlap_percentage  = 20

  vector_dimension    = 1536

  tags = {
    Environment = "advanced-test"
  }
}

run "verify_s3_versioning" {
  command = plan

  assert {
    condition     = length(aws_s3_bucket_versioning.documents) == 1
    error_message = "S3 versioning should be enabled"
  }

  assert {
    condition     = can(aws_s3_bucket_versioning.documents[0].versioning_configuration[0].status == "Enabled")
    error_message = "Versioning status should be Enabled"
  }
}

run "verify_s3_encryption" {
  command = plan

  assert {
    condition     = length(aws_s3_bucket_server_side_encryption_configuration.documents) == 1
    error_message = "S3 encryption should be configured"
  }

  assert {
    condition     = can(aws_s3_bucket_server_side_encryption_configuration.documents[0].rule[0].apply_server_side_encryption_by_default[0].sse_algorithm == "aws:kms")
    error_message = "Should use KMS encryption"
  }
}

run "verify_s3_public_access_block" {
  command = plan

  assert {
    condition     = length(aws_s3_bucket_public_access_block.documents) == 1
    error_message = "Public access block should be configured"
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.documents[0].block_public_acls == true
    error_message = "Should block public ACLs"
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.documents[0].restrict_public_buckets == true
    error_message = "Should restrict public buckets"
  }
}

run "verify_opensearch_security_policies" {
  command = plan

  assert {
    condition     = aws_opensearchserverless_security_policy.encryption.type == "encryption"
    error_message = "Encryption policy should be configured"
  }

  assert {
    condition     = aws_opensearchserverless_security_policy.network.type == "network"
    error_message = "Network policy should be configured"
  }

  assert {
    condition     = aws_opensearchserverless_access_policy.data_access.type == "data"
    error_message = "Data access policy should be configured"
  }
}

run "verify_chunking_configuration" {
  command = plan

  assert {
    condition     = can(aws_bedrockagent_data_source.this.vector_ingestion_configuration[0].chunking_configuration[0].chunking_strategy == "FIXED_SIZE")
    error_message = "Chunking strategy should be FIXED_SIZE"
  }

  assert {
    condition     = can(aws_bedrockagent_data_source.this.vector_ingestion_configuration[0].chunking_configuration[0].fixed_size_chunking_configuration[0].max_tokens == 512)
    error_message = "Max tokens should be 512"
  }
}

run "verify_embeddings_configuration" {
  command = plan

  assert {
    condition     = can(aws_bedrockagent_knowledge_base.this.knowledge_base_configuration[0].vector_knowledge_base_configuration[0].embedding_model_configuration[0].bedrock_embedding_model_configuration[0].dimensions == 1536)
    error_message = "Vector dimensions should be 1536"
  }
}

run "verify_kms_permissions" {
  command = plan

  assert {
    condition     = can(regex("kms:Decrypt", data.aws_iam_policy_document.knowledge_base_permissions.json))
    error_message = "IAM policy should include KMS decrypt permissions"
  }
}
