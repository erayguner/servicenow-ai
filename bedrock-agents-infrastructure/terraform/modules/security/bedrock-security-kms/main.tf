# ==============================================================================
# Bedrock Security KMS Module
# ==============================================================================
# Purpose: KMS encryption for Bedrock agent data with automatic rotation
# Features: Multi-region keys, key rotation, CloudWatch metrics, key grants
# ==============================================================================

locals {
  common_tags = merge(
    var.tags,
    {
      Module        = "bedrock-security-kms"
      ManagedBy     = "terraform"
      SecurityLevel = "critical"
      Compliance    = "SOC2,HIPAA,PCI-DSS"
    }
  )
}

# ==============================================================================
# Primary KMS Key for Bedrock Data Encryption
# ==============================================================================

resource "aws_kms_key" "bedrock_data" {
  description              = "KMS key for encrypting Bedrock agent data in ${var.environment}"
  deletion_window_in_days  = var.deletion_window_in_days
  enable_key_rotation      = var.enable_key_rotation
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  is_enabled               = true

  multi_region = var.enable_multi_region

  policy = data.aws_iam_policy_document.bedrock_data_key_policy.json

  tags = merge(
    local.common_tags,
    {
      Name    = "${var.project_name}-bedrock-data-key-${var.environment}"
      Purpose = "bedrock-data-encryption"
    }
  )
}

resource "aws_kms_alias" "bedrock_data" {
  name          = "alias/${var.project_name}/bedrock-data-${var.environment}"
  target_key_id = aws_kms_key.bedrock_data.key_id
}

data "aws_iam_policy_document" "bedrock_data_key_policy" {
  # Root account full access
  statement {
    sid    = "EnableRootAccountPermissions"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }

  # Bedrock service access
  statement {
    sid    = "AllowBedrockServiceAccess"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["bedrock.amazonaws.com"]
    }

    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:CreateGrant"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["bedrock.${var.aws_region}.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:CallerAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  # Lambda service access
  statement {
    sid    = "AllowLambdaServiceAccess"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = [
      "kms:Decrypt",
      "kms:DescribeKey"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["lambda.${var.aws_region}.amazonaws.com"]
    }
  }

  # CloudWatch Logs access
  statement {
    sid    = "AllowCloudWatchLogsAccess"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logs.${var.aws_region}.amazonaws.com"]
    }

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:CreateGrant",
      "kms:DescribeKey"
    ]

    resources = ["*"]

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:*"]
    }
  }

  # IAM role access
  statement {
    sid    = "AllowIAMRoleAccess"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = var.iam_role_arns
    }

    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*"
    ]

    resources = ["*"]
  }

  # Key administrators
  statement {
    sid    = "AllowKeyAdministration"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = var.key_admin_arns
    }

    actions = [
      "kms:Create*",
      "kms:Describe*",
      "kms:Enable*",
      "kms:List*",
      "kms:Put*",
      "kms:Update*",
      "kms:Revoke*",
      "kms:Disable*",
      "kms:Get*",
      "kms:Delete*",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion"
    ]

    resources = ["*"]
  }
}

# ==============================================================================
# KMS Key for Secrets Manager
# ==============================================================================

resource "aws_kms_key" "secrets" {
  description              = "KMS key for encrypting Secrets Manager secrets in ${var.environment}"
  deletion_window_in_days  = var.deletion_window_in_days
  enable_key_rotation      = var.enable_key_rotation
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  is_enabled               = true

  multi_region = var.enable_multi_region

  policy = data.aws_iam_policy_document.secrets_key_policy.json

  tags = merge(
    local.common_tags,
    {
      Name    = "${var.project_name}-secrets-key-${var.environment}"
      Purpose = "secrets-encryption"
    }
  )
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${var.project_name}/secrets-${var.environment}"
  target_key_id = aws_kms_key.secrets.key_id
}

data "aws_iam_policy_document" "secrets_key_policy" {
  # Root account permissions
  statement {
    sid    = "EnableRootAccountPermissions"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }

  # Secrets Manager service access
  statement {
    sid    = "AllowSecretsManagerAccess"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["secretsmanager.amazonaws.com"]
    }

    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:CreateGrant"
    ]

    resources = ["*"]
  }

  # IAM role access
  statement {
    sid    = "AllowIAMRoleAccess"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = var.iam_role_arns
    }

    actions = [
      "kms:Decrypt",
      "kms:DescribeKey"
    ]

    resources = ["*"]
  }
}

# ==============================================================================
# KMS Key for S3 Encryption
# ==============================================================================

resource "aws_kms_key" "s3" {
  description              = "KMS key for encrypting S3 buckets in ${var.environment}"
  deletion_window_in_days  = var.deletion_window_in_days
  enable_key_rotation      = var.enable_key_rotation
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  is_enabled               = true

  multi_region = var.enable_multi_region

  policy = data.aws_iam_policy_document.s3_key_policy.json

  tags = merge(
    local.common_tags,
    {
      Name    = "${var.project_name}-s3-key-${var.environment}"
      Purpose = "s3-encryption"
    }
  )
}

resource "aws_kms_alias" "s3" {
  name          = "alias/${var.project_name}/s3-${var.environment}"
  target_key_id = aws_kms_key.s3.key_id
}

data "aws_iam_policy_document" "s3_key_policy" {
  # Root account permissions
  statement {
    sid    = "EnableRootAccountPermissions"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }

  # S3 service access
  statement {
    sid    = "AllowS3ServiceAccess"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["s3.${var.aws_region}.amazonaws.com"]
    }
  }

  # IAM role access
  statement {
    sid    = "AllowIAMRoleAccess"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = var.iam_role_arns
    }

    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*"
    ]

    resources = ["*"]
  }
}

# ==============================================================================
# KMS Grants
# ==============================================================================

resource "aws_kms_grant" "bedrock_data_grant" {
  count = length(var.grant_role_arns)

  name              = "${var.project_name}-bedrock-data-grant-${count.index}-${var.environment}"
  key_id            = aws_kms_key.bedrock_data.key_id
  grantee_principal = var.grant_role_arns[count.index]

  operations = [
    "Encrypt",
    "Decrypt",
    "GenerateDataKey",
    "DescribeKey"
  ]

  constraints {
    encryption_context_subset = {
      Environment = var.environment
      Project     = var.project_name
    }
  }
}

# ==============================================================================
# CloudWatch Alarms for KMS Key Usage
# ==============================================================================

resource "aws_cloudwatch_metric_alarm" "kms_key_disabled" {
  for_each = {
    bedrock_data = aws_kms_key.bedrock_data.id
    secrets      = aws_kms_key.secrets.id
    s3           = aws_kms_key.s3.id
  }

  alarm_name          = "${var.project_name}-kms-key-disabled-${each.key}-${var.environment}"
  alarm_description   = "Alert when KMS key ${each.key} is disabled"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "KeyState"
  namespace           = "AWS/KMS"
  period              = "300"
  statistic           = "Average"
  threshold           = "1"
  treat_missing_data  = "breaching"

  dimensions = {
    KeyId = each.value
  }

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "kms_api_errors" {
  for_each = {
    bedrock_data = aws_kms_key.bedrock_data.id
    secrets      = aws_kms_key.secrets.id
    s3           = aws_kms_key.s3.id
  }

  alarm_name          = "${var.project_name}-kms-api-errors-${each.key}-${var.environment}"
  alarm_description   = "Alert on KMS API errors for ${each.key}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UserErrorCount"
  namespace           = "AWS/KMS"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.kms_error_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    KeyId = each.value
  }

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]

  tags = local.common_tags
}

# ==============================================================================
# CloudWatch Log Metric Filter for KMS Key Deletion
# ==============================================================================

resource "aws_cloudwatch_log_metric_filter" "kms_key_deletion" {
  name           = "${var.project_name}-kms-key-deletion-${var.environment}"
  log_group_name = var.cloudtrail_log_group_name
  pattern        = "{ ($.eventName = DisableKey) || ($.eventName = ScheduleKeyDeletion) }"

  metric_transformation {
    name      = "KMSKeyDeletion"
    namespace = "${var.project_name}/Security"
    value     = "1"

    dimensions = {
      Environment = var.environment
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "kms_key_deletion" {
  alarm_name          = "${var.project_name}-kms-key-deletion-${var.environment}"
  alarm_description   = "Alert on KMS key deletion or disablement"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "KMSKeyDeletion"
  namespace           = "${var.project_name}/Security"
  period              = "60"
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
