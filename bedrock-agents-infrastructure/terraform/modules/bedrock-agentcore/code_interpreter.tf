# ==============================================================================
# AgentCore Code Interpreter
# ==============================================================================
# Code execution environment with sandbox or VPC network modes
# ==============================================================================

# ==============================================================================
# Code Interpreter IAM Role
# ==============================================================================

resource "aws_iam_role" "code_interpreter_role" {
  count = local.create_code_interpreter && var.code_interpreter_role_arn == null ? 1 : 0

  name = "${local.name_prefix}-agentcore-codeinterp-role-${local.resource_suffix}"

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
            "aws:SourceArn" = "arn:${local.partition}:bedrock-agentcore:${local.region}:${local.account_id}:code-interpreter/*"
          }
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name    = "${local.name_prefix}-agentcore-codeinterp-role"
      Purpose = "agentcore-code-interpreter"
    }
  )
}

resource "aws_iam_role_policy" "code_interpreter_role_policy" {
  count = local.create_code_interpreter && var.code_interpreter_role_arn == null ? 1 : 0

  name = "${local.name_prefix}-agentcore-codeinterp-policy"
  role = aws_iam_role.code_interpreter_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
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
            "arn:${local.partition}:logs:${local.region}:${local.account_id}:log-group:/aws/bedrock-agentcore/code-interpreter/*"
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
      # VPC network interface permissions (if VPC mode)
      var.code_interpreter_network_mode == "VPC" ? [
        {
          Sid    = "VPCNetworkInterface"
          Effect = "Allow"
          Action = [
            "ec2:CreateNetworkInterface",
            "ec2:DescribeNetworkInterfaces",
            "ec2:DeleteNetworkInterface",
            "ec2:AssignPrivateIpAddresses",
            "ec2:UnassignPrivateIpAddresses"
          ]
          Resource = ["*"]
        }
      ] : [],
      # S3 access for code artifacts
      length(var.code_interpreter_s3_bucket_arns) > 0 ? [
        {
          Sid    = "S3Access"
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:ListBucket"
          ]
          Resource = concat(
            var.code_interpreter_s3_bucket_arns,
            [for arn in var.code_interpreter_s3_bucket_arns : "${arn}/*"]
          )
        }
      ] : [],
      # KMS access (if encryption key provided)
      var.code_interpreter_kms_key_arn != null ? [
        {
          Sid    = "KMSAccess"
          Effect = "Allow"
          Action = [
            "kms:Decrypt",
            "kms:GenerateDataKey"
          ]
          Resource = [var.code_interpreter_kms_key_arn]
        }
      ] : []
    )
  })
}

# ==============================================================================
# AgentCore Code Interpreter
# ==============================================================================

resource "awscc_bedrockagentcore_code_interpreter_custom" "this" {
  count = local.create_code_interpreter ? 1 : 0

  name               = "${local.resource_suffix}_${local.sanitized_code_interpreter_name}"
  description        = var.code_interpreter_description
  execution_role_arn = var.code_interpreter_role_arn != null ? var.code_interpreter_role_arn : aws_iam_role.code_interpreter_role[0].arn

  # Network configuration
  network_configuration = {
    network_mode = var.code_interpreter_network_mode

    # VPC configuration (only if VPC mode)
    vpc_configuration = var.code_interpreter_network_mode == "VPC" ? {
      security_group_ids = var.code_interpreter_security_group_ids
      subnet_ids         = var.code_interpreter_subnet_ids
    } : null
  }

  depends_on = [time_sleep.iam_role_propagation]
}

# ==============================================================================
# CloudWatch Log Group for Code Interpreter
# ==============================================================================

resource "aws_cloudwatch_log_group" "code_interpreter" {
  count = local.create_code_interpreter ? 1 : 0

  name              = "/aws/bedrock-agentcore/code-interpreter/${local.name_prefix}-${var.code_interpreter_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.code_interpreter_kms_key_arn

  tags = merge(
    local.common_tags,
    {
      Name    = "${local.name_prefix}-code-interpreter-logs"
      Purpose = "agentcore-code-interpreter-logs"
    }
  )
}

# ==============================================================================
# Code Interpreter Access Policy Document (for external consumers)
# ==============================================================================

data "aws_iam_policy_document" "code_interpreter_invoke" {
  count = local.create_code_interpreter ? 1 : 0

  statement {
    sid    = "CodeInterpreterInvoke"
    effect = "Allow"

    actions = [
      "bedrock-agentcore:InvokeCodeInterpreter"
    ]

    resources = [
      awscc_bedrockagentcore_code_interpreter_custom.this[0].code_interpreter_arn
    ]
  }
}
