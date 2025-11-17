# AWS DynamoDB Module - 2025 Best Practices
# Equivalent to GCP Firestore

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  common_tags = merge(
    var.tags,
    {
      ManagedBy   = "Terraform"
      Module      = "dynamodb"
      Environment = var.environment
    }
  )
}

resource "aws_dynamodb_table" "main" {
  for_each = { for table in var.tables : table.name => table }

  name         = each.value.name
  billing_mode = each.value.billing_mode
  hash_key     = each.value.hash_key
  range_key    = each.value.range_key

  # For provisioned mode
  read_capacity  = each.value.billing_mode == "PROVISIONED" ? each.value.read_capacity : null
  write_capacity = each.value.billing_mode == "PROVISIONED" ? each.value.write_capacity : null

  # Attributes
  dynamic "attribute" {
    for_each = each.value.attributes
    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }

  # Global Secondary Indexes
  dynamic "global_secondary_index" {
    for_each = each.value.global_secondary_indexes != null ? each.value.global_secondary_indexes : []
    content {
      name            = global_secondary_index.value.name
      hash_key        = global_secondary_index.value.hash_key
      range_key       = global_secondary_index.value.range_key
      projection_type = global_secondary_index.value.projection_type
      read_capacity   = each.value.billing_mode == "PROVISIONED" ? global_secondary_index.value.read_capacity : null
      write_capacity  = each.value.billing_mode == "PROVISIONED" ? global_secondary_index.value.write_capacity : null
    }
  }

  # TTL
  dynamic "ttl" {
    for_each = each.value.ttl_attribute != null ? [1] : []
    content {
      enabled        = true
      attribute_name = each.value.ttl_attribute
    }
  }

  # Point-in-time recovery (2025 best practice)
  point_in_time_recovery {
    enabled = each.value.enable_point_in_time_recovery
  }

  # Server-side encryption
  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  # DynamoDB Streams
  stream_enabled   = each.value.enable_streams
  stream_view_type = each.value.enable_streams ? each.value.stream_view_type : null

  tags = merge(
    local.common_tags,
    {
      Name = each.value.name
    }
  )

  lifecycle {
    prevent_destroy = true
  }
}

# Auto Scaling for Provisioned tables (2025 best practice)
resource "aws_appautoscaling_target" "read" {
  for_each = { for table in var.tables : table.name => table if table.billing_mode == "PROVISIONED" && table.enable_autoscaling }

  max_capacity       = each.value.autoscaling_read_max
  min_capacity       = each.value.read_capacity
  resource_id        = "table/${aws_dynamodb_table.main[each.key].name}"
  scalable_dimension = "dynamodb:table:ReadCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "read" {
  for_each = { for table in var.tables : table.name => table if table.billing_mode == "PROVISIONED" && table.enable_autoscaling }

  name               = "${each.value.name}-read-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.read[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.read[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.read[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }
    target_value = 70.0
  }
}

resource "aws_appautoscaling_target" "write" {
  for_each = { for table in var.tables : table.name => table if table.billing_mode == "PROVISIONED" && table.enable_autoscaling }

  max_capacity       = each.value.autoscaling_write_max
  min_capacity       = each.value.write_capacity
  resource_id        = "table/${aws_dynamodb_table.main[each.key].name}"
  scalable_dimension = "dynamodb:table:WriteCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "write" {
  for_each = { for table in var.tables : table.name => table if table.billing_mode == "PROVISIONED" && table.enable_autoscaling }

  name               = "${each.value.name}-write-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.write[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.write[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.write[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
    }
    target_value = 70.0
  }
}
