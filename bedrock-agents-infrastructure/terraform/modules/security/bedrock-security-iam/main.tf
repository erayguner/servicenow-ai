# ==============================================================================
# Bedrock Security IAM Module
# ==============================================================================
# Purpose: Least-privilege IAM policies and roles for Bedrock agents
# Features: ABAC, permission boundaries, service roles, cross-account access
# ==============================================================================

locals {
  common_tags = merge(
    var.tags,
    {
      Module        = "bedrock-security-iam"
      ManagedBy     = "terraform"
      SecurityLevel = "critical"
      Compliance    = "SOC2-HIPAA-PCI-DSS"
    }
  )
}

# ==============================================================================
# Bedrock Agent Execution Role
# ==============================================================================

resource "aws_iam_role" "bedrock_agent_execution" {
  name               = "${var.project_name}-bedrock-agent-execution-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.bedrock_agent_assume.json
  description        = "Execution role for Bedrock agents with least-privilege access"

  permissions_boundary = var.enable_permission_boundary ? aws_iam_policy.permission_boundary[0].arn : null

  max_session_duration = var.max_session_duration

  tags = merge(
    local.common_tags,
    {
      Name    = "${var.project_name}-bedrock-agent-execution-${var.environment}"
      Purpose = "bedrock-agent-execution"
      ABAC    = "enabled"
    }
  )
}

data "aws_iam_policy_document" "bedrock_agent_assume" {
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
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:agent/*"]
    }
  }
}

# Bedrock Agent Base Policy
resource "aws_iam_role_policy" "bedrock_agent_base" {
  name   = "bedrock-agent-base-policy"
  role   = aws_iam_role.bedrock_agent_execution.id
  policy = data.aws_iam_policy_document.bedrock_agent_base.json
}

data "aws_iam_policy_document" "bedrock_agent_base" {
  # Bedrock model invocation
  statement {
    sid    = "BedrockModelInvocation"
    effect = "Allow"

    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream"
    ]

    resources = var.allowed_bedrock_models

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.aws_region]
    }
  }

  # Knowledge base access
  dynamic "statement" {
    for_each = length(var.knowledge_base_arns) > 0 ? [1] : []
    content {
      sid    = "BedrockKnowledgeBase"
      effect = "Allow"

      actions = [
        "bedrock:Retrieve",
        "bedrock:RetrieveAndGenerate"
      ]

      resources = var.knowledge_base_arns
    }
  }

  # CloudWatch Logs
  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = [
      "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/bedrock/agents/${var.project_name}-*"
    ]
  }

  # CloudWatch Metrics
  statement {
    sid    = "CloudWatchMetrics"
    effect = "Allow"

    actions = [
      "cloudwatch:PutMetricData"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = ["AWS/Bedrock", "${var.project_name}/BedrockAgents"]
    }
  }
}

# ==============================================================================
# Lambda Execution Role for Bedrock Action Groups
# ==============================================================================

resource "aws_iam_role" "lambda_execution" {
  name               = "${var.project_name}-bedrock-lambda-execution-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  description        = "Execution role for Lambda functions invoked by Bedrock agents"

  permissions_boundary = var.enable_permission_boundary ? aws_iam_policy.permission_boundary[0].arn : null

  tags = merge(
    local.common_tags,
    {
      Name    = "${var.project_name}-bedrock-lambda-execution-${var.environment}"
      Purpose = "lambda-execution"
    }
  )
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_bedrock_access" {
  name   = "lambda-bedrock-access"
  role   = aws_iam_role.lambda_execution.id
  policy = data.aws_iam_policy_document.lambda_bedrock_access.json
}

data "aws_iam_policy_document" "lambda_bedrock_access" {
  # Secrets Manager access
  statement {
    sid    = "SecretsManagerAccess"
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]

    resources = [
      "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "secretsmanager:ResourceTag/Project"
      values   = [var.project_name]
    }
  }

  # DynamoDB access with ABAC
  dynamic "statement" {
    for_each = length(var.dynamodb_table_arns) > 0 ? [1] : []
    content {
      sid    = "DynamoDBAccess"
      effect = "Allow"

      actions = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ]

      resources = var.dynamodb_table_arns

      condition {
        test     = "StringEquals"
        variable = "dynamodb:ResourceTag/Environment"
        values   = [var.environment]
      }
    }
  }

  # S3 access with ABAC
  statement {
    sid    = "S3Access"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]

    resources = [
      "arn:aws:s3:::${var.project_name}-*/${var.environment}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "s3:ResourceTag/Environment"
      values   = [var.environment]
    }
  }

  # KMS decryption - only include if kms_key_arns is not empty
  dynamic "statement" {
    for_each = length(var.kms_key_arns) > 0 ? [1] : []
    content {
      sid    = "KMSDecrypt"
      effect = "Allow"

      actions = [
        "kms:Decrypt",
        "kms:DescribeKey"
      ]

      resources = var.kms_key_arns
    }
  }
}

# ==============================================================================
# Step Functions Execution Role
# ==============================================================================

resource "aws_iam_role" "step_functions_execution" {
  count = var.enable_step_functions ? 1 : 0

  name               = "${var.project_name}-bedrock-stepfunctions-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.step_functions_assume[0].json
  description        = "Execution role for Step Functions orchestrating Bedrock agents"

  permissions_boundary = var.enable_permission_boundary ? aws_iam_policy.permission_boundary[0].arn : null

  tags = merge(
    local.common_tags,
    {
      Name    = "${var.project_name}-bedrock-stepfunctions-${var.environment}"
      Purpose = "step-functions-execution"
    }
  )
}

data "aws_iam_policy_document" "step_functions_assume" {
  count = var.enable_step_functions ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy" "step_functions_execution" {
  count = var.enable_step_functions ? 1 : 0

  name   = "step-functions-execution-policy"
  role   = aws_iam_role.step_functions_execution[0].id
  policy = data.aws_iam_policy_document.step_functions_execution[0].json
}

data "aws_iam_policy_document" "step_functions_execution" {
  count = var.enable_step_functions ? 1 : 0

  statement {
    sid    = "InvokeLambda"
    effect = "Allow"

    actions = [
      "lambda:InvokeFunction"
    ]

    resources = [
      "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${var.project_name}-*"
    ]
  }

  statement {
    sid    = "InvokeBedrock"
    effect = "Allow"

    actions = [
      "bedrock:InvokeAgent",
      "bedrock:InvokeModel"
    ]

    resources = [
      "arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:agent/*",
      "arn:aws:bedrock:${var.aws_region}::foundation-model/*"
    ]
  }

  statement {
    sid    = "CloudWatchLogs"
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

# ==============================================================================
# Cross-Account Access Role
# ==============================================================================

resource "aws_iam_role" "cross_account_access" {
  count = var.enable_cross_account_access ? 1 : 0

  name               = "${var.project_name}-bedrock-cross-account-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.cross_account_assume[0].json
  description        = "Cross-account access role for Bedrock agents"

  permissions_boundary = var.enable_permission_boundary ? aws_iam_policy.permission_boundary[0].arn : null

  tags = merge(
    local.common_tags,
    {
      Name    = "${var.project_name}-bedrock-cross-account-${var.environment}"
      Purpose = "cross-account-access"
    }
  )
}

data "aws_iam_policy_document" "cross_account_assume" {
  count = var.enable_cross_account_access ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = var.trusted_account_ids
    }

    actions = ["sts:AssumeRole"]

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.external_id]
    }
  }
}

resource "aws_iam_role_policy" "cross_account_access" {
  count = var.enable_cross_account_access ? 1 : 0

  name   = "cross-account-access-policy"
  role   = aws_iam_role.cross_account_access[0].id
  policy = data.aws_iam_policy_document.cross_account_access[0].json
}

data "aws_iam_policy_document" "cross_account_access" {
  count = var.enable_cross_account_access ? 1 : 0

  statement {
    sid    = "BedrockReadOnly"
    effect = "Allow"

    actions = [
      "bedrock:GetAgent",
      "bedrock:ListAgents",
      "bedrock:GetKnowledgeBase",
      "bedrock:ListKnowledgeBases"
    ]

    resources = ["*"]
  }
}

# ==============================================================================
# Permission Boundary Policy
# ==============================================================================

resource "aws_iam_policy" "permission_boundary" {
  count = var.enable_permission_boundary ? 1 : 0

  name        = "${var.project_name}-bedrock-permission-boundary-${var.environment}"
  description = "Permission boundary for Bedrock agent roles"
  policy      = data.aws_iam_policy_document.permission_boundary[0].json

  tags = merge(
    local.common_tags,
    {
      Name    = "${var.project_name}-bedrock-permission-boundary-${var.environment}"
      Purpose = "permission-boundary"
    }
  )
}

data "aws_iam_policy_document" "permission_boundary" {
  count = var.enable_permission_boundary ? 1 : 0

  # Restrict to specific regions
  statement {
    sid    = "RegionRestriction"
    effect = "Deny"

    actions = ["*"]

    resources = ["*"]

    condition {
      test     = "StringNotEquals"
      variable = "aws:RequestedRegion"
      values   = var.allowed_regions
    }
  }

  # Prevent privilege escalation
  statement {
    sid    = "PreventPrivilegeEscalation"
    effect = "Deny"

    actions = [
      "iam:CreateUser",
      "iam:CreateRole",
      "iam:CreateAccessKey",
      "iam:AttachUserPolicy",
      "iam:AttachRolePolicy",
      "iam:PutUserPolicy",
      "iam:PutRolePolicy"
    ]

    resources = ["*"]
  }

  # Prevent security group modifications
  statement {
    sid    = "PreventSecurityGroupModification"
    effect = "Deny"

    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupEgress"
    ]

    resources = ["*"]
  }
}

# ==============================================================================
# CloudWatch Alarms for IAM Activity
# ==============================================================================

# Removed plan-time data lookup for CloudTrail; assume provided name exists or let users disable via flags

resource "aws_cloudwatch_log_metric_filter" "unauthorized_api_calls" {
  count = var.enable_cloudtrail_metrics && var.cloudtrail_log_group_name != "" ? 1 : 0

  name           = "${var.project_name}-unauthorized-api-calls-${var.environment}"
  log_group_name = var.cloudtrail_log_group_name
  pattern        = "{ ($.errorCode = \"*UnauthorizedOperation\") || ($.errorCode = \"AccessDenied*\") }"

  metric_transformation {
    name      = "UnauthorizedAPICalls"
    namespace = "${var.project_name}/Security"
    value     = "1"

    dimensions = {
      Environment = var.environment
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "unauthorized_api_calls" {
  count = var.enable_cloudtrail_metrics && var.cloudtrail_log_group_name != "" ? 1 : 0

  alarm_name          = "${var.project_name}-unauthorized-api-calls-${var.environment}"
  alarm_description   = "Alert on unauthorized API calls"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "UnauthorizedAPICalls"
  namespace           = "${var.project_name}/Security"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.unauthorized_calls_threshold
  treat_missing_data  = "notBreaching"

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]

  tags = local.common_tags
}

resource "aws_cloudwatch_log_metric_filter" "iam_policy_changes" {
  count = var.enable_cloudtrail_metrics && var.cloudtrail_log_group_name != "" ? 1 : 0

  name           = "${var.project_name}-iam-policy-changes-${var.environment}"
  log_group_name = var.cloudtrail_log_group_name
  pattern        = "{ ($.eventName = DeleteGroupPolicy) || ($.eventName = DeleteRolePolicy) || ($.eventName = DeleteUserPolicy) || ($.eventName = PutGroupPolicy) || ($.eventName = PutRolePolicy) || ($.eventName = PutUserPolicy) || ($.eventName = CreatePolicy) || ($.eventName = DeletePolicy) || ($.eventName = CreatePolicyVersion) || ($.eventName = DeletePolicyVersion) || ($.eventName = AttachRolePolicy) || ($.eventName = DetachRolePolicy) || ($.eventName = AttachUserPolicy) || ($.eventName = DetachUserPolicy) || ($.eventName = AttachGroupPolicy) || ($.eventName = DetachGroupPolicy) }"


  metric_transformation {
    name      = "IAMPolicyChanges"
    namespace = "${var.project_name}/Security"
    value     = "1"

    dimensions = {
      Environment = var.environment
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "iam_policy_changes" {
  count = var.enable_cloudtrail_metrics && var.cloudtrail_log_group_name != "" ? 1 : 0

  alarm_name          = "${var.project_name}-iam-policy-changes-${var.environment}"
  alarm_description   = "Alert on IAM policy changes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "IAMPolicyChanges"
  namespace           = "${var.project_name}/Security"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  treat_missing_data  = "notBreaching"

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]

  tags = local.common_tags
}

# ==============================================================================
# Data Sources
# ==============================================================================

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# ==============================================================================
# AgentCore Consumer Role
# ==============================================================================
# This role is for applications that need to interact with AgentCore resources

resource "aws_iam_role" "agentcore_consumer" {
  count = var.enable_agentcore ? 1 : 0

  name               = "${var.project_name}-agentcore-consumer-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.agentcore_consumer_assume[0].json
  description        = "Consumer role for interacting with Bedrock AgentCore resources"

  permissions_boundary = var.enable_permission_boundary ? aws_iam_policy.permission_boundary[0].arn : null
  max_session_duration = var.max_session_duration

  tags = merge(
    local.common_tags,
    {
      Name    = "${var.project_name}-agentcore-consumer-${var.environment}"
      Purpose = "agentcore-consumer"
    }
  )
}

data "aws_iam_policy_document" "agentcore_consumer_assume" {
  count = var.enable_agentcore ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com", "states.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy" "agentcore_consumer" {
  count = var.enable_agentcore ? 1 : 0

  name   = "agentcore-consumer-policy"
  role   = aws_iam_role.agentcore_consumer[0].id
  policy = data.aws_iam_policy_document.agentcore_consumer[0].json
}

data "aws_iam_policy_document" "agentcore_consumer" {
  count = var.enable_agentcore ? 1 : 0

  # Runtime invocation
  dynamic "statement" {
    for_each = length(var.agentcore_runtime_arns) > 0 ? [1] : []
    content {
      sid    = "AgentCoreRuntimeInvoke"
      effect = "Allow"

      actions = [
        "bedrock-agentcore:InvokeRuntime",
        "bedrock-agentcore:InvokeRuntimeWithResponseStream"
      ]

      resources = var.agentcore_runtime_arns
    }
  }

  # Gateway invocation
  dynamic "statement" {
    for_each = length(var.agentcore_gateway_arns) > 0 ? [1] : []
    content {
      sid    = "AgentCoreGatewayInvoke"
      effect = "Allow"

      actions = [
        "bedrock-agentcore:InvokeGateway",
        "bedrock-agentcore:ListGatewayTargets"
      ]

      resources = var.agentcore_gateway_arns
    }
  }

  # Memory operations - Short-Term Memory (STM)
  dynamic "statement" {
    for_each = length(var.agentcore_memory_arns) > 0 ? [1] : []
    content {
      sid    = "AgentCoreMemorySTM"
      effect = "Allow"

      actions = [
        "bedrock-agentcore:CreateEvent",
        "bedrock-agentcore:GetEvent",
        "bedrock-agentcore:ListEvents",
        "bedrock-agentcore:ListEventsPaginated",
        "bedrock-agentcore:DeleteEvents",
        "bedrock-agentcore:DeleteSession"
      ]

      resources = var.agentcore_memory_arns
    }
  }

  # Memory operations - Long-Term Memory (LTM)
  dynamic "statement" {
    for_each = length(var.agentcore_memory_arns) > 0 ? [1] : []
    content {
      sid    = "AgentCoreMemoryLTM"
      effect = "Allow"

      actions = [
        "bedrock-agentcore:CreateMemoryRecord",
        "bedrock-agentcore:GetMemoryRecord",
        "bedrock-agentcore:RetrieveMemoryRecords",
        "bedrock-agentcore:ListMemoryRecords",
        "bedrock-agentcore:UpdateMemoryRecord",
        "bedrock-agentcore:DeleteMemoryRecord"
      ]

      resources = var.agentcore_memory_arns
    }
  }

  # Code Interpreter invocation
  dynamic "statement" {
    for_each = length(var.agentcore_code_interpreter_arns) > 0 ? [1] : []
    content {
      sid    = "AgentCoreCodeInterpreter"
      effect = "Allow"

      actions = [
        "bedrock-agentcore:InvokeCodeInterpreter"
      ]

      resources = var.agentcore_code_interpreter_arns
    }
  }

  # Lambda invocation for gateway targets
  dynamic "statement" {
    for_each = length(var.agentcore_lambda_function_arns) > 0 ? [1] : []
    content {
      sid    = "LambdaInvocationForGateway"
      effect = "Allow"

      actions = [
        "lambda:InvokeFunction"
      ]

      resources = var.agentcore_lambda_function_arns
    }
  }

  # Bedrock model invocation (for agents using AgentCore)
  statement {
    sid    = "BedrockModelInvocation"
    effect = "Allow"

    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream"
    ]

    resources = var.allowed_bedrock_models

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = var.allowed_regions
    }
  }

  # CloudWatch Logs
  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = [
      "arn:${data.aws_partition.current.partition}:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/bedrock-agentcore/*"
    ]
  }

  # X-Ray tracing
  statement {
    sid    = "XRayTracing"
    effect = "Allow"

    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords"
    ]

    resources = ["*"]
  }
}

# ==============================================================================
# AgentCore Admin Role
# ==============================================================================
# This role is for administrators who need to manage AgentCore resources

resource "aws_iam_role" "agentcore_admin" {
  count = var.enable_agentcore ? 1 : 0

  name               = "${var.project_name}-agentcore-admin-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.agentcore_admin_assume[0].json
  description        = "Admin role for managing Bedrock AgentCore resources"

  permissions_boundary = var.enable_permission_boundary ? aws_iam_policy.permission_boundary[0].arn : null
  max_session_duration = var.max_session_duration

  tags = merge(
    local.common_tags,
    {
      Name    = "${var.project_name}-agentcore-admin-${var.environment}"
      Purpose = "agentcore-admin"
    }
  )
}

data "aws_iam_policy_document" "agentcore_admin_assume" {
  count = var.enable_agentcore ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions = ["sts:AssumeRole"]

    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }
}

resource "aws_iam_role_policy" "agentcore_admin" {
  count = var.enable_agentcore ? 1 : 0

  name   = "agentcore-admin-policy"
  role   = aws_iam_role.agentcore_admin[0].id
  policy = data.aws_iam_policy_document.agentcore_admin[0].json
}

data "aws_iam_policy_document" "agentcore_admin" {
  count = var.enable_agentcore ? 1 : 0

  # Full AgentCore management
  statement {
    sid    = "AgentCoreFullAccess"
    effect = "Allow"

    actions = [
      "bedrock-agentcore:*"
    ]

    resources = [
      "arn:${data.aws_partition.current.partition}:bedrock-agentcore:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = var.allowed_regions
    }
  }

  # IAM PassRole for AgentCore
  statement {
    sid    = "IAMPassRole"
    effect = "Allow"

    actions = [
      "iam:PassRole"
    ]

    resources = [
      "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-agentcore-*"
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["bedrock-agentcore.amazonaws.com"]
    }
  }

  # Bedrock model listing
  statement {
    sid    = "BedrockModelListing"
    effect = "Allow"

    actions = [
      "bedrock:ListFoundationModels",
      "bedrock:GetFoundationModel"
    ]

    resources = ["*"]
  }

  # CloudWatch Logs for debugging
  statement {
    sid    = "CloudWatchLogsRead"
    effect = "Allow"

    actions = [
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:GetLogEvents",
      "logs:FilterLogEvents"
    ]

    resources = [
      "arn:${data.aws_partition.current.partition}:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/bedrock-agentcore/*"
    ]
  }
}
