# ==============================================================================
# AgentCore Runtime
# ==============================================================================
# Supports container-based and code-based runtime deployments
# ==============================================================================

# ==============================================================================
# Runtime IAM Role
# ==============================================================================

resource "aws_iam_role" "runtime_role" {
  count = local.create_runtime && var.runtime_role_arn == null ? 1 : 0

  name = "${local.name_prefix}-agentcore-runtime-role-${local.resource_suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "bedrock-agentcore.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:${local.partition}:bedrock-agentcore:${local.region}:${local.account_id}:runtime/*"
          }
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name    = "${local.name_prefix}-agentcore-runtime-role"
      Purpose = "agentcore-runtime"
    }
  )
}

resource "aws_iam_role_policy" "runtime_role_policy" {
  count = local.create_runtime && var.runtime_role_arn == null ? 1 : 0

  name = "${local.name_prefix}-agentcore-runtime-policy"
  role = aws_iam_role.runtime_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        # Bedrock model invocation
        {
          Sid    = "BedrockModelInvocation"
          Effect = "Allow"
          Action = [
            "bedrock:InvokeModel",
            "bedrock:InvokeModelWithResponseStream"
          ]
          Resource = var.runtime_allowed_model_arns
        },
        # CloudWatch Logs
        {
          Sid    = "CloudWatchLogs"
          Effect = "Allow"
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          Resource = [
            "arn:${local.partition}:logs:${local.region}:${local.account_id}:log-group:/aws/bedrock-agentcore/runtime/*"
          ]
        },
        # X-Ray tracing
        {
          Sid    = "XRayTracing"
          Effect = "Allow"
          Action = [
            "xray:PutTraceSegments",
            "xray:PutTelemetryRecords"
          ]
          Resource = ["*"]
        }
      ],
      # Memory access permissions (if memory is enabled)
      local.create_memory ? [
        {
          Sid    = "MemoryAccess"
          Effect = "Allow"
          Action = concat(
            local.all_memory_write_perms,
            local.all_memory_read_perms,
            local.all_memory_update_perms
          )
          Resource = [
            "arn:${local.partition}:bedrock-agentcore:${local.region}:${local.account_id}:memory/*"
          ]
        }
      ] : [],
      # Gateway access permissions (if gateway is enabled)
      local.create_gateway ? [
        {
          Sid    = "GatewayAccess"
          Effect = "Allow"
          Action = [
            "bedrock-agentcore:InvokeGateway",
            "bedrock-agentcore:ListGatewayTargets"
          ]
          Resource = [
            "arn:${local.partition}:bedrock-agentcore:${local.region}:${local.account_id}:gateway/*"
          ]
        }
      ] : [],
      # Code interpreter permissions (if enabled)
      local.create_code_interpreter ? [
        {
          Sid    = "CodeInterpreterAccess"
          Effect = "Allow"
          Action = [
            "bedrock-agentcore:InvokeCodeInterpreter"
          ]
          Resource = [
            "arn:${local.partition}:bedrock-agentcore:${local.region}:${local.account_id}:code-interpreter/*"
          ]
        }
      ] : [],
      # KMS access (if encryption key provided)
      var.runtime_kms_key_arn != null ? [
        {
          Sid    = "KMSAccess"
          Effect = "Allow"
          Action = [
            "kms:Decrypt",
            "kms:GenerateDataKey"
          ]
          Resource = [var.runtime_kms_key_arn]
        }
      ] : []
    )
  })
}

# ==============================================================================
# AgentCore Runtime - Container Based
# ==============================================================================

resource "awscc_bedrockagentcore_runtime" "container" {
  count = local.create_runtime && var.runtime_artifact_type == "container" ? 1 : 0

  agent_runtime_name = "${local.resource_suffix}_${local.sanitized_runtime_name}"
  description        = var.runtime_description
  role_arn           = var.runtime_role_arn != null ? var.runtime_role_arn : aws_iam_role.runtime_role[0].arn

  agent_runtime_artifact = {
    container_configuration = {
      container_uri = var.runtime_container_uri
    }
  }

  network_configuration = {
    network_mode = var.runtime_network_mode
  }

  depends_on = [time_sleep.iam_role_propagation]
}

# ==============================================================================
# AgentCore Runtime - Code Based
# ==============================================================================

resource "awscc_bedrockagentcore_runtime" "code" {
  count = local.create_runtime && var.runtime_artifact_type == "code" ? 1 : 0

  agent_runtime_name = "${local.resource_suffix}_${local.sanitized_runtime_name}"
  description        = var.runtime_description
  role_arn           = var.runtime_role_arn != null ? var.runtime_role_arn : aws_iam_role.runtime_role[0].arn

  agent_runtime_artifact = {
    s3_code_artifact = {
      s3_bucket_name = var.runtime_code_s3_bucket
      s3_object_key  = var.runtime_code_s3_key
    }
  }

  network_configuration = {
    network_mode = var.runtime_network_mode
  }

  depends_on = [time_sleep.iam_role_propagation]
}

# ==============================================================================
# CloudWatch Log Group for Runtime
# ==============================================================================

resource "aws_cloudwatch_log_group" "runtime" {
  count = local.create_runtime ? 1 : 0

  name              = "/aws/bedrock-agentcore/runtime/${local.name_prefix}-${var.runtime_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.runtime_kms_key_arn

  tags = merge(
    local.common_tags,
    {
      Name    = "${local.name_prefix}-runtime-logs"
      Purpose = "agentcore-runtime-logs"
    }
  )
}
