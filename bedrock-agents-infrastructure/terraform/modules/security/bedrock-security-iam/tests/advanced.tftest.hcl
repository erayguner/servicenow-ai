# ==============================================================================
# Security IAM Module - Advanced Tests
# ==============================================================================

variables {
  project_name = "advanced-project"
  environment  = "prod"
  aws_region   = "us-east-1"

  allowed_bedrock_models    = ["arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-v2"]
  knowledge_base_arns       = ["arn:aws:bedrock:us-east-1:123456789012:knowledge-base/KB123"]
  dynamodb_table_arns       = ["arn:aws:dynamodb:us-east-1:123456789012:table/test-table"]
  kms_key_arns              = ["arn:aws:kms:us-east-1:123456789012:key/12345"]
  sns_topic_arn             = "arn:aws:sns:us-east-1:123456789012:alarms"
  cloudtrail_log_group_name = "/aws/cloudtrail/advanced"

  enable_permission_boundary  = true
  enable_step_functions       = true
  enable_cross_account_access = true
  trusted_account_ids         = ["123456789012"]
  external_id                 = "test-external-id"
  allowed_regions             = ["us-east-1", "us-west-2"]

  tags = {
    Environment = "prod"
  }
}

run "verify_permission_boundary" {
  command = plan

  assert {
    condition     = length(aws_iam_policy.permission_boundary) == 1
    error_message = "Should create permission boundary policy"
  }

  assert {
    condition     = can(regex("RegionRestriction", data.aws_iam_policy_document.permission_boundary[0].json))
    error_message = "Permission boundary should include region restriction"
  }
}

run "verify_step_functions_role" {
  command = plan

  assert {
    condition     = length(aws_iam_role.step_functions_execution) == 1
    error_message = "Should create Step Functions execution role"
  }
}

run "verify_cross_account_role" {
  command = plan

  assert {
    condition     = length(aws_iam_role.cross_account_access) == 1
    error_message = "Should create cross-account access role"
  }

  assert {
    condition     = can(regex("sts:ExternalId", data.aws_iam_policy_document.cross_account_assume[0].json))
    error_message = "Cross-account role should require external ID"
  }
}

run "verify_abac_implementation" {
  command = plan

  assert {
    condition     = can(regex("dynamodb:ResourceTag/Environment", data.aws_iam_policy_document.lambda_bedrock_access.json))
    error_message = "Should implement ABAC for DynamoDB"
  }

  assert {
    condition     = can(regex("s3:ResourceTag/Environment", data.aws_iam_policy_document.lambda_bedrock_access.json))
    error_message = "Should implement ABAC for S3"
  }
}
