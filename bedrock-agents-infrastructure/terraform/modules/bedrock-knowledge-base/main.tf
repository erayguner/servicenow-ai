# S3 Bucket for Documents
resource "aws_s3_bucket" "documents" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = var.s3_bucket_name != null ? var.s3_bucket_name : "${var.knowledge_base_name}-documents"

  tags = merge(
    var.tags,
    {
      Name      = "${var.knowledge_base_name}-documents"
      ManagedBy = "Terraform"
      Component = "BedrockKnowledgeBase"
    }
  )
}

resource "aws_s3_bucket_versioning" "documents" {
  count  = var.create_s3_bucket && var.enable_versioning ? 1 : 0
  bucket = aws_s3_bucket.documents[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "documents" {
  count  = var.create_s3_bucket && var.enable_server_side_encryption ? 1 : 0
  bucket = aws_s3_bucket.documents[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_id != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_id
    }
    bucket_key_enabled = var.kms_key_id != null ? true : false
  }
}

resource "aws_s3_bucket_public_access_block" "documents" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = aws_s3_bucket.documents[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# OpenSearch Serverless Collection
resource "aws_opensearchserverless_security_policy" "encryption" {
  name        = "${var.knowledge_base_name}-encryption-policy"
  type        = "encryption"
  description = "Encryption policy for ${var.knowledge_base_name} OpenSearch Serverless collection"

  policy = jsonencode({
    Rules = [
      {
        ResourceType = "collection"
        Resource = [
          "collection/${local.collection_name}"
        ]
      }
    ]
    AWSOwnedKey = true
  })
}

resource "aws_opensearchserverless_security_policy" "network" {
  name        = "${var.knowledge_base_name}-network-policy"
  type        = "network"
  description = "Network policy for ${var.knowledge_base_name} OpenSearch Serverless collection"

  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "collection"
          Resource = [
            "collection/${local.collection_name}"
          ]
        },
        {
          ResourceType = "dashboard"
          Resource = [
            "collection/${local.collection_name}"
          ]
        }
      ]
      AllowFromPublic = !var.enable_vpc_configuration
      SourceVPCEs     = var.enable_vpc_configuration ? var.vpc_subnet_ids : null
    }
  ])
}

resource "aws_opensearchserverless_access_policy" "data_access" {
  name        = "${var.knowledge_base_name}-data-access-policy"
  type        = "data"
  description = "Data access policy for ${var.knowledge_base_name} OpenSearch Serverless collection"

  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "collection"
          Resource = [
            "collection/${local.collection_name}"
          ]
          Permission = [
            "aoss:CreateCollectionItems",
            "aoss:DeleteCollectionItems",
            "aoss:UpdateCollectionItems",
            "aoss:DescribeCollectionItems"
          ]
        },
        {
          ResourceType = "index"
          Resource = [
            "index/${local.collection_name}/*"
          ]
          Permission = [
            "aoss:CreateIndex",
            "aoss:DeleteIndex",
            "aoss:UpdateIndex",
            "aoss:DescribeIndex",
            "aoss:ReadDocument",
            "aoss:WriteDocument"
          ]
        }
      ]
      Principal = [
        aws_iam_role.knowledge_base.arn,
        data.aws_caller_identity.current.arn
      ]
    }
  ])
}

resource "aws_opensearchserverless_collection" "this" {
  name             = local.collection_name
  type             = "VECTORSEARCH"
  description      = "OpenSearch Serverless collection for ${var.knowledge_base_name}"
  standby_replicas = var.standby_replicas

  tags = merge(
    var.tags,
    {
      Name      = local.collection_name
      ManagedBy = "Terraform"
      Component = "BedrockKnowledgeBase"
    }
  )

  depends_on = [
    aws_opensearchserverless_security_policy.encryption,
    aws_opensearchserverless_security_policy.network,
    aws_opensearchserverless_access_policy.data_access
  ]
}

# IAM Role for Knowledge Base
resource "aws_iam_role" "knowledge_base" {
  name               = "${var.knowledge_base_name}-kb-role"
  assume_role_policy = data.aws_iam_policy_document.knowledge_base_trust.json

  tags = merge(
    var.tags,
    {
      Name      = "${var.knowledge_base_name}-kb-role"
      ManagedBy = "Terraform"
      Component = "BedrockKnowledgeBase"
    }
  )
}

data "aws_iam_policy_document" "knowledge_base_trust" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["bedrock.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:bedrock:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:knowledge-base/*"]
    }
  }
}

resource "aws_iam_role_policy" "knowledge_base" {
  name   = "${var.knowledge_base_name}-kb-policy"
  role   = aws_iam_role.knowledge_base.id
  policy = data.aws_iam_policy_document.knowledge_base_permissions.json
}

data "aws_iam_policy_document" "knowledge_base_permissions" {
  # Bedrock model invocation for embeddings
  statement {
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel"
    ]
    resources = [
      local.embedding_model_arn
    ]
  }

  # S3 bucket access
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      local.s3_bucket_arn,
      "${local.s3_bucket_arn}/*"
    ]
  }

  # OpenSearch Serverless access
  statement {
    effect = "Allow"
    actions = [
      "aoss:APIAccessAll"
    ]
    resources = [
      aws_opensearchserverless_collection.this.arn
    ]
  }

  # KMS encryption (if enabled)
  dynamic "statement" {
    for_each = var.kms_key_id != null ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ]
      resources = ["arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/${var.kms_key_id}"]
    }
  }
}

# Bedrock Knowledge Base
resource "aws_bedrockagent_knowledge_base" "this" {
  name        = var.knowledge_base_name
  description = var.description
  role_arn    = aws_iam_role.knowledge_base.arn

  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = local.embedding_model_arn

      embedding_model_configuration {
        bedrock_embedding_model_configuration {
          dimensions = var.vector_dimension
        }
      }
    }
  }

  storage_configuration {
    type = "OPENSEARCH_SERVERLESS"
    opensearch_serverless_configuration {
      collection_arn    = aws_opensearchserverless_collection.this.arn
      vector_index_name = var.opensearch_index_name
      field_mapping {
        vector_field   = var.vector_field_name
        text_field     = var.text_field_name
        metadata_field = var.metadata_field_name
      }
    }
  }

  tags = merge(
    var.tags,
    {
      Name      = var.knowledge_base_name
      ManagedBy = "Terraform"
      Component = "BedrockKnowledgeBase"
    }
  )

  depends_on = [
    aws_iam_role_policy.knowledge_base,
    aws_opensearchserverless_collection.this
  ]
}

# Data Source for Knowledge Base
resource "aws_bedrockagent_data_source" "this" {
  knowledge_base_id    = aws_bedrockagent_knowledge_base.this.id
  name                 = "${var.knowledge_base_name}-s3-datasource"
  description          = "S3 data source for ${var.knowledge_base_name}"
  data_deletion_policy = var.data_deletion_policy

  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn         = local.s3_bucket_arn
      inclusion_prefixes = var.s3_bucket_prefix != "" ? [var.s3_bucket_prefix] : null
    }
  }

  vector_ingestion_configuration {
    chunking_configuration {
      chunking_strategy = var.chunking_strategy

      dynamic "fixed_size_chunking_configuration" {
        for_each = var.chunking_strategy == "FIXED_SIZE" ? [1] : []
        content {
          max_tokens         = var.max_tokens
          overlap_percentage = var.overlap_percentage
        }
      }
    }
  }

  depends_on = [aws_bedrockagent_knowledge_base.this]
}

# Local variables
locals {
  collection_name     = var.opensearch_collection_name != null ? var.opensearch_collection_name : "${var.knowledge_base_name}-collection"
  s3_bucket_arn       = var.create_s3_bucket ? aws_s3_bucket.documents[0].arn : var.existing_s3_bucket_arn
  embedding_model_arn = var.embedding_model_arn != null ? var.embedding_model_arn : "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/${var.embedding_model_id}"
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
