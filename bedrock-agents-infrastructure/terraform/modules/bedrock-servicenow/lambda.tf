# Lambda function for ServiceNow integration
# Handles API calls to ServiceNow and agent action execution

# Lambda execution role is defined in iam.tf

# ==============================================================================
# S3 Bucket for Lambda Artifacts
# ==============================================================================

resource "aws_s3_bucket" "lambda_artifacts" {
  bucket        = "${local.name_prefix}-lambda-artifacts-${module.shared_data.account_id}-${local.resource_id}"
  force_destroy = var.environment != "prod"

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-lambda-artifacts"
    }
  )
}

resource "aws_s3_bucket_versioning" "lambda_artifacts" {
  bucket = aws_s3_bucket.lambda_artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "lambda_artifacts" {
  bucket = aws_s3_bucket.lambda_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = local.kms_key_id_normalized != null ? "aws:kms" : "AES256"
      kms_master_key_id = local.kms_key_id_normalized
    }
    bucket_key_enabled = local.kms_key_id_normalized != null
  }
}

resource "aws_s3_bucket_public_access_block" "lambda_artifacts" {
  bucket = aws_s3_bucket.lambda_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "lambda_artifacts" {
  bucket = aws_s3_bucket.lambda_artifacts.id

  rule {
    id     = "cleanup-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# ==============================================================================
# Lambda Code Archives - Placeholder Python Code
# ==============================================================================

# Note: These use the archive_file data source to create ZIP files dynamically.
# The actual Lambda code should be managed in a separate CI/CD process.
# These placeholders allow terraform apply to succeed.

data "archive_file" "servicenow_integration" {
  type        = "zip"
  output_path = "${path.module}/lambda/servicenow-integration.zip"

  source {
    content  = <<-PYTHON
import json
import os
import boto3
from datetime import datetime

def lambda_handler(event, context):
    """ServiceNow integration Lambda handler - placeholder"""
    print(f"Event: {json.dumps(event)}")

    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'ServiceNow integration placeholder',
            'timestamp': datetime.utcnow().isoformat()
        })
    }
PYTHON
    filename = "index.py"
  }
}

data "archive_file" "webhook_processor" {
  type        = "zip"
  output_path = "${path.module}/lambda/webhook-processor.zip"

  source {
    content  = <<-PYTHON
import json
import os
import boto3

def lambda_handler(event, context):
    """Webhook processor Lambda handler - placeholder"""
    print(f"Webhook Event: {json.dumps(event)}")

    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'Webhook received'})
    }
PYTHON
    filename = "index.py"
  }
}

data "archive_file" "knowledge_sync" {
  type        = "zip"
  output_path = "${path.module}/lambda/knowledge-sync.zip"

  source {
    content  = <<-PYTHON
import json
import os
import boto3

def lambda_handler(event, context):
    """Knowledge sync Lambda handler - placeholder"""
    print(f"Sync Event: {json.dumps(event)}")

    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'Knowledge sync completed'})
    }
PYTHON
    filename = "index.py"
  }
}

data "archive_file" "dependencies_layer" {
  type        = "zip"
  output_path = "${path.module}/lambda/layers/servicenow-dependencies.zip"

  source {
    content  = "# Placeholder for dependencies layer"
    filename = "python/lib/python3.12/site-packages/__init__.py"
  }
}

# ==============================================================================
# S3 Objects for Lambda Code (with MD5 hash for change detection)
# ==============================================================================

resource "aws_s3_object" "servicenow_integration" {
  bucket = aws_s3_bucket.lambda_artifacts.id
  key    = "lambda/servicenow-integration.zip"
  source = data.archive_file.servicenow_integration.output_path

  # MD5 hash for change detection
  etag = data.archive_file.servicenow_integration.output_md5
}

resource "aws_s3_object" "webhook_processor" {
  bucket = aws_s3_bucket.lambda_artifacts.id
  key    = "lambda/webhook-processor.zip"
  source = data.archive_file.webhook_processor.output_path

  # MD5 hash for change detection
  etag = data.archive_file.webhook_processor.output_md5
}

resource "aws_s3_object" "knowledge_sync" {
  bucket = aws_s3_bucket.lambda_artifacts.id
  key    = "lambda/knowledge-sync.zip"
  source = data.archive_file.knowledge_sync.output_path

  # MD5 hash for change detection
  etag = data.archive_file.knowledge_sync.output_md5
}

resource "aws_s3_object" "dependencies_layer" {
  bucket = aws_s3_bucket.lambda_artifacts.id
  key    = "layers/servicenow-dependencies.zip"
  source = data.archive_file.dependencies_layer.output_path

  # MD5 hash for change detection
  etag = data.archive_file.dependencies_layer.output_md5
}

# ==============================================================================
# Lambda Layer for dependencies (boto3, requests, etc.)
# ==============================================================================

resource "aws_lambda_layer_version" "servicenow_dependencies" {
  s3_bucket   = aws_s3_bucket.lambda_artifacts.id
  s3_key      = aws_s3_object.dependencies_layer.key
  layer_name  = "${local.name_prefix}-dependencies"
  description = "Dependencies for ServiceNow integration Lambda"

  compatible_runtimes = [var.lambda_runtime]

  # Use MD5 hash for change detection
  source_code_hash = data.archive_file.dependencies_layer.output_base64sha256

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_s3_object.dependencies_layer]
}

# Main ServiceNow integration Lambda function
resource "aws_lambda_function" "servicenow_integration" {
  s3_bucket        = aws_s3_bucket.lambda_artifacts.id
  s3_key           = aws_s3_object.servicenow_integration.key
  function_name    = "${local.name_prefix}-integration-${local.resource_id}"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "index.lambda_handler"
  source_code_hash = data.archive_file.servicenow_integration.output_base64sha256
  runtime          = var.lambda_runtime
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size

  layers = [aws_lambda_layer_version.servicenow_dependencies.arn]

  environment {
    variables = {
      SERVICENOW_INSTANCE_URL       = var.servicenow_instance_url
      SERVICENOW_CREDENTIALS_SECRET = local.servicenow_credentials_secret_arn
      DYNAMODB_TABLE_NAME           = aws_dynamodb_table.servicenow_state.name
      AUTH_TYPE                     = var.servicenow_auth_type
      AUTO_ASSIGNMENT_ENABLED       = var.auto_assignment_enabled
      AUTO_ASSIGNMENT_THRESHOLD     = var.auto_assignment_confidence_threshold
      POWERTOOLS_SERVICE_NAME       = "servicenow-integration"
      LOG_LEVEL                     = var.enable_enhanced_monitoring ? "DEBUG" : "INFO"
    }
  }

  dynamic "vpc_config" {
    for_each = var.vpc_id != null ? [1] : []
    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = var.security_group_ids
    }
  }

  tracing_config {
    mode = "Active"
  }

  reserved_concurrent_executions = 10

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-integration-function"
    }
  )

  depends_on = [
    aws_iam_role_policy_attachment.lambda_execution,
    aws_cloudwatch_log_group.lambda_integration,
    aws_s3_object.servicenow_integration
  ]
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_integration" {
  name              = "/aws/lambda/${local.name_prefix}-integration-${local.resource_id}"
  retention_in_days = 30
  kms_key_id        = local.kms_key_id_normalized

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-lambda-logs"
    }
  )
}

# Lambda permission for Bedrock agents to invoke
resource "aws_lambda_permission" "bedrock_agent_invoke" {
  for_each = local.enabled_agents

  statement_id  = "AllowBedrockAgent-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.servicenow_integration.function_name
  principal     = "bedrock.amazonaws.com"
  source_arn    = "arn:aws:bedrock:${module.shared_data.region_name}:${module.shared_data.account_id}:agent/*"
}

# Lambda permission for API Gateway to invoke
resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.servicenow_integration.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.servicenow_webhooks.execution_arn}/*/*"
}

# Webhook processor Lambda for incoming ServiceNow events
resource "aws_lambda_function" "webhook_processor" {
  s3_bucket        = aws_s3_bucket.lambda_artifacts.id
  s3_key           = aws_s3_object.webhook_processor.key
  function_name    = "${local.name_prefix}-webhook-${local.resource_id}"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "index.lambda_handler"
  source_code_hash = data.archive_file.webhook_processor.output_base64sha256
  runtime          = var.lambda_runtime
  timeout          = 60
  memory_size      = 256

  environment {
    variables = {
      DYNAMODB_TABLE_NAME     = aws_dynamodb_table.servicenow_state.name
      EVENTBRIDGE_BUS_NAME    = aws_cloudwatch_event_bus.servicenow_events.name
      STATE_MACHINE_ARN       = aws_sfn_state_machine.incident_workflow.arn
      POWERTOOLS_SERVICE_NAME = "webhook-processor"
      LOG_LEVEL               = var.enable_enhanced_monitoring ? "DEBUG" : "INFO"
    }
  }

  dynamic "vpc_config" {
    for_each = var.vpc_id != null ? [1] : []
    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = var.security_group_ids
    }
  }

  tracing_config {
    mode = "Active"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-webhook-function"
    }
  )

  depends_on = [
    aws_iam_role_policy_attachment.lambda_execution,
    aws_cloudwatch_log_group.lambda_webhook,
    aws_s3_object.webhook_processor
  ]
}

# CloudWatch Log Group for Webhook Lambda
resource "aws_cloudwatch_log_group" "lambda_webhook" {
  name              = "/aws/lambda/${local.name_prefix}-webhook-${local.resource_id}"
  retention_in_days = 30
  kms_key_id        = local.kms_key_id_normalized

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-webhook-logs"
    }
  )
}

# Knowledge Sync Lambda for scheduled synchronization
resource "aws_lambda_function" "knowledge_sync" {
  count = var.enable_knowledge_sync ? 1 : 0

  s3_bucket        = aws_s3_bucket.lambda_artifacts.id
  s3_key           = aws_s3_object.knowledge_sync.key
  function_name    = "${local.name_prefix}-knowledge-sync-${local.resource_id}"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "index.lambda_handler"
  source_code_hash = data.archive_file.knowledge_sync.output_base64sha256
  runtime          = var.lambda_runtime
  timeout          = 900 # 15 minutes for sync operations
  memory_size      = 1024

  layers = [aws_lambda_layer_version.servicenow_dependencies.arn]

  environment {
    variables = {
      SERVICENOW_INSTANCE_URL       = var.servicenow_instance_url
      SERVICENOW_CREDENTIALS_SECRET = local.servicenow_credentials_secret_arn
      KNOWLEDGE_BASE_IDS            = jsonencode(var.knowledge_base_ids)
      BEDROCK_AGENT_ID              = local.enabled_agents["knowledge"] != null ? module.bedrock_agents["knowledge"].agent_id : ""
      POWERTOOLS_SERVICE_NAME       = "knowledge-sync"
      LOG_LEVEL                     = var.enable_enhanced_monitoring ? "DEBUG" : "INFO"
    }
  }

  dynamic "vpc_config" {
    for_each = var.vpc_id != null ? [1] : []
    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = var.security_group_ids
    }
  }

  tracing_config {
    mode = "Active"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-knowledge-sync-function"
    }
  )

  depends_on = [
    aws_iam_role_policy_attachment.lambda_execution,
    aws_cloudwatch_log_group.lambda_knowledge_sync,
    aws_s3_object.knowledge_sync
  ]
}

# CloudWatch Log Group for Knowledge Sync Lambda
resource "aws_cloudwatch_log_group" "lambda_knowledge_sync" {
  count = var.enable_knowledge_sync ? 1 : 0

  name              = "/aws/lambda/${local.name_prefix}-knowledge-sync-${local.resource_id}"
  retention_in_days = 30
  kms_key_id        = local.kms_key_id_normalized

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-knowledge-sync-logs"
    }
  )
}

# Note: The null_resource.create_lambda_packages has been replaced with:
# - archive_file data sources for creating ZIP files dynamically
# - S3 bucket for storing Lambda artifacts
# - S3 objects with MD5 hash (etag) for change detection
# This approach eliminates the need for local file management and shell scripts.
