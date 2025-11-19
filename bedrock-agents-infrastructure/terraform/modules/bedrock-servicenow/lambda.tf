# Lambda function for ServiceNow integration
# Handles API calls to ServiceNow and agent action execution

# Lambda execution role is defined in iam.tf

# Lambda Layer for dependencies (boto3, requests, etc.)
resource "aws_lambda_layer_version" "servicenow_dependencies" {
  filename            = "${path.module}/lambda/layers/servicenow-dependencies.zip"
  layer_name          = "${local.name_prefix}-dependencies"
  description         = "Dependencies for ServiceNow integration Lambda"
  compatible_runtimes = [var.lambda_runtime]

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [filename]
  }
}

# Main ServiceNow integration Lambda function
resource "aws_lambda_function" "servicenow_integration" {
  filename         = "${path.module}/lambda/servicenow-integration.zip"
  function_name    = "${local.name_prefix}-integration-${local.resource_id}"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "index.lambda_handler"
  source_code_hash = fileexists("${path.module}/lambda/servicenow-integration.zip") ? filebase64sha256("${path.module}/lambda/servicenow-integration.zip") : null
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

  lifecycle {
    ignore_changes = [filename, source_code_hash]
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_execution,
    aws_cloudwatch_log_group.lambda_integration
  ]
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_integration" {
  name              = "/aws/lambda/${local.name_prefix}-integration-${local.resource_id}"
  retention_in_days = 30
  kms_key_id        = var.kms_key_id

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
  source_arn    = "arn:aws:bedrock:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:agent/*"
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
  filename         = "${path.module}/lambda/webhook-processor.zip"
  function_name    = "${local.name_prefix}-webhook-${local.resource_id}"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "index.lambda_handler"
  source_code_hash = fileexists("${path.module}/lambda/webhook-processor.zip") ? filebase64sha256("${path.module}/lambda/webhook-processor.zip") : null
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

  lifecycle {
    ignore_changes = [filename, source_code_hash]
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_execution,
    aws_cloudwatch_log_group.lambda_webhook
  ]
}

# CloudWatch Log Group for Webhook Lambda
resource "aws_cloudwatch_log_group" "lambda_webhook" {
  name              = "/aws/lambda/${local.name_prefix}-webhook-${local.resource_id}"
  retention_in_days = 30
  kms_key_id        = var.kms_key_id

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

  filename         = "${path.module}/lambda/knowledge-sync.zip"
  function_name    = "${local.name_prefix}-knowledge-sync-${local.resource_id}"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "index.lambda_handler"
  source_code_hash = fileexists("${path.module}/lambda/knowledge-sync.zip") ? filebase64sha256("${path.module}/lambda/knowledge-sync.zip") : null
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

  lifecycle {
    ignore_changes = [filename, source_code_hash]
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_execution,
    aws_cloudwatch_log_group.lambda_knowledge_sync
  ]
}

# CloudWatch Log Group for Knowledge Sync Lambda
resource "aws_cloudwatch_log_group" "lambda_knowledge_sync" {
  count = var.enable_knowledge_sync ? 1 : 0

  name              = "/aws/lambda/${local.name_prefix}-knowledge-sync-${local.resource_id}"
  retention_in_days = 30
  kms_key_id        = var.kms_key_id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-knowledge-sync-logs"
    }
  )
}

# Create placeholder Lambda deployment packages if they don't exist
resource "null_resource" "create_lambda_packages" {
  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ${path.module}/lambda/layers

      # Create servicenow-integration.zip if it doesn't exist
      if [ ! -f ${path.module}/lambda/servicenow-integration.zip ]; then
        echo 'Creating placeholder servicenow-integration.zip'
        mkdir -p /tmp/servicenow-integration
        cat > /tmp/servicenow-integration/index.py << 'EOF'
import json
import os
import boto3
from datetime import datetime

def lambda_handler(event, context):
    """ServiceNow integration Lambda handler"""
    print(f"Event: {json.dumps(event)}")

    # This is a placeholder - implement actual ServiceNow API integration
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'ServiceNow integration placeholder',
            'timestamp': datetime.utcnow().isoformat()
        })
    }
EOF
        cd /tmp/servicenow-integration && zip -r ${path.module}/lambda/servicenow-integration.zip .
        rm -rf /tmp/servicenow-integration
      fi

      # Create webhook-processor.zip if it doesn't exist
      if [ ! -f ${path.module}/lambda/webhook-processor.zip ]; then
        echo 'Creating placeholder webhook-processor.zip'
        mkdir -p /tmp/webhook-processor
        cat > /tmp/webhook-processor/index.py << 'EOF'
import json
import os
import boto3

def lambda_handler(event, context):
    """Webhook processor Lambda handler"""
    print(f"Webhook Event: {json.dumps(event)}")

    # This is a placeholder - implement actual webhook processing
    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'Webhook received'})
    }
EOF
        cd /tmp/webhook-processor && zip -r ${path.module}/lambda/webhook-processor.zip .
        rm -rf /tmp/webhook-processor
      fi

      # Create knowledge-sync.zip if it doesn't exist
      if [ ! -f ${path.module}/lambda/knowledge-sync.zip ]; then
        echo 'Creating placeholder knowledge-sync.zip'
        mkdir -p /tmp/knowledge-sync
        cat > /tmp/knowledge-sync/index.py << 'EOF'
import json
import os
import boto3

def lambda_handler(event, context):
    """Knowledge sync Lambda handler"""
    print(f"Sync Event: {json.dumps(event)}")

    # This is a placeholder - implement actual knowledge sync
    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'Knowledge sync completed'})
    }
EOF
        cd /tmp/knowledge-sync && zip -r ${path.module}/lambda/knowledge-sync.zip .
        rm -rf /tmp/knowledge-sync
      fi

      # Create dependencies layer if it doesn't exist
      if [ ! -f ${path.module}/lambda/layers/servicenow-dependencies.zip ]; then
        echo 'Creating placeholder dependencies layer'
        mkdir -p /tmp/python/lib/python3.12/site-packages
        touch /tmp/python/lib/python3.12/site-packages/__init__.py
        cd /tmp && zip -r ${path.module}/lambda/layers/servicenow-dependencies.zip python
        rm -rf /tmp/python
      fi
    EOT
  }

  triggers = {
    always_run = timestamp()
  }
}
