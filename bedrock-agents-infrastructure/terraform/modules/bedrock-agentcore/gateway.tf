# ==============================================================================
# AgentCore Gateway
# ==============================================================================
# Gateway with MCP (Model Context Protocol) support
# Supports CUSTOM_JWT and AWS_IAM authorization
# ==============================================================================

# ==============================================================================
# Gateway IAM Role
# ==============================================================================

resource "aws_iam_role" "gateway_role" {
  count = local.create_gateway && var.gateway_role_arn == null ? 1 : 0

  name = "${local.name_prefix}-agentcore-gateway-role-${local.resource_suffix}"

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
            "aws:SourceArn" = "arn:${local.partition}:bedrock-agentcore:${local.region}:${local.account_id}:gateway/*"
          }
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name    = "${local.name_prefix}-agentcore-gateway-role"
      Purpose = "agentcore-gateway"
    }
  )
}

resource "aws_iam_role_policy" "gateway_role_policy" {
  count = local.create_gateway && var.gateway_role_arn == null ? 1 : 0

  name = "${local.name_prefix}-agentcore-gateway-policy"
  role = aws_iam_role.gateway_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        # Lambda function invocation for gateway targets
        {
          Sid    = "LambdaInvocation"
          Effect = "Allow"
          Action = [
            "lambda:InvokeFunction"
          ]
          Resource = var.gateway_lambda_function_arns
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
            "arn:${local.partition}:logs:${local.region}:${local.account_id}:log-group:/aws/bedrock-agentcore/gateway/*"
          ]
        }
      ],
      # KMS access (if encryption key provided)
      var.gateway_kms_key_arn != null ? [
        {
          Sid    = "KMSAccess"
          Effect = "Allow"
          Action = [
            "kms:Decrypt",
            "kms:GenerateDataKey"
          ]
          Resource = [var.gateway_kms_key_arn]
        }
      ] : []
    )
  })
}

# ==============================================================================
# Lambda Permission for Gateway
# ==============================================================================

resource "aws_lambda_permission" "gateway_invoke" {
  for_each = local.create_gateway ? toset(var.gateway_lambda_function_arns) : []

  statement_id  = "AllowAgentCoreGatewayInvoke-${local.resource_suffix}"
  action        = "lambda:InvokeFunction"
  function_name = each.value
  principal     = "bedrock-agentcore.amazonaws.com"
  source_arn    = local.create_gateway ? awscc_bedrockagentcore_gateway.this[0].gateway_arn : null
}

# ==============================================================================
# AgentCore Gateway
# ==============================================================================

resource "awscc_bedrockagentcore_gateway" "this" {
  count = local.create_gateway ? 1 : 0

  name            = "${local.resource_suffix}-${var.gateway_name}"
  description     = var.gateway_description
  role_arn        = var.gateway_role_arn != null ? var.gateway_role_arn : aws_iam_role.gateway_role[0].arn
  authorizer_type = var.gateway_authorizer_type
  protocol_type   = var.gateway_protocol_type
  kms_key_arn     = var.gateway_kms_key_arn

  # CUSTOM_JWT authorizer configuration (requires Cognito)
  authorizer_configuration = var.gateway_authorizer_type == "CUSTOM_JWT" ? {
    custom_jwt_authorizer = {
      discovery_url = local.create_cognito ? "https://cognito-idp.${local.region}.amazonaws.com/${aws_cognito_user_pool.gateway[0].id}" : var.cognito_user_pool_discovery_url
      allowed_audience = local.create_cognito ? [
        aws_cognito_user_pool_client.gateway[0].id
      ] : var.jwt_allowed_audiences
      allowed_clients = local.create_cognito ? [
        aws_cognito_user_pool_client.gateway[0].id
      ] : var.jwt_allowed_clients
    }
  } : null

  # MCP Protocol configuration
  protocol_configuration = var.gateway_protocol_type == "MCP" ? {
    mcp = {
      instructions       = var.gateway_mcp_configuration.instructions
      search_type        = var.gateway_mcp_configuration.search_type
      supported_versions = var.gateway_mcp_configuration.supported_versions
    }
  } : null

  depends_on = [time_sleep.iam_role_propagation]
}

# ==============================================================================
# Gateway Targets - Lambda
# ==============================================================================
# NOTE: Gateway targets are not yet supported by the AWSCC provider (v1.66.0)
# These will be added when the awscc_bedrockagentcore_gateway_target resource
# becomes available.
#
# resource "awscc_bedrockagentcore_gateway_target" "lambda" {
#   for_each = local.create_gateway && var.create_gateway_targets ? {
#     for idx, target in var.gateway_lambda_targets : target.name => target
#   } : {}
#
#   name        = each.value.name
#   description = each.value.description
#   gateway_arn = awscc_bedrockagentcore_gateway.this[0].gateway_arn
#
#   target_configuration = {
#     lambda_target_configuration = {
#       lambda_arn = each.value.lambda_arn
#       tool_schema = {
#         inline_tool_schema = each.value.tool_schema != null ? {
#           tool_schema_type = "INLINE"
#           inline_schema = {
#             name           = each.value.tool_schema.name
#             description    = each.value.tool_schema.description
#             input_schema   = each.value.tool_schema.input_schema
#             output_schema  = each.value.tool_schema.output_schema
#           }
#         } : null
#         s3_tool_schema = each.value.s3_tool_schema != null ? {
#           tool_schema_type = "S3"
#           s3_schema = {
#             s3_bucket_name = each.value.s3_tool_schema.bucket
#             s3_object_key  = each.value.s3_tool_schema.key
#           }
#         } : null
#       }
#     }
#   }
#
#   depends_on = [awscc_bedrockagentcore_gateway.this]
# }

# ==============================================================================
# Gateway Targets - MCP Server
# ==============================================================================
# NOTE: Gateway targets are not yet supported by the AWSCC provider (v1.66.0)
#
# resource "awscc_bedrockagentcore_gateway_target" "mcp_server" {
#   for_each = local.create_gateway && var.create_gateway_targets ? {
#     for idx, target in var.gateway_mcp_server_targets : target.name => target
#   } : {}
#
#   name        = each.value.name
#   description = each.value.description
#   gateway_arn = awscc_bedrockagentcore_gateway.this[0].gateway_arn
#
#   target_configuration = {
#     mcp_gateway_target_configuration = {
#       lambda_arn = each.value.lambda_arn
#     }
#   }
#
#   depends_on = [awscc_bedrockagentcore_gateway.this]
# }

# ==============================================================================
# CloudWatch Log Group for Gateway
# ==============================================================================

resource "aws_cloudwatch_log_group" "gateway" {
  count = local.create_gateway ? 1 : 0

  name              = "/aws/bedrock-agentcore/gateway/${local.name_prefix}-${var.gateway_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.gateway_kms_key_arn

  tags = merge(
    local.common_tags,
    {
      Name    = "${local.name_prefix}-gateway-logs"
      Purpose = "agentcore-gateway-logs"
    }
  )
}
