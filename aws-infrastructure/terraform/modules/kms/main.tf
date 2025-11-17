# AWS KMS Module - 2025 Best Practices
# Equivalent to GCP Cloud KMS

terraform {
  required_version = ">= 1.11.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }
}

resource "aws_kms_key" "main" {
  for_each = var.keys

  description             = "KMS key for ${each.key}"
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = true
  multi_region            = var.enable_multi_region

  tags = merge(
    var.tags,
    {
      Name    = "${var.key_prefix}-${each.key}"
      Purpose = each.key
    }
  )
}

resource "aws_kms_alias" "main" {
  for_each = var.keys

  name          = "alias/${var.key_prefix}-${each.key}"
  target_key_id = aws_kms_key.main[each.key].key_id
}
