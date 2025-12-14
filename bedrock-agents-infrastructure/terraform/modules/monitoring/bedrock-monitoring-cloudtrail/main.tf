# CloudTrail Audit Logging for Bedrock Agents
# Provides comprehensive audit trail for all API activity

locals {
  trail_name     = var.trail_name != null ? var.trail_name : "${var.project_name}-${var.environment}-trail"
  bucket_name    = var.create_s3_bucket ? "${var.project_name}-${var.environment}-cloudtrail-${data.aws_caller_identity.current.account_id}" : var.s3_bucket_name
  log_group_name = var.create_cloudwatch_logs_group ? "/aws/cloudtrail/${var.project_name}-${var.environment}" : var.cloudwatch_logs_group_name
  kms_key_id_normalized = var.kms_key_id == null ? null : (
    can(regex("^arn:", var.kms_key_id)) || can(regex("^alias/", var.kms_key_id))
    ? var.kms_key_id
    : "arn:aws:kms:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:key/${var.kms_key_id}"
  )

  common_tags = merge(
    var.tags,
    {
      Module      = "bedrock-monitoring-cloudtrail"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )

  # Use advanced event selectors from variable (which has proper defaults)
  bedrock_advanced_selectors = var.advanced_event_selectors
}

# ============================================================================
# S3 Bucket for CloudTrail
# ============================================================================

resource "aws_s3_bucket" "cloudtrail" {
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

resource "aws_s3_bucket_versioning" "cloudtrail" {
  count = var.create_s3_bucket ? 1 : 0

  bucket = aws_s3_bucket.cloudtrail[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  count = var.create_s3_bucket ? 1 : 0

  bucket = aws_s3_bucket.cloudtrail[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_id != null ? "aws:kms" : "AES256"
      kms_master_key_id = local.kms_key_id_normalized
    }
    bucket_key_enabled = var.kms_key_id != null
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  count = var.create_s3_bucket ? 1 : 0

  bucket = aws_s3_bucket.cloudtrail[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  count = var.create_s3_bucket ? 1 : 0

  bucket = aws_s3_bucket.cloudtrail[0].id

  rule {
    id     = "cloudtrail-lifecycle"
    status = "Enabled"

    transition {
      days          = var.s3_lifecycle_transition_days
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = var.s3_lifecycle_transition_days * 2
      storage_class = "GLACIER"
    }

    expiration {
      days = var.s3_lifecycle_expiration_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# Bucket policy for CloudTrail
resource "aws_s3_bucket_policy" "cloudtrail" {
  count = var.create_s3_bucket ? 1 : 0

  bucket = aws_s3_bucket.cloudtrail[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail[0].arn
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = "arn:aws:cloudtrail:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:trail/${local.trail_name}"
          }
        }
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail[0].arn}/${var.s3_key_prefix}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"  = "bucket-owner-full-control"
            "AWS:SourceArn" = "arn:aws:cloudtrail:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:trail/${local.trail_name}"
          }
        }
      }
    ]
  })
}

# ============================================================================
# CloudWatch Logs for CloudTrail
# ============================================================================

resource "aws_cloudwatch_log_group" "cloudtrail" {
  count = var.create_cloudwatch_logs_group ? 1 : 0

  name              = local.log_group_name
  retention_in_days = var.cloudwatch_logs_retention_days
  kms_key_id        = local.kms_key_id_normalized

  tags = local.common_tags
}

# IAM Role for CloudTrail to write to CloudWatch Logs
resource "aws_iam_role" "cloudtrail_cloudwatch" {
  count = var.create_cloudwatch_logs_group ? 1 : 0

  name = "${var.project_name}-${var.environment}-cloudtrail-cloudwatch"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "cloudtrail_cloudwatch" {
  count = var.create_cloudwatch_logs_group ? 1 : 0

  name = "${var.project_name}-${var.environment}-cloudtrail-cloudwatch"
  role = aws_iam_role.cloudtrail_cloudwatch[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.cloudtrail[0].arn}:*"
      }
    ]
  })
}

# ============================================================================
# SNS Topic for CloudTrail
# ============================================================================

resource "aws_sns_topic" "cloudtrail" {
  count = var.sns_topic_name != null ? 1 : 0

  name              = var.sns_topic_name
  display_name      = "CloudTrail Notifications"
  kms_master_key_id = local.kms_key_id_normalized

  tags = local.common_tags
}

resource "aws_sns_topic_policy" "cloudtrail" {
  count = var.sns_topic_name != null ? 1 : 0

  arn = aws_sns_topic.cloudtrail[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailSNSPolicy"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.cloudtrail[0].arn
      }
    ]
  })
}

# ============================================================================
# CloudTrail
# ============================================================================

resource "aws_cloudtrail" "main" {
  count = var.enable_trail ? 1 : 0

  name                          = local.trail_name
  s3_bucket_name                = local.bucket_name
  s3_key_prefix                 = var.s3_key_prefix
  include_global_service_events = var.include_global_service_events
  is_multi_region_trail         = var.is_multi_region_trail
  enable_log_file_validation    = var.enable_log_file_validation
  kms_key_id                    = local.kms_key_id_normalized
  sns_topic_name                = try(aws_sns_topic.cloudtrail[0].name, null)

  cloud_watch_logs_group_arn = var.create_cloudwatch_logs_group ? "${aws_cloudwatch_log_group.cloudtrail[0].arn}:*" : null
  cloud_watch_logs_role_arn  = var.create_cloudwatch_logs_group ? aws_iam_role.cloudtrail_cloudwatch[0].arn : null

  # Event selectors (basic)
  dynamic "event_selector" {
    for_each = !var.use_advanced_event_selectors ? var.event_selectors : []

    content {
      read_write_type           = event_selector.value.read_write_type
      include_management_events = event_selector.value.include_management_events

      dynamic "data_resource" {
        for_each = event_selector.value.data_resources

        content {
          type   = data_resource.value.type
          values = data_resource.value.values
        }
      }
    }
  }

  # Advanced event selectors
  dynamic "advanced_event_selector" {
    for_each = var.use_advanced_event_selectors ? local.bedrock_advanced_selectors : []

    content {
      name = advanced_event_selector.value.name

      dynamic "field_selector" {
        for_each = advanced_event_selector.value.field_selectors

        content {
          field           = field_selector.value.field
          equals          = lookup(field_selector.value, "equals", null)
          not_equals      = lookup(field_selector.value, "not_equals", null)
          starts_with     = lookup(field_selector.value, "starts_with", null)
          not_starts_with = lookup(field_selector.value, "not_starts_with", null)
        }
      }
    }
  }

  # Insights
  dynamic "insight_selector" {
    for_each = var.enable_insights ? var.insight_selector_type : []

    content {
      insight_type = insight_selector.value
    }
  }

  depends_on = [
    aws_s3_bucket_policy.cloudtrail,
    aws_iam_role_policy.cloudtrail_cloudwatch
  ]

  tags = local.common_tags
}

# ============================================================================
# CloudWatch Insights Queries
# ============================================================================

resource "aws_cloudwatch_query_definition" "bedrock_api_calls" {
  count = var.create_cloudwatch_logs_group ? 1 : 0

  name = "${var.project_name}-${var.environment}-bedrock-api-calls"

  log_group_names = [aws_cloudwatch_log_group.cloudtrail[0].name]

  query_string = <<-QUERY
    fields @timestamp, eventName, eventSource, userIdentity.principalId, sourceIPAddress, errorCode, errorMessage
    | filter eventSource = "bedrock.amazonaws.com"
    | sort @timestamp desc
    | limit 100
  QUERY
}

resource "aws_cloudwatch_query_definition" "bedrock_errors" {
  count = var.create_cloudwatch_logs_group ? 1 : 0

  name = "${var.project_name}-${var.environment}-bedrock-errors"

  log_group_names = [aws_cloudwatch_log_group.cloudtrail[0].name]

  query_string = <<-QUERY
    fields @timestamp, eventName, eventSource, userIdentity.principalId, errorCode, errorMessage
    | filter eventSource = "bedrock.amazonaws.com" and ispresent(errorCode)
    | sort @timestamp desc
    | limit 100
  QUERY
}

resource "aws_cloudwatch_query_definition" "unauthorized_api_calls" {
  count = var.create_cloudwatch_logs_group ? 1 : 0

  name = "${var.project_name}-${var.environment}-unauthorized-calls"

  log_group_names = [aws_cloudwatch_log_group.cloudtrail[0].name]

  query_string = <<-QUERY
    fields @timestamp, eventName, eventSource, userIdentity.principalId, sourceIPAddress, errorCode
    | filter errorCode = "AccessDenied" or errorCode = "UnauthorizedOperation"
    | sort @timestamp desc
    | limit 100
  QUERY
}

# ============================================================================
# Data Sources
# ============================================================================

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
