# ==============================================================================
# Bedrock Security Secrets Module
# ==============================================================================
# Purpose: Secrets management with automatic rotation for Bedrock agents
# Features: Automatic rotation, cross-region replication, access logging
# ==============================================================================

locals {
  common_tags = merge(
    var.tags,
    {
      Module        = "bedrock-security-secrets"
      ManagedBy     = "terraform"
      SecurityLevel = "critical"
      Compliance    = "SOC2,HIPAA,PCI-DSS"
    }
  )
}

# ==============================================================================
# Secrets Manager Secrets
# ==============================================================================

# Bedrock API Keys Secret
resource "aws_secretsmanager_secret" "bedrock_api_keys" {
  name                    = "${var.project_name}/bedrock/api-keys-${var.environment}"
  description             = "API keys for Bedrock agents"
  kms_key_id              = var.kms_key_id
  recovery_window_in_days = var.recovery_window_in_days

  dynamic "replica" {
    for_each = var.enable_cross_region_replication ? var.replica_regions : []

    content {
      region     = replica.value
      kms_key_id = var.replica_kms_key_ids[replica.value]
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name       = "${var.project_name}-bedrock-api-keys-${var.environment}"
      SecretType = "api-keys"
      Rotation   = var.enable_rotation ? "enabled" : "disabled"
    }
  )
}

resource "aws_secretsmanager_secret_version" "bedrock_api_keys" {
  secret_id     = aws_secretsmanager_secret.bedrock_api_keys.id
  secret_string = jsonencode(var.bedrock_api_keys)

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# Database Credentials Secret
resource "aws_secretsmanager_secret" "database_credentials" {
  count = var.enable_database_secrets ? 1 : 0

  name                    = "${var.project_name}/bedrock/database-credentials-${var.environment}"
  description             = "Database credentials for Bedrock agents"
  kms_key_id              = var.kms_key_id
  recovery_window_in_days = var.recovery_window_in_days

  dynamic "replica" {
    for_each = var.enable_cross_region_replication ? var.replica_regions : []

    content {
      region     = replica.value
      kms_key_id = var.replica_kms_key_ids[replica.value]
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name       = "${var.project_name}-bedrock-database-${var.environment}"
      SecretType = "database-credentials"
      Rotation   = var.enable_rotation ? "enabled" : "disabled"
    }
  )
}

resource "aws_secretsmanager_secret_version" "database_credentials" {
  count = var.enable_database_secrets ? 1 : 0

  secret_id = aws_secretsmanager_secret.database_credentials[0].id
  secret_string = jsonencode({
    username = var.database_username
    password = var.database_password
    host     = var.database_host
    port     = var.database_port
    dbname   = var.database_name
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# Third-party API Keys Secret
resource "aws_secretsmanager_secret" "third_party_keys" {
  count = length(var.third_party_api_keys) > 0 ? 1 : 0

  name                    = "${var.project_name}/bedrock/third-party-keys-${var.environment}"
  description             = "Third-party API keys for Bedrock integrations"
  kms_key_id              = var.kms_key_id
  recovery_window_in_days = var.recovery_window_in_days

  dynamic "replica" {
    for_each = var.enable_cross_region_replication ? var.replica_regions : []

    content {
      region     = replica.value
      kms_key_id = var.replica_kms_key_ids[replica.value]
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name       = "${var.project_name}-bedrock-third-party-keys-${var.environment}"
      SecretType = "third-party-api-keys"
      Rotation   = "manual"
    }
  )
}

resource "aws_secretsmanager_secret_version" "third_party_keys" {
  count = length(var.third_party_api_keys) > 0 ? 1 : 0

  secret_id     = aws_secretsmanager_secret.third_party_keys[0].id
  secret_string = jsonencode(var.third_party_api_keys)

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# ==============================================================================
# Secrets Rotation - Lambda Function
# ==============================================================================

resource "aws_lambda_function" "secrets_rotation" {
  count = var.enable_rotation ? 1 : 0

  filename      = var.rotation_lambda_zip_path
  function_name = "${var.project_name}-secrets-rotation-${var.environment}"
  role          = aws_iam_role.secrets_rotation[0].arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 300

  environment {
    variables = {
      SECRETS_MANAGER_ENDPOINT = "https://secretsmanager.${data.aws_region.current.name}.amazonaws.com"
      PROJECT_NAME             = var.project_name
      ENVIRONMENT              = var.environment
      SNS_TOPIC_ARN            = var.sns_topic_arn
    }
  }

  vpc_config {
    subnet_ids         = var.lambda_subnet_ids
    security_group_ids = var.lambda_security_group_ids
  }

  tags = local.common_tags
}

resource "aws_iam_role" "secrets_rotation" {
  count = var.enable_rotation ? 1 : 0

  name = "${var.project_name}-secrets-rotation-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "secrets_rotation_basic" {
  count = var.enable_rotation ? 1 : 0

  role       = aws_iam_role.secrets_rotation[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "secrets_rotation_vpc" {
  count = var.enable_rotation && length(var.lambda_subnet_ids) > 0 ? 1 : 0

  role       = aws_iam_role.secrets_rotation[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "secrets_rotation_policy" {
  count = var.enable_rotation ? 1 : 0

  name = "secrets-rotation-policy"
  role = aws_iam_role.secrets_rotation[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecretVersionStage"
        ]
        Resource = [
          aws_secretsmanager_secret.bedrock_api_keys.arn,
          var.enable_database_secrets ? aws_secretsmanager_secret.database_credentials[0].arn : ""
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetRandomPassword"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey"
        ]
        Resource = var.kms_key_arn
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = var.sns_topic_arn
      }
    ]
  })
}

resource "aws_lambda_permission" "secrets_rotation" {
  count = var.enable_rotation ? 1 : 0

  statement_id  = "AllowExecutionFromSecretsManager"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.secrets_rotation[0].function_name
  principal     = "secretsmanager.amazonaws.com"
}

# ==============================================================================
# Secrets Rotation Configuration
# ==============================================================================

resource "aws_secretsmanager_secret_rotation" "bedrock_api_keys" {
  count = var.enable_rotation ? 1 : 0

  secret_id           = aws_secretsmanager_secret.bedrock_api_keys.id
  rotation_lambda_arn = aws_lambda_function.secrets_rotation[0].arn

  rotation_rules {
    automatically_after_days = var.rotation_days
  }
}

resource "aws_secretsmanager_secret_rotation" "database_credentials" {
  count = var.enable_rotation && var.enable_database_secrets ? 1 : 0

  secret_id           = aws_secretsmanager_secret.database_credentials[0].id
  rotation_lambda_arn = aws_lambda_function.secrets_rotation[0].arn

  rotation_rules {
    automatically_after_days = var.rotation_days
  }
}

# ==============================================================================
# Resource Policy for Secrets Access
# ==============================================================================

resource "aws_secretsmanager_secret_policy" "bedrock_api_keys" {
  secret_arn = aws_secretsmanager_secret.bedrock_api_keys.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableIAMRoleAccess"
        Effect = "Allow"
        Principal = {
          AWS = var.iam_role_arns
        }
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
      },
      {
        Sid       = "DenyUnencryptedAccess"
        Effect    = "Deny"
        Principal = "*"
        Action    = "secretsmanager:GetSecretValue"
        Resource  = "*"
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# ==============================================================================
# CloudWatch Alarms for Secrets
# ==============================================================================

resource "aws_cloudwatch_log_metric_filter" "secrets_access" {
  name           = "${var.project_name}-secrets-access-${var.environment}"
  log_group_name = var.cloudtrail_log_group_name
  pattern        = "{ ($.eventName = GetSecretValue) && ($.requestParameters.secretId = \"${var.project_name}/*\") }"

  metric_transformation {
    name      = "SecretsAccess"
    namespace = "${var.project_name}/Security"
    value     = "1"

    dimensions = {
      Environment = var.environment
      SecretName  = "$.requestParameters.secretId"
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "secrets_access_high" {
  alarm_name          = "${var.project_name}-secrets-access-high-${var.environment}"
  alarm_description   = "Alert on high number of secrets access attempts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "SecretsAccess"
  namespace           = "${var.project_name}/Security"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.secrets_access_threshold
  treat_missing_data  = "notBreaching"

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]

  tags = local.common_tags
}

resource "aws_cloudwatch_log_metric_filter" "rotation_failures" {
  name           = "${var.project_name}-rotation-failures-${var.environment}"
  log_group_name = var.enable_rotation ? "/aws/lambda/${aws_lambda_function.secrets_rotation[0].function_name}" : var.cloudtrail_log_group_name
  pattern        = "[timestamp, request_id, level = ERROR*, ...]"

  metric_transformation {
    name      = "RotationFailures"
    namespace = "${var.project_name}/Security"
    value     = "1"

    dimensions = {
      Environment = var.environment
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "rotation_failures" {
  alarm_name          = "${var.project_name}-rotation-failures-${var.environment}"
  alarm_description   = "Alert on secrets rotation failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "RotationFailures"
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
# EventBridge Rule for Rotation Events
# ==============================================================================

resource "aws_cloudwatch_event_rule" "rotation_success" {
  name        = "${var.project_name}-secrets-rotation-success-${var.environment}"
  description = "Capture successful secrets rotation events"

  event_pattern = jsonencode({
    source      = ["aws.secretsmanager"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventName = ["RotationSucceeded"]
    }
  })

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "rotation_success_sns" {
  rule      = aws_cloudwatch_event_rule.rotation_success.name
  target_id = "SendToSNS"
  arn       = var.sns_topic_arn
}

resource "aws_cloudwatch_event_rule" "rotation_failed" {
  name        = "${var.project_name}-secrets-rotation-failed-${var.environment}"
  description = "Capture failed secrets rotation events"

  event_pattern = jsonencode({
    source      = ["aws.secretsmanager"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventName = ["RotationFailed"]
    }
  })

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "rotation_failed_sns" {
  rule      = aws_cloudwatch_event_rule.rotation_failed.name
  target_id = "SendToSNS"
  arn       = var.sns_topic_arn
}

# ==============================================================================
# Data Sources
# ==============================================================================

data "aws_region" "current" {}
