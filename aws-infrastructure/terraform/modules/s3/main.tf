# AWS S3 Module - 2025 Best Practices
# Equivalent to GCP Cloud Storage

terraform {
  required_version = ">= 1.11.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }
}

locals {
  common_tags = merge(
    var.tags,
    {
      ManagedBy   = "Terraform"
      Module      = "s3"
      Environment = var.environment
    }
  )
}

resource "aws_s3_bucket" "main" {
  for_each = { for bucket in var.buckets : bucket.name => bucket }

  bucket = each.value.name

  tags = merge(
    local.common_tags,
    {
      Name = each.value.name
    }
  )
}

# Enable versioning
resource "aws_s3_bucket_versioning" "main" {
  for_each = { for bucket in var.buckets : bucket.name => bucket if bucket.versioning_enabled }

  bucket = aws_s3_bucket.main[each.key].id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption with KMS
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  for_each = { for bucket in var.buckets : bucket.name => bucket }

  bucket = aws_s3_bucket.main[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = each.value.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

# Block public access (2025 security best practice)
resource "aws_s3_bucket_public_access_block" "main" {
  for_each = { for bucket in var.buckets : bucket.name => bucket }

  bucket = aws_s3_bucket.main[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle rules
resource "aws_s3_bucket_lifecycle_configuration" "main" {
  for_each = { for bucket in var.buckets : bucket.name => bucket if length(bucket.lifecycle_rules) > 0 }

  bucket = aws_s3_bucket.main[each.key].id

  dynamic "rule" {
    for_each = each.value.lifecycle_rules
    content {
      id     = rule.value.id
      status = "Enabled"

      dynamic "transition" {
        for_each = rule.value.transitions != null ? rule.value.transitions : []
        content {
          days          = transition.value.days
          storage_class = transition.value.storage_class
        }
      }

      dynamic "expiration" {
        for_each = rule.value.expiration_days != null ? [1] : []
        content {
          days = rule.value.expiration_days
        }
      }
    }
  }
}

# S3 Intelligent-Tiering configuration (2025 cost optimization)
resource "aws_s3_bucket_intelligent_tiering_configuration" "main" {
  for_each = { for bucket in var.buckets : bucket.name => bucket if bucket.enable_intelligent_tiering }

  bucket = aws_s3_bucket.main[each.key].id
  name   = "EntireDataset"

  tiering {
    access_tier = "ARCHIVE_ACCESS"
    days        = 90
  }

  tiering {
    access_tier = "DEEP_ARCHIVE_ACCESS"
    days        = 180
  }
}

# Event notifications to EventBridge (2025 best practice)
resource "aws_s3_bucket_notification" "main" {
  for_each = { for bucket in var.buckets : bucket.name => bucket if bucket.enable_eventbridge }

  bucket      = aws_s3_bucket.main[each.key].id
  eventbridge = true
}
