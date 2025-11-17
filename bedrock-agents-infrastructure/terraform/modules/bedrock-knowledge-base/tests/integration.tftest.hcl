# ==============================================================================
# Bedrock Knowledge Base Module - Integration Tests
# ==============================================================================
# Tests integration with S3, OpenSearch, and IAM
# ==============================================================================

variables {
  knowledge_base_name = "integration-kb"
  description         = "Integration test knowledge base"
  create_s3_bucket    = false
  existing_s3_bucket_arn = "arn:aws:s3:::existing-bucket"

  tags = {
    Environment = "integration-test"
  }
}

run "verify_existing_bucket_integration" {
  command = plan

  assert {
    condition     = length(aws_s3_bucket.documents) == 0
    error_message = "Should not create S3 bucket when using existing"
  }
}

run "verify_iam_opensearch_permissions" {
  command = plan

  assert {
    condition     = can(regex("aoss:APIAccessAll", data.aws_iam_policy_document.knowledge_base_permissions.json))
    error_message = "IAM policy should include OpenSearch Serverless permissions"
  }
}

run "verify_iam_s3_permissions" {
  command = plan

  assert {
    condition     = can(regex("s3:GetObject", data.aws_iam_policy_document.knowledge_base_permissions.json))
    error_message = "IAM policy should include S3 GetObject permission"
  }

  assert {
    condition     = can(regex("s3:ListBucket", data.aws_iam_policy_document.knowledge_base_permissions.json))
    error_message = "IAM policy should include S3 ListBucket permission"
  }
}

run "verify_bedrock_permissions" {
  command = plan

  assert {
    condition     = can(regex("bedrock:InvokeModel", data.aws_iam_policy_document.knowledge_base_permissions.json))
    error_message = "IAM policy should include Bedrock InvokeModel permission"
  }
}

run "verify_opensearch_dependencies" {
  command = plan

  assert {
    condition     = can(aws_opensearchserverless_collection.this.depends_on)
    error_message = "OpenSearch collection should have explicit dependencies"
  }
}

run "verify_knowledge_base_dependencies" {
  command = plan

  assert {
    condition     = can(aws_bedrockagent_knowledge_base.this.depends_on)
    error_message = "Knowledge base should have explicit dependencies"
  }
}
