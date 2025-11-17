# KMS Configuration Examples

## Customer-Managed Key Creation

### Terraform Configuration

```hcl
# KMS Key for Bedrock Agents
resource "aws_kms_key" "bedrock_key" {
  description             = "KMS key for Bedrock Agents encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    Environment = "production"
    Purpose     = "bedrock-agents-encryption"
  }
}

# Key Alias
resource "aws_kms_alias" "bedrock_alias" {
  name          = "alias/bedrock-agents-key"
  target_key_id = aws_kms_key.bedrock_key.key_id
}

# Key Policy
resource "aws_kms_key_policy" "bedrock_policy" {
  key_id = aws_kms_key.bedrock_key.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM Root Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Services to Use Key"
        Effect = "Allow"
        Principal = {
          Service = [
            "s3.amazonaws.com",
            "rds.amazonaws.com",
            "dynamodb.amazonaws.com",
            "logs.amazonaws.com"
          ]
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow Lambda Execution Role"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.lambda_execution_role.arn
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow CloudTrail to Encrypt Logs"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "kms:GenerateDataKey"
        Resource = "*"
        Condition = {
          StringLike = {
            "kms:EncryptionContext:aws:cloudtrail:arn" = "arn:aws:cloudtrail:*:${data.aws_caller_identity.current.account_id}:trail/*"
          }
        }
      }
    ]
  })
}
```

## S3 Bucket Encryption

### Terraform Configuration

```hcl
# Bedrock Agents Data Bucket
resource "aws_s3_bucket" "bedrock_data" {
  bucket = "bedrock-agents-data-${data.aws_caller_identity.current.account_id}"

  tags = {
    Environment = "production"
    Encryption  = "kms"
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "bedrock_data" {
  bucket = aws_s3_bucket.bedrock_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "bedrock_data" {
  bucket = aws_s3_bucket.bedrock_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.bedrock_key.arn
    }
    bucket_key_enabled = true
  }
}

# Enforce encryption policy
resource "aws_s3_bucket_policy" "bedrock_data" {
  bucket = aws_s3_bucket.bedrock_data.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyUnencryptedObjectUploads"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:PutObject"
        Resource = "${aws_s3_bucket.bedrock_data.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      },
      {
        Sid    = "DenyIncorrectKmsKey"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:PutObject"
        Resource = "${aws_s3_bucket.bedrock_data.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption-aws-kms-key-id" = aws_kms_key.bedrock_key.arn
          }
        }
      }
    ]
  })
}

# Versioning for recovery
resource "aws_s3_bucket_versioning" "bedrock_data" {
  bucket = aws_s3_bucket.bedrock_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

# MFA Delete protection
resource "aws_s3_bucket_versioning" "bedrock_data_mfa" {
  bucket = aws_s3_bucket.bedrock_data.id

  versioning_configuration {
    status             = "Enabled"
    mfa_delete         = "Enabled"
    expected_bucket_owner = data.aws_caller_identity.current.account_id
  }
}
```

## RDS Database Encryption

### Terraform Configuration

```hcl
# RDS Cluster with encryption
resource "aws_rds_cluster" "bedrock_db" {
  cluster_identifier      = "bedrock-cluster"
  engine                  = "aurora-postgresql"
  engine_version          = "15.2"
  database_name           = "bedrock"
  master_username         = "admin"
  master_password         = random_password.db_password.result

  # Encryption configuration
  storage_encrypted       = true
  kms_key_id              = aws_kms_key.bedrock_key.arn

  # Availability and backup
  db_subnet_group_name    = aws_db_subnet_group.bedrock.name
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.bedrock.name

  # Backup and recovery
  backup_retention_period = 30
  preferred_backup_window = "03:00-04:00"
  preferred_maintenance_window = "mon:04:00-mon:05:00"

  # Audit logging
  enable_cloudwatch_logs_exports = [
    "postgresql"
  ]

  # Enhanced monitoring
  enabled_cloudwatch_logs_exports = ["postgresql"]

  # Security
  publicly_accessible    = false
  deletion_protection    = true

  tags = {
    Environment = "production"
    Encryption  = "kms"
  }
}

# RDS Instance
resource "aws_rds_cluster_instance" "bedrock_db" {
  count              = 2
  cluster_identifier = aws_rds_cluster.bedrock_db.id
  instance_class     = "db.r5.large"
  engine              = aws_rds_cluster.bedrock_db.engine
  engine_version      = aws_rds_cluster.bedrock_db.engine_version

  # Performance monitoring
  performance_insights_enabled    = true
  performance_insights_kms_key_id = aws_kms_key.bedrock_key.arn

  # Public access disabled
  publicly_accessible = false

  tags = {
    Environment = "production"
    Role        = count.index == 0 ? "primary" : "replica"
  }
}

# DB Subnet Group
resource "aws_db_subnet_group" "bedrock" {
  name       = "bedrock-subnet-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  tags = {
    Environment = "production"
  }
}

# DB Security Group
resource "aws_security_group" "bedrock_db" {
  name   = "bedrock-db-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
    description     = "PostgreSQL from app tier"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = "production"
  }
}
```

## DynamoDB Encryption

### Terraform Configuration

```hcl
resource "aws_dynamodb_table" "agent_state" {
  name           = "agent-state"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "agent_id"
  range_key      = "timestamp"

  # Encryption
  sse_specification {
    enabled     = true
    kms_key_arn = aws_kms_key.bedrock_key.arn
  }

  # Point-in-time recovery
  point_in_time_recovery_specification {
    enabled = true
  }

  # Streams
  stream_specification {
    stream_view_type = "NEW_AND_OLD_IMAGES"
  }

  # Attributes
  attribute {
    name = "agent_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  # TTL
  ttl {
    attribute_name = "expiration"
    enabled        = true
  }

  # Backup
  tags = {
    Environment = "production"
    Encryption  = "kms"
    Backup      = "enabled"
  }
}

# DynamoDB Backup
resource "aws_dynamodb_backup" "agent_state" {
  table_name = aws_dynamodb_table.agent_state.name
  backup_name = "agent-state-backup-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
}

# Point-in-time recovery (enabled via stream)
resource "aws_dynamodb_continuous_backups" "agent_state" {
  table_name = aws_dynamodb_table.agent_state.name

  point_in_time_recovery_specification {
    point_in_time_recovery_enabled = true
  }
}
```

---

**Version**: 1.0
**Updated**: November 2024
