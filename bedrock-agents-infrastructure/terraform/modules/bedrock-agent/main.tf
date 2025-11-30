# ==============================================================================
# Shared Data Sources
# ==============================================================================

module "shared_data" {
  source = "../_shared/data-sources"
}

# ==============================================================================
# IAM Resources
# ==============================================================================

# IAM Role for Bedrock Agent
resource "aws_iam_role" "agent" {
  name               = "${var.agent_name}-agent-role"
  assume_role_policy = data.aws_iam_policy_document.agent_trust.json

  tags = merge(
    var.tags,
    {
      Name      = "${var.agent_name}-agent-role"
      ManagedBy = "Terraform"
      Component = "BedrockAgent"
    }
  )
}

data "aws_iam_policy_document" "agent_trust" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["bedrock.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [module.shared_data.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:bedrock:${module.shared_data.region_name}:${module.shared_data.account_id}:agent/*"]
    }
  }
}

# IAM Policy for Bedrock Agent
resource "aws_iam_role_policy" "agent" {
  name   = "${var.agent_name}-agent-policy"
  role   = aws_iam_role.agent.id
  policy = data.aws_iam_policy_document.agent_permissions.json
}

data "aws_iam_policy_document" "agent_permissions" {
  # Bedrock model invocation
  statement {
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream"
    ]
    resources = [
      "arn:aws:bedrock:${module.shared_data.region_name}::foundation-model/${var.foundation_model}",
      "arn:aws:bedrock:${module.shared_data.region_name}::foundation-model/${var.model_id}"
    ]
  }

  # Knowledge base access
  dynamic "statement" {
    for_each = length(var.knowledge_bases) > 0 ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "bedrock:Retrieve",
        "bedrock:RetrieveAndGenerate"
      ]
      resources = [
        for kb in var.knowledge_bases : "arn:aws:bedrock:${module.shared_data.region_name}:${module.shared_data.account_id}:knowledge-base/${kb.knowledge_base_id}"
      ]
    }
  }

  # Lambda invocation for action groups
  dynamic "statement" {
    for_each = length(var.action_groups) > 0 ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "lambda:InvokeFunction"
      ]
      resources = [
        for ag in var.action_groups : ag.lambda_arn
      ]
    }
  }

  # CloudWatch Logs
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:${module.shared_data.region_name}:${module.shared_data.account_id}:log-group:/aws/bedrock/agents/${var.agent_name}:*"
    ]
  }

  # KMS encryption (if enabled)
  dynamic "statement" {
    for_each = var.customer_encryption_key_arn != null ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ]
      resources = [var.customer_encryption_key_arn]
    }
  }
}

# Bedrock Agent
resource "aws_bedrockagent_agent" "this" {
  agent_name              = var.agent_name
  description             = var.description
  agent_resource_role_arn = aws_iam_role.agent.arn
  foundation_model        = var.foundation_model
  instruction             = var.instruction

  idle_session_ttl_in_seconds = var.idle_session_ttl_in_seconds
  prepare_agent               = var.prepare_agent

  customer_encryption_key_arn = var.customer_encryption_key_arn

  dynamic "prompt_override_configuration" {
    for_each = var.prompt_override_configuration != null ? [var.prompt_override_configuration] : []
    content {
      prompt_configurations {
        prompt_type          = prompt_override_configuration.value.prompt_type
        prompt_creation_mode = prompt_override_configuration.value.prompt_creation_mode
        prompt_state         = prompt_override_configuration.value.prompt_state
        base_prompt_template = prompt_override_configuration.value.base_prompt_template

        dynamic "inference_configuration" {
          for_each = prompt_override_configuration.value.inference_configuration != null ? [prompt_override_configuration.value.inference_configuration] : []
          content {
            temperature    = inference_configuration.value.temperature
            top_p          = inference_configuration.value.top_p
            top_k          = inference_configuration.value.top_k
            stop_sequences = inference_configuration.value.stop_sequences
          }
        }
      }
    }
  }

  dynamic "guardrail_configuration" {
    for_each = var.guardrail_configuration != null ? [var.guardrail_configuration] : []
    content {
      guardrail_identifier = guardrail_configuration.value.guardrail_identifier
      guardrail_version    = guardrail_configuration.value.guardrail_version
    }
  }

  tags = merge(
    var.tags,
    {
      Name      = var.agent_name
      ManagedBy = "Terraform"
      Component = "BedrockAgent"
    }
  )
}

# Knowledge Base Associations
resource "aws_bedrockagent_agent_knowledge_base_association" "this" {
  for_each = { for idx, kb in var.knowledge_bases : idx => kb }

  agent_id             = aws_bedrockagent_agent.this.id
  description          = each.value.description
  knowledge_base_id    = each.value.knowledge_base_id
  knowledge_base_state = "ENABLED"
}

# Action Groups
resource "aws_bedrockagent_agent_action_group" "this" {
  for_each = { for idx, ag in var.action_groups : idx => ag }

  action_group_name          = each.value.action_group_name
  agent_id                   = aws_bedrockagent_agent.this.id
  agent_version              = "DRAFT"
  description                = each.value.description
  action_group_state         = each.value.enabled ? "ENABLED" : "DISABLED"
  skip_resource_in_use_check = false

  action_group_executor {
    lambda = each.value.lambda_arn
  }

  api_schema {
    payload = each.value.api_schema
  }

  depends_on = [aws_bedrockagent_agent.this]
}

# Agent Aliases
resource "aws_bedrockagent_agent_alias" "this" {
  for_each = var.agent_aliases

  agent_alias_name = each.key
  agent_id         = aws_bedrockagent_agent.this.id
  description      = each.value.description

  tags = merge(
    var.tags,
    each.value.tags,
    {
      Name      = "${var.agent_name}-${each.key}"
      ManagedBy = "Terraform"
      Component = "BedrockAgentAlias"
    }
  )
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "agent" {
  name              = "/aws/bedrock/agents/${var.agent_name}"
  retention_in_days = 30
  kms_key_id        = var.kms_key_id

  tags = merge(
    var.tags,
    {
      Name      = "${var.agent_name}-logs"
      ManagedBy = "Terraform"
      Component = "BedrockAgent"
    }
  )
}
