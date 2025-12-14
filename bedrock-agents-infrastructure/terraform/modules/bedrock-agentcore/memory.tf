# ==============================================================================
# AgentCore Memory
# ==============================================================================
# Memory with semantic, summary, and user preference strategies
# Supports Short-Term Memory (STM) and Long-Term Memory (LTM)
# ==============================================================================

# ==============================================================================
# Memory IAM Role
# ==============================================================================

resource "aws_iam_role" "memory_role" {
  count = local.create_memory && var.memory_role_arn == null ? 1 : 0

  name = "${local.name_prefix}-agentcore-memory-role-${local.resource_suffix}"

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
            "aws:SourceArn" = "arn:${local.partition}:bedrock-agentcore:${local.region}:${local.account_id}:memory/*"
          }
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name    = "${local.name_prefix}-agentcore-memory-role"
      Purpose = "agentcore-memory"
    }
  )
}

resource "aws_iam_role_policy" "memory_role_policy" {
  count = local.create_memory && var.memory_role_arn == null ? 1 : 0

  name = "${local.name_prefix}-agentcore-memory-policy"
  role = aws_iam_role.memory_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        # Bedrock model invocation for memory strategies
        {
          Sid    = "BedrockModelInvocation"
          Effect = "Allow"
          Action = [
            "bedrock:InvokeModel",
            "bedrock:InvokeModelWithResponseStream"
          ]
          Resource = var.memory_allowed_model_arns
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
            "arn:${local.partition}:logs:${local.region}:${local.account_id}:log-group:/aws/bedrock-agentcore/memory/*"
          ]
        }
      ],
      # KMS access (if encryption key provided)
      var.memory_kms_key_arn != null ? [
        {
          Sid    = "KMSAccess"
          Effect = "Allow"
          Action = [
            "kms:Decrypt",
            "kms:GenerateDataKey",
            "kms:DescribeKey"
          ]
          Resource = [var.memory_kms_key_arn]
        }
      ] : []
    )
  })
}

# ==============================================================================
# AgentCore Memory
# ==============================================================================

resource "awscc_bedrockagentcore_memory" "this" {
  count = local.create_memory ? 1 : 0

  name                      = "${local.resource_suffix}_${local.sanitized_memory_name}"
  description               = var.memory_description
  event_expiry_duration     = var.memory_event_expiry_duration
  encryption_key_arn        = var.memory_kms_key_arn
  memory_execution_role_arn = var.memory_role_arn != null ? var.memory_role_arn : aws_iam_role.memory_role[0].arn

  # Memory strategies configuration
  memory_strategies = [
    for strategy in var.memory_strategies : {
      # Semantic Memory Strategy
      semantic_memory_strategy = strategy.semantic_memory_strategy != null ? {
        name        = strategy.semantic_memory_strategy.name
        description = strategy.semantic_memory_strategy.description
        namespaces  = strategy.semantic_memory_strategy.namespaces
        model_id    = strategy.semantic_memory_strategy.model_id
      } : null

      # Summary Memory Strategy
      summary_memory_strategy = strategy.summary_memory_strategy != null ? {
        name        = strategy.summary_memory_strategy.name
        description = strategy.summary_memory_strategy.description
        namespaces  = strategy.summary_memory_strategy.namespaces
        model_id    = strategy.summary_memory_strategy.model_id
      } : null

      # User Preference Memory Strategy
      user_preference_memory_strategy = strategy.user_preference_memory_strategy != null ? {
        name        = strategy.user_preference_memory_strategy.name
        description = strategy.user_preference_memory_strategy.description
        namespaces  = strategy.user_preference_memory_strategy.namespaces
        model_id    = strategy.user_preference_memory_strategy.model_id
      } : null

      # Custom Memory Strategy
      custom_memory_strategy = strategy.custom_memory_strategy != null ? {
        name          = strategy.custom_memory_strategy.name
        description   = strategy.custom_memory_strategy.description
        namespaces    = strategy.custom_memory_strategy.namespaces
        configuration = strategy.custom_memory_strategy.configuration
      } : null
    }
  ]

  depends_on = [time_sleep.iam_role_propagation]
}

# ==============================================================================
# CloudWatch Log Group for Memory
# ==============================================================================

resource "aws_cloudwatch_log_group" "memory" {
  count = local.create_memory ? 1 : 0

  name              = "/aws/bedrock-agentcore/memory/${local.name_prefix}-${var.memory_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.memory_kms_key_arn

  tags = merge(
    local.common_tags,
    {
      Name    = "${local.name_prefix}-memory-logs"
      Purpose = "agentcore-memory-logs"
    }
  )
}

# ==============================================================================
# Memory Access Policy Documents (for external consumers)
# ==============================================================================

data "aws_iam_policy_document" "memory_stm_read" {
  count = local.create_memory ? 1 : 0

  statement {
    sid    = "STMReadAccess"
    effect = "Allow"

    actions = local.stm_read_perms

    resources = [
      awscc_bedrockagentcore_memory.this[0].memory_arn
    ]
  }
}

data "aws_iam_policy_document" "memory_stm_write" {
  count = local.create_memory ? 1 : 0

  statement {
    sid    = "STMWriteAccess"
    effect = "Allow"

    actions = local.stm_write_perms

    resources = [
      awscc_bedrockagentcore_memory.this[0].memory_arn
    ]
  }
}

data "aws_iam_policy_document" "memory_ltm_read" {
  count = local.create_memory ? 1 : 0

  statement {
    sid    = "LTMReadAccess"
    effect = "Allow"

    actions = local.ltm_read_perms

    resources = [
      awscc_bedrockagentcore_memory.this[0].memory_arn
    ]
  }
}

data "aws_iam_policy_document" "memory_ltm_write" {
  count = local.create_memory ? 1 : 0

  statement {
    sid    = "LTMWriteAccess"
    effect = "Allow"

    actions = local.ltm_write_perms

    resources = [
      awscc_bedrockagentcore_memory.this[0].memory_arn
    ]
  }
}

data "aws_iam_policy_document" "memory_full_access" {
  count = local.create_memory ? 1 : 0

  statement {
    sid    = "MemoryFullAccess"
    effect = "Allow"

    actions = concat(
      local.all_memory_write_perms,
      local.all_memory_read_perms,
      local.all_memory_update_perms,
      local.all_memory_delete_perms
    )

    resources = [
      awscc_bedrockagentcore_memory.this[0].memory_arn
    ]
  }
}
