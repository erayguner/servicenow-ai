# ==============================================================================
# Bedrock Knowledge Base Module - Validation Tests
# ==============================================================================
# Tests output validation and data integrity
# ==============================================================================

variables {
  knowledge_base_name = "validation-kb"
  description         = "Validation test knowledge base"
  create_s3_bucket    = true

  tags = {
    Environment = "validation"
  }
}

run "validate_knowledge_base_outputs" {
  command = plan

  assert {
    condition     = output.knowledge_base_id != null
    error_message = "Knowledge base ID output should not be null"
  }

  assert {
    condition     = output.knowledge_base_arn != null
    error_message = "Knowledge base ARN output should not be null"
  }

  assert {
    condition     = can(regex("^arn:aws:bedrock:", output.knowledge_base_arn))
    error_message = "Knowledge base ARN should be a valid Bedrock ARN"
  }
}

run "validate_opensearch_outputs" {
  command = plan

  assert {
    condition     = output.opensearch_collection_arn != null
    error_message = "OpenSearch collection ARN should not be null"
  }

  assert {
    condition     = output.opensearch_collection_endpoint != null
    error_message = "OpenSearch collection endpoint should not be null"
  }
}

run "validate_s3_outputs" {
  command = plan

  assert {
    condition     = output.s3_bucket_name != null
    error_message = "S3 bucket name should not be null"
  }

  assert {
    condition     = output.s3_bucket_arn != null
    error_message = "S3 bucket ARN should not be null"
  }

  assert {
    condition     = can(regex("^arn:aws:s3:::", output.s3_bucket_arn))
    error_message = "S3 bucket ARN should be a valid S3 ARN"
  }
}

run "validate_data_source_outputs" {
  command = plan

  assert {
    condition     = output.data_source_id != null
    error_message = "Data source ID should not be null"
  }
}

run "validate_iam_role_outputs" {
  command = plan

  assert {
    condition     = output.knowledge_base_role_arn != null
    error_message = "Knowledge base role ARN should not be null"
  }

  assert {
    condition     = can(regex("^arn:aws:iam::", output.knowledge_base_role_arn))
    error_message = "Role ARN should be a valid IAM ARN"
  }
}
