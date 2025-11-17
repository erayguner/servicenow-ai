# DynamoDB Table for State Management
resource "aws_dynamodb_table" "state" {
  count = var.create_dynamodb_table ? 1 : 0

  name         = var.dynamodb_table_name != null ? var.dynamodb_table_name : "${var.orchestration_name}-state"
  billing_mode = var.dynamodb_billing_mode
  hash_key     = "execution_id"
  range_key    = "timestamp"

  dynamic "attribute" {
    for_each = [
      { name = "execution_id", type = "S" },
      { name = "timestamp", type = "N" },
      { name = "agent_id", type = "S" },
      { name = "status", type = "S" }
    ]
    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }

  dynamic "global_secondary_index" {
    for_each = var.dynamodb_billing_mode == "PROVISIONED" ? [1] : []
    content {
      name            = "AgentIndex"
      hash_key        = "agent_id"
      range_key       = "timestamp"
      projection_type = "ALL"
      read_capacity   = var.dynamodb_read_capacity
      write_capacity  = var.dynamodb_write_capacity
    }
  }

  dynamic "global_secondary_index" {
    for_each = var.dynamodb_billing_mode == "PAY_PER_REQUEST" ? [1] : []
    content {
      name            = "AgentIndex"
      hash_key        = "agent_id"
      range_key       = "timestamp"
      projection_type = "ALL"
    }
  }

  dynamic "global_secondary_index" {
    for_each = var.dynamodb_billing_mode == "PROVISIONED" ? [1] : []
    content {
      name            = "StatusIndex"
      hash_key        = "status"
      range_key       = "timestamp"
      projection_type = "ALL"
      read_capacity   = var.dynamodb_read_capacity
      write_capacity  = var.dynamodb_write_capacity
    }
  }

  dynamic "global_secondary_index" {
    for_each = var.dynamodb_billing_mode == "PAY_PER_REQUEST" ? [1] : []
    content {
      name            = "StatusIndex"
      hash_key        = "status"
      range_key       = "timestamp"
      projection_type = "ALL"
    }
  }

  read_capacity  = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_read_capacity : null
  write_capacity = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_write_capacity : null

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_id != null ? "arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/${var.kms_key_id}" : null
  }

  ttl {
    enabled        = true
    attribute_name = "ttl"
  }

  tags = merge(
    var.tags,
    {
      Name      = "${var.orchestration_name}-state"
      ManagedBy = "Terraform"
      Component = "BedrockOrchestration"
    }
  )
}

# IAM Role for Step Functions
resource "aws_iam_role" "state_machine" {
  name               = "${var.orchestration_name}-sfn-role"
  assume_role_policy = data.aws_iam_policy_document.sfn_trust.json

  tags = merge(
    var.tags,
    {
      Name      = "${var.orchestration_name}-sfn-role"
      ManagedBy = "Terraform"
      Component = "BedrockOrchestration"
    }
  )
}

data "aws_iam_policy_document" "sfn_trust" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy" "state_machine" {
  name   = "${var.orchestration_name}-sfn-policy"
  role   = aws_iam_role.state_machine.id
  policy = data.aws_iam_policy_document.sfn_permissions.json
}

data "aws_iam_policy_document" "sfn_permissions" {
  # Bedrock agent invocation
  statement {
    effect = "Allow"
    actions = [
      "bedrock:InvokeAgent"
    ]
    resources = var.agent_arns
  }

  # DynamoDB access
  dynamic "statement" {
    for_each = var.create_dynamodb_table ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ]
      resources = [
        aws_dynamodb_table.state[0].arn,
        "${aws_dynamodb_table.state[0].arn}/index/*"
      ]
    }
  }

  # CloudWatch Logs
  dynamic "statement" {
    for_each = var.enable_logging ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "logs:CreateLogDelivery",
        "logs:GetLogDelivery",
        "logs:UpdateLogDelivery",
        "logs:DeleteLogDelivery",
        "logs:ListLogDeliveries",
        "logs:PutResourcePolicy",
        "logs:DescribeResourcePolicies",
        "logs:DescribeLogGroups"
      ]
      resources = ["*"]
    }
  }

  # SNS notifications
  dynamic "statement" {
    for_each = var.enable_sns_notifications ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "sns:Publish"
      ]
      resources = [aws_sns_topic.notifications[0].arn]
    }
  }

  # X-Ray tracing
  dynamic "statement" {
    for_each = var.enable_xray_tracing ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "xray:PutTraceSegments",
        "xray:PutTelemetryRecords"
      ]
      resources = ["*"]
    }
  }

  # KMS encryption
  dynamic "statement" {
    for_each = var.kms_key_id != null ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ]
      resources = ["arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/${var.kms_key_id}"]
    }
  }
}

# CloudWatch Log Group for Step Functions
resource "aws_cloudwatch_log_group" "state_machine" {
  count             = var.enable_logging ? 1 : 0
  name              = "/aws/vendedlogs/states/${var.orchestration_name}"
  retention_in_days = 30
  kms_key_id        = var.kms_key_id != null ? "arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/${var.kms_key_id}" : null

  tags = merge(
    var.tags,
    {
      Name      = "${var.orchestration_name}-logs"
      ManagedBy = "Terraform"
      Component = "BedrockOrchestration"
    }
  )
}

# Step Functions State Machine
resource "aws_sfn_state_machine" "this" {
  name     = var.orchestration_name
  role_arn = aws_iam_role.state_machine.arn
  type     = var.state_machine_type

  definition = var.use_default_definition ? local.default_state_machine_definition : var.state_machine_definition

  dynamic "logging_configuration" {
    for_each = var.enable_logging ? [1] : []
    content {
      log_destination        = "${aws_cloudwatch_log_group.state_machine[0].arn}:*"
      include_execution_data = true
      level                  = var.log_level
    }
  }

  dynamic "tracing_configuration" {
    for_each = var.enable_xray_tracing ? [1] : []
    content {
      enabled = true
    }
  }

  tags = merge(
    var.tags,
    {
      Name      = var.orchestration_name
      ManagedBy = "Terraform"
      Component = "BedrockOrchestration"
    }
  )

  depends_on = [
    aws_iam_role_policy.state_machine,
    aws_cloudwatch_log_group.state_machine
  ]
}

# SNS Topic for Notifications
resource "aws_sns_topic" "notifications" {
  count = var.enable_sns_notifications ? 1 : 0

  name              = var.sns_topic_name != null ? var.sns_topic_name : "${var.orchestration_name}-notifications"
  kms_master_key_id = var.kms_key_id

  tags = merge(
    var.tags,
    {
      Name      = "${var.orchestration_name}-notifications"
      ManagedBy = "Terraform"
      Component = "BedrockOrchestration"
    }
  )
}

resource "aws_sns_topic_subscription" "email" {
  for_each = var.enable_sns_notifications ? toset(var.sns_email_subscriptions) : []

  topic_arn = aws_sns_topic.notifications[0].arn
  protocol  = "email"
  endpoint  = each.value
}

# EventBridge Rule for Triggering
resource "aws_cloudwatch_event_rule" "trigger" {
  count = var.enable_eventbridge_trigger ? 1 : 0

  name                = "${var.orchestration_name}-trigger"
  description         = "Trigger for ${var.orchestration_name} orchestration"
  schedule_expression = var.eventbridge_schedule_expression
  event_pattern       = var.eventbridge_event_pattern

  tags = merge(
    var.tags,
    {
      Name      = "${var.orchestration_name}-trigger"
      ManagedBy = "Terraform"
      Component = "BedrockOrchestration"
    }
  )
}

resource "aws_cloudwatch_event_target" "state_machine" {
  count = var.enable_eventbridge_trigger ? 1 : 0

  rule      = aws_cloudwatch_event_rule.trigger[0].name
  target_id = "StepFunctionsTarget"
  arn       = aws_sfn_state_machine.this.arn
  role_arn  = aws_iam_role.eventbridge[0].arn

  dynamic "input_transformer" {
    for_each = var.eventbridge_input_transformer != null ? [var.eventbridge_input_transformer] : []
    content {
      input_paths    = input_transformer.value.input_paths_map
      input_template = input_transformer.value.input_template
    }
  }
}

# IAM Role for EventBridge
resource "aws_iam_role" "eventbridge" {
  count = var.enable_eventbridge_trigger ? 1 : 0

  name               = "${var.orchestration_name}-eventbridge-role"
  assume_role_policy = data.aws_iam_policy_document.eventbridge_trust[0].json

  tags = merge(
    var.tags,
    {
      Name      = "${var.orchestration_name}-eventbridge-role"
      ManagedBy = "Terraform"
      Component = "BedrockOrchestration"
    }
  )
}

data "aws_iam_policy_document" "eventbridge_trust" {
  count = var.enable_eventbridge_trigger ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy" "eventbridge" {
  count = var.enable_eventbridge_trigger ? 1 : 0

  name   = "${var.orchestration_name}-eventbridge-policy"
  role   = aws_iam_role.eventbridge[0].id
  policy = data.aws_iam_policy_document.eventbridge_permissions[0].json
}

data "aws_iam_policy_document" "eventbridge_permissions" {
  count = var.enable_eventbridge_trigger ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "states:StartExecution"
    ]
    resources = [aws_sfn_state_machine.this.arn]
  }
}

# Default State Machine Definition
locals {
  default_state_machine_definition = templatefile("${path.module}/templates/${var.orchestration_pattern}_definition.json.tpl", {
    agent_arns          = jsonencode(var.agent_arns)
    dynamodb_table_name = var.create_dynamodb_table ? aws_dynamodb_table.state[0].name : ""
    sns_topic_arn       = var.enable_sns_notifications ? aws_sns_topic.notifications[0].arn : ""
    timeout_seconds     = var.timeout_seconds
    max_retry_attempts  = var.max_retry_attempts
    error_handling      = var.error_handling_strategy
  })
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
