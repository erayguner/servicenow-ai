# AWS Secrets Manager Module - 2025 Best Practices
# Equivalent to GCP Secret Manager

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_secretsmanager_secret" "main" {
  for_each = { for secret in var.secrets : secret.name => secret }

  name        = each.value.name
  description = each.value.description
  kms_key_id  = var.kms_key_arn

  recovery_window_in_days = each.value.recovery_window_in_days

  tags = merge(
    var.tags,
    {
      Name = each.value.name
    }
  )
}

resource "aws_secretsmanager_secret_rotation" "main" {
  for_each = { for secret in var.secrets : secret.name => secret if secret.enable_rotation }

  secret_id           = aws_secretsmanager_secret.main[each.key].id
  rotation_lambda_arn = each.value.rotation_lambda_arn

  rotation_rules {
    automatically_after_days = each.value.rotation_days
  }
}
