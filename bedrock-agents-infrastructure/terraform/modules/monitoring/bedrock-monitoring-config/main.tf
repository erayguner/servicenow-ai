# AWS Config Compliance Monitoring for Bedrock Agents
# Provides continuous compliance checking and remediation

locals {
  bucket_name = var.create_s3_bucket ? "${var.project_name}-${var.environment}-config-${data.aws_caller_identity.current.account_id}" : var.s3_bucket_name
  recorder_name = "${var.project_name}-${var.environment}-recorder"

  common_tags = merge(
    var.tags,
    {
      Module      = "bedrock-monitoring-config"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

# ============================================================================
# S3 Bucket for Config
# ============================================================================

resource "aws_s3_bucket" "config" {
  count = var.create_s3_bucket ? 1 : 0

  bucket        = local.bucket_name
  force_destroy = var.environment != "prod"

  tags = merge(
    local.common_tags,
    {
      Name = local.bucket_name
    }
  )
}

resource "aws_s3_bucket_versioning" "config" {
  count = var.create_s3_bucket ? 1 : 0

  bucket = aws_s3_bucket.config[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config" {
  count = var.create_s3_bucket ? 1 : 0

  bucket = aws_s3_bucket.config[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_id != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_id
    }
    bucket_key_enabled = var.kms_key_id != null
  }
}

resource "aws_s3_bucket_public_access_block" "config" {
  count = var.create_s3_bucket ? 1 : 0

  bucket = aws_s3_bucket.config[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "config" {
  count = var.create_s3_bucket ? 1 : 0

  bucket = aws_s3_bucket.config[0].id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 180
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}

# Bucket policy for Config
resource "aws_s3_bucket_policy" "config" {
  count = var.create_s3_bucket ? 1 : 0

  bucket = aws_s3_bucket.config[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSConfigBucketPermissionsCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.config[0].arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "AWSConfigBucketExistenceCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.config[0].arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "AWSConfigBucketPut"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.config[0].arn}/${var.s3_key_prefix}/AWSLogs/${data.aws_caller_identity.current.account_id}/Config/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"      = "bucket-owner-full-control"
            "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# ============================================================================
# IAM Role for Config
# ============================================================================

resource "aws_iam_role" "config" {
  count = var.enable_config ? 1 : 0

  name = "${var.project_name}-${var.environment}-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "config" {
  count = var.enable_config ? 1 : 0

  role       = aws_iam_role.config[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/ConfigRole"
}

resource "aws_iam_role_policy" "config" {
  count = var.enable_config ? 1 : 0

  name = "${var.project_name}-${var.environment}-config-policy"
  role = aws_iam_role.config[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketVersioning",
          "s3:PutObject",
          "s3:GetObject"
        ]
        Resource = [
          var.create_s3_bucket ? aws_s3_bucket.config[0].arn : "arn:aws:s3:::${var.s3_bucket_name}",
          var.create_s3_bucket ? "${aws_s3_bucket.config[0].arn}/*" : "arn:aws:s3:::${var.s3_bucket_name}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = var.sns_topic_arn != null ? [var.sns_topic_arn] : []
      }
    ]
  })
}

# ============================================================================
# Config Recorder
# ============================================================================

resource "aws_config_configuration_recorder" "main" {
  count = var.enable_config ? 1 : 0

  name     = local.recorder_name
  role_arn = aws_iam_role.config[0].arn

  recording_group {
    all_supported                 = false
    include_global_resource_types = var.include_global_resource_types
    resource_types                = var.resource_types
  }

  recording_mode {
    recording_frequency = var.recording_frequency
  }
}

resource "aws_config_delivery_channel" "main" {
  count = var.enable_config ? 1 : 0

  name           = "${var.project_name}-${var.environment}-delivery-channel"
  s3_bucket_name = local.bucket_name
  s3_key_prefix  = var.s3_key_prefix
  sns_topic_arn  = var.sns_topic_arn

  snapshot_delivery_properties {
    delivery_frequency = var.delivery_frequency
  }

  depends_on = [
    aws_config_configuration_recorder.main,
    aws_s3_bucket_policy.config
  ]
}

resource "aws_config_configuration_recorder_status" "main" {
  count = var.enable_config && var.enable_recorder ? 1 : 0

  name       = aws_config_configuration_recorder.main[0].name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.main]
}

# ============================================================================
# Config Rules - Encryption
# ============================================================================

# Check if S3 buckets are encrypted
resource "aws_config_config_rule" "s3_bucket_encryption" {
  count = var.enable_compliance_rules ? 1 : 0

  name = "${var.project_name}-${var.environment}-s3-encryption"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder.main]

  tags = local.common_tags
}

# Check if KMS keys have rotation enabled
resource "aws_config_config_rule" "kms_key_rotation" {
  count = var.enable_compliance_rules ? 1 : 0

  name = "${var.project_name}-${var.environment}-kms-rotation"

  source {
    owner             = "AWS"
    source_identifier = "CMK_BACKING_KEY_ROTATION_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder.main]

  tags = local.common_tags
}

# Check if CloudWatch Logs are encrypted
resource "aws_config_config_rule" "cloudwatch_logs_encryption" {
  count = var.enable_compliance_rules ? 1 : 0

  name = "${var.project_name}-${var.environment}-logs-encryption"

  source {
    owner             = "AWS"
    source_identifier = "CLOUDWATCH_LOG_GROUP_ENCRYPTED"
  }

  depends_on = [aws_config_configuration_recorder.main]

  tags = local.common_tags
}

# ============================================================================
# Config Rules - Access Control
# ============================================================================

# Check if S3 buckets block public access
resource "aws_config_config_rule" "s3_public_access" {
  count = var.enable_compliance_rules ? 1 : 0

  name = "${var.project_name}-${var.environment}-s3-public-access"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }

  depends_on = [aws_config_configuration_recorder.main]

  tags = local.common_tags
}

# Check if IAM policies are attached only to groups or roles
resource "aws_config_config_rule" "iam_user_no_policies" {
  count = var.enable_compliance_rules ? 1 : 0

  name = "${var.project_name}-${var.environment}-iam-user-no-policies"

  source {
    owner             = "AWS"
    source_identifier = "IAM_USER_NO_POLICIES_CHECK"
  }

  depends_on = [aws_config_configuration_recorder.main]

  tags = local.common_tags
}

# ============================================================================
# Config Rules - Lambda
# ============================================================================

# Check if Lambda functions have DLQ configured
resource "aws_config_config_rule" "lambda_dlq" {
  count = var.enable_compliance_rules ? 1 : 0

  name = "${var.project_name}-${var.environment}-lambda-dlq"

  source {
    owner             = "AWS"
    source_identifier = "LAMBDA_DLQ_CHECK"
  }

  depends_on = [aws_config_configuration_recorder.main]

  tags = local.common_tags
}

# Check if Lambda functions are in VPC
resource "aws_config_config_rule" "lambda_in_vpc" {
  count = var.enable_compliance_rules ? 1 : 0

  name = "${var.project_name}-${var.environment}-lambda-in-vpc"

  source {
    owner             = "AWS"
    source_identifier = "LAMBDA_INSIDE_VPC"
  }

  depends_on = [aws_config_configuration_recorder.main]

  tags = local.common_tags
}

# ============================================================================
# Config Aggregator
# ============================================================================

resource "aws_config_configuration_aggregator" "main" {
  count = var.enable_aggregator ? 1 : 0

  name = "${var.project_name}-${var.environment}-aggregator"

  account_aggregation_source {
    account_ids = length(var.aggregator_account_ids) > 0 ? var.aggregator_account_ids : [data.aws_caller_identity.current.account_id]
    regions     = length(var.aggregator_regions) > 0 ? var.aggregator_regions : [data.aws_region.current.name]
  }

  tags = local.common_tags
}

# ============================================================================
# Data Sources
# ============================================================================

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
