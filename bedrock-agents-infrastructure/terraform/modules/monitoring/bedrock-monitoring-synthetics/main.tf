# CloudWatch Synthetics for Bedrock Agents
# Provides synthetic monitoring with canary scripts

locals {
  bucket_name = var.create_s3_bucket ? "${var.project_name}-${var.environment}-synthetics-${data.aws_caller_identity.current.account_id}" : var.s3_bucket_name

  common_tags = merge(
    var.tags,
    {
      Module      = "bedrock-monitoring-synthetics"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )

  # Convert bedrock endpoints to canary format
  bedrock_canaries = {
    for endpoint in var.bedrock_agent_endpoints :
    endpoint.name => {
      endpoint_url        = endpoint.endpoint_url
      method              = "POST"
      expected_status     = 200
      timeout_seconds     = 60
      schedule_expression = "rate(5 minutes)"
      headers             = merge({ "Content-Type" = "application/json" }, endpoint.headers)
      body                = null
      runtime_version     = "syn-nodejs-puppeteer-9.1"
      handler             = "apiCanaryBlueprint.handler"
    }
  }

  all_canaries = merge(local.bedrock_canaries, var.canaries)
}

# ============================================================================
# S3 Bucket for Canary Artifacts
# ============================================================================

resource "aws_s3_bucket" "canary_artifacts" {
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

resource "aws_s3_bucket_versioning" "canary_artifacts" {
  count = var.create_s3_bucket ? 1 : 0

  bucket = aws_s3_bucket.canary_artifacts[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "canary_artifacts" {
  count = var.create_s3_bucket ? 1 : 0

  bucket = aws_s3_bucket.canary_artifacts[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_id != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_id
    }
    bucket_key_enabled = var.kms_key_id != null
  }
}

resource "aws_s3_bucket_public_access_block" "canary_artifacts" {
  count = var.create_s3_bucket ? 1 : 0

  bucket = aws_s3_bucket.canary_artifacts[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "canary_artifacts" {
  count = var.create_s3_bucket ? 1 : 0

  bucket = aws_s3_bucket.canary_artifacts[0].id

  rule {
    id     = "expire-artifacts"
    status = "Enabled"

    expiration {
      days = var.s3_lifecycle_expiration_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

# ============================================================================
# IAM Role for Canaries
# ============================================================================

resource "aws_iam_role" "canary" {
  count = var.enable_synthetics && length(local.all_canaries) > 0 ? 1 : 0

  name = "${var.project_name}-${var.environment}-canary-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "canary" {
  count = var.enable_synthetics && length(local.all_canaries) > 0 ? 1 : 0

  name = "${var.project_name}-${var.environment}-canary-policy"
  role = aws_iam_role.canary[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.create_s3_bucket ? aws_s3_bucket.canary_artifacts[0].arn : "arn:aws:s3:::${var.s3_bucket_name}",
          var.create_s3_bucket ? "${aws_s3_bucket.canary_artifacts[0].arn}/*" : "arn:aws:s3:::${var.s3_bucket_name}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/cwsyn-*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "CloudWatchSynthetics"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments"
        ]
        Resource = "*"
      }
    ]
  })
}

# VPC permissions if VPC config is provided
resource "aws_iam_role_policy_attachment" "canary_vpc" {
  count = var.enable_synthetics && var.vpc_config != null && length(local.all_canaries) > 0 ? 1 : 0

  role       = aws_iam_role.canary[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# ============================================================================
# Canary Scripts
# ============================================================================

# Create canary script files
resource "local_file" "canary_scripts" {
  for_each = var.enable_synthetics ? local.all_canaries : {}

  filename = "${path.module}/scripts/canary-${each.key}.js"
  content = templatefile("${path.module}/templates/api-canary.js.tpl", {
    endpoint_url    = each.value.endpoint_url
    method          = each.value.method
    expected_status = each.value.expected_status
    timeout         = each.value.timeout_seconds * 1000
    headers         = jsonencode(each.value.headers)
    body            = each.value.body != null ? jsonencode(each.value.body) : "null"
  })

  file_permission = "0644"
}

# Archive canary scripts
data "archive_file" "canary_scripts" {
  for_each = var.enable_synthetics ? local.all_canaries : {}

  type        = "zip"
  output_path = "${path.module}/scripts/canary-${each.key}.zip"

  source {
    content  = local_file.canary_scripts[each.key].content
    filename = "nodejs/node_modules/${each.value.handler == "apiCanaryBlueprint.handler" ? "apiCanaryBlueprint.js" : "index.js"}"
  }

  depends_on = [local_file.canary_scripts]
}

# ============================================================================
# Synthetics Canaries
# ============================================================================

resource "aws_synthetics_canary" "canaries" {
  for_each = var.enable_synthetics ? local.all_canaries : {}

  name                 = "${var.project_name}-${var.environment}-${each.key}"
  artifact_s3_location = "s3://${local.bucket_name}/canary-results"
  execution_role_arn   = aws_iam_role.canary[0].arn
  handler              = each.value.handler
  zip_file             = data.archive_file.canary_scripts[each.key].output_path
  runtime_version      = each.value.runtime_version
  start_canary         = true

  success_retention_period = var.success_retention_period
  failure_retention_period = var.failure_retention_period

  schedule {
    expression = each.value.schedule_expression
  }

  run_config {
    timeout_in_seconds = each.value.timeout_seconds
    memory_in_mb       = 1024
    active_tracing     = var.enable_active_tracing
    environment_variables = {
      ENDPOINT_URL    = each.value.endpoint_url
      METHOD          = each.value.method
      EXPECTED_STATUS = tostring(each.value.expected_status)
    }
  }

  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []

    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  artifact_config {
    s3_encryption {
      encryption_mode = var.kms_key_id != null ? "SSE_KMS" : "SSE_S3"
      kms_key_arn = var.kms_key_id != null ?
        "arn:aws:kms:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:key/${var.kms_key_id}"
        : null
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-${each.key}"
    }
  )

  depends_on = [
    aws_iam_role.canary,
    aws_iam_role_policy.canary
  ]
}

# ============================================================================
# CloudWatch Alarms for Canaries
# ============================================================================

resource "aws_cloudwatch_metric_alarm" "canary_failures" {
  for_each = var.enable_synthetics && var.alarm_sns_topic_arn != null ? local.all_canaries : {}

  alarm_name          = "${var.project_name}-${var.environment}-canary-${each.key}-failures"
  alarm_description   = "Canary ${each.key} is failing"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "SuccessPercent"
  namespace           = "CloudWatchSynthetics"
  period              = 300
  statistic           = "Average"
  threshold           = 90
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.alarm_sns_topic_arn]
  actions_enabled     = true

  dimensions = {
    CanaryName = aws_synthetics_canary.canaries[each.key].name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "canary_duration" {
  for_each = var.enable_synthetics && var.alarm_sns_topic_arn != null ? local.all_canaries : {}

  alarm_name          = "${var.project_name}-${var.environment}-canary-${each.key}-duration"
  alarm_description   = "Canary ${each.key} duration is high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Duration"
  namespace           = "CloudWatchSynthetics"
  period              = 300
  statistic           = "Average"
  threshold           = each.value.timeout_seconds * 1000 * 0.8 # 80% of timeout
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.alarm_sns_topic_arn]
  actions_enabled     = true

  dimensions = {
    CanaryName = aws_synthetics_canary.canaries[each.key].name
  }

  tags = local.common_tags
}

# ============================================================================
# Data Sources
# ============================================================================

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
