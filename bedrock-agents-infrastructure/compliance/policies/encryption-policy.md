# Encryption Policy

## Amazon Bedrock Agents Infrastructure

**Document Version:** 1.0 **Effective Date:** 2025-11-17 **Last Reviewed:**
2025-11-17 **Next Review:** 2026-11-17 **Policy Owner:** Chief Information
Security Officer (CISO) **Approved By:** Executive Leadership Team

---

## 1. Purpose

This Encryption Policy establishes requirements for the use of cryptography to
protect data confidentiality, integrity, and authenticity within the Amazon
Bedrock Agents infrastructure. The policy ensures compliance with regulatory
requirements (GDPR, HIPAA, PCI DSS, SOC 2, ISO 27001) and industry best
practices.

## 2. Scope

This policy applies to:

- All data processed by Amazon Bedrock agents (at rest and in transit)
- All AWS services supporting Bedrock infrastructure
- All cryptographic keys and certificates
- All environments (development, staging, production)
- All personnel with access to encryption systems
- All third-party integrations

## 3. Policy Statements

### 3.1 General Encryption Requirements

**3.1.1** All RESTRICTED and CONFIDENTIAL data MUST be encrypted at rest and in
transit.

**3.1.2** All INTERNAL data SHOULD be encrypted at rest and MUST be encrypted in
transit.

**3.1.3** Encryption algorithms MUST comply with current NIST recommendations
and industry standards.

**3.1.4** Encryption keys MUST be protected with controls equivalent to or
greater than the data they protect.

**3.1.5** Cryptographic operations MUST use FIPS 140-2 validated modules where
required by regulation.

### 3.2 Encryption at Rest

**3.2.1** All Amazon Bedrock knowledge bases containing RESTRICTED or
CONFIDENTIAL data MUST use AWS KMS Customer Managed Keys (CMK) for encryption.

**3.2.2** All S3 buckets storing RESTRICTED or CONFIDENTIAL data MUST have
default encryption enabled using KMS CMK.

**3.2.3** All EBS volumes containing RESTRICTED or CONFIDENTIAL data MUST be
encrypted using KMS CMK.

**3.2.4** All RDS databases containing RESTRICTED or CONFIDENTIAL data MUST have
encryption at rest enabled using KMS CMK.

**3.2.5** All DynamoDB tables containing RESTRICTED or CONFIDENTIAL data MUST
use AWS KMS encryption.

**3.2.6** All backup data MUST be encrypted with the same or higher level of
encryption as the source data.

**3.2.7** All CloudWatch Logs containing RESTRICTED or CONFIDENTIAL data MUST be
encrypted using KMS CMK.

### 3.3 Encryption in Transit

**3.3.1** All data in transit over untrusted networks MUST be encrypted using
TLS 1.2 or higher.

**3.3.2** All API communications with Amazon Bedrock MUST use HTTPS with TLS 1.2
minimum.

**3.3.3** All AWS service-to-service communications for RESTRICTED data MUST use
AWS PrivateLink or VPC endpoints.

**3.3.4** All Application Load Balancers and API Gateways MUST enforce HTTPS and
redirect HTTP to HTTPS.

**3.3.5** TLS cipher suites MUST be configured to use only strong ciphers (no
weak or deprecated ciphers).

**3.3.6** Certificate validation MUST be enforced for all TLS connections.

### 3.4 Key Management

**3.4.1** All encryption keys MUST be generated using cryptographically secure
random number generators.

**3.4.2** Customer Managed Keys (CMK) MUST be used for RESTRICTED and
CONFIDENTIAL data encryption.

**3.4.3** Automatic key rotation MUST be enabled for all Customer Managed Keys.

**3.4.4** Encryption keys MUST NOT be hardcoded in source code or configuration
files.

**3.4.5** Access to encryption keys MUST be restricted to the minimum necessary
personnel and services.

**3.4.6** Key usage MUST be logged and monitored for anomalous activity.

**3.4.7** Encryption keys MUST have a minimum deletion window of 30 days when
scheduled for deletion.

---

## 4. Encryption Standards

### 4.1 Approved Algorithms

#### Symmetric Encryption

| Algorithm | Key Size | Use Case                      | Status                         |
| --------- | -------- | ----------------------------- | ------------------------------ |
| AES       | 256-bit  | Data at rest, bulk encryption | **Recommended**                |
| AES       | 192-bit  | Data at rest (acceptable)     | Acceptable                     |
| AES       | 128-bit  | Legacy systems only           | Deprecated (phase out by 2026) |
| 3DES      | N/A      | N/A                           | **Prohibited**                 |
| DES       | N/A      | N/A                           | **Prohibited**                 |
| RC4       | N/A      | N/A                           | **Prohibited**                 |

**AWS KMS Default:** AES-256-GCM for data encryption keys

#### Asymmetric Encryption

| Algorithm   | Key Size   | Use Case                         | Status               |
| ----------- | ---------- | -------------------------------- | -------------------- |
| RSA         | 4096-bit   | Key exchange, digital signatures | **Recommended**      |
| RSA         | 2048-bit   | Key exchange, digital signatures | Acceptable (minimum) |
| RSA         | < 2048-bit | N/A                              | **Prohibited**       |
| ECC (P-256) | 256-bit    | Key exchange, digital signatures | **Recommended**      |
| ECC (P-384) | 384-bit    | High security requirements       | **Recommended**      |
| DSA         | N/A        | N/A                              | Deprecated           |

#### Hashing Algorithms

| Algorithm | Use Case                           | Status          |
| --------- | ---------------------------------- | --------------- |
| SHA-256   | Data integrity, digital signatures | **Recommended** |
| SHA-384   | High security requirements         | **Recommended** |
| SHA-512   | High security requirements         | **Recommended** |
| SHA-1     | N/A                                | **Prohibited**  |
| MD5       | N/A                                | **Prohibited**  |

**Exception:** SHA-1 and MD5 may be used for non-security purposes (e.g.,
checksums) where collision resistance is not required.

#### Message Authentication Codes (MAC)

| Algorithm   | Use Case               | Status          |
| ----------- | ---------------------- | --------------- |
| HMAC-SHA256 | Message authentication | **Recommended** |
| HMAC-SHA384 | Message authentication | **Recommended** |
| HMAC-SHA512 | Message authentication | **Recommended** |

### 4.2 TLS/SSL Configuration

#### Minimum TLS Version

| Data Classification | Minimum TLS Version            | Cipher Suite Requirements                     |
| ------------------- | ------------------------------ | --------------------------------------------- |
| PUBLIC              | TLS 1.2                        | Standard                                      |
| INTERNAL            | TLS 1.2                        | Standard                                      |
| CONFIDENTIAL        | TLS 1.2                        | Strong ciphers only                           |
| RESTRICTED          | TLS 1.3 (preferred) or TLS 1.2 | Strong ciphers only + Perfect Forward Secrecy |

#### Approved TLS Cipher Suites (TLS 1.2)

**Recommended (Perfect Forward Secrecy):**

```
TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256
```

**Prohibited:**

```
All NULL cipher suites (no encryption)
All EXPORT cipher suites (weak encryption)
All DES/3DES cipher suites
All RC4 cipher suites
All CBC mode cipher suites (vulnerable to BEAST/Lucky13)
All cipher suites without Perfect Forward Secrecy for RESTRICTED data
```

#### TLS 1.3 (Recommended for RESTRICTED data)

All TLS 1.3 cipher suites are acceptable (TLS 1.3 removed weak ciphers):

```
TLS_AES_256_GCM_SHA384
TLS_CHACHA20_POLY1305_SHA256
TLS_AES_128_GCM_SHA256
```

### 4.3 Certificate Management

**Certificate Authority (CA):**

- Certificates MUST be issued by a trusted public CA or internal CA
- Self-signed certificates are PROHIBITED in production
- Self-signed certificates acceptable in development with documented exception

**Certificate Standards:**

- RSA: 2048-bit minimum (4096-bit recommended for RESTRICTED data)
- ECC: P-256 minimum (P-384 recommended for RESTRICTED data)
- Validity period: Maximum 398 days (per CA/Browser Forum requirements)
- Certificate Transparency: MUST be enabled

**Certificate Lifecycle:**

- Issuance: Automated via AWS Certificate Manager (ACM) or internal PKI
- Renewal: Automated 30 days before expiration
- Revocation: Within 24 hours of compromise or decommissioning
- Monitoring: Certificate expiration alerts 60/30/14 days before expiry

---

## 5. AWS Service-Specific Encryption Requirements

### 5.1 Amazon Bedrock

#### Knowledge Bases

**RESTRICTED and CONFIDENTIAL knowledge bases:**

```yaml
Encryption at rest:
  - Type: AWS KMS Customer Managed Key (CMK)
  - Key rotation: Enabled (annual automatic rotation)
  - Key policy: Least privilege access
  - Separate key per environment: Required

Encryption in transit:
  - TLS version: 1.2 minimum (1.3 recommended)
  - Access: VPC endpoint with AWS PrivateLink
  - Certificate validation: Enforced

Data sources (S3):
  - S3 bucket encryption: KMS CMK (same key as knowledge base)
  - Bucket versioning: Enabled
  - SSL/TLS requests only: Enforced
```

**Implementation (Terraform):**

```hcl
resource "aws_bedrockagent_knowledge_base" "encrypted_kb" {
  name     = "secure-knowledge-base"
  role_arn = aws_iam_role.bedrock_kb_role.arn

  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:aws:bedrock:region::foundation-model/amazon.titan-embed-text-v1"
    }
  }

  storage_configuration {
    type = "OPENSEARCH_SERVERLESS"
    opensearch_serverless_configuration {
      collection_arn    = aws_opensearchserverless_collection.kb_collection.arn
      vector_index_name = "bedrock-knowledge-base-index"
      field_mapping {
        vector_field   = "embedding"
        text_field     = "text"
        metadata_field = "metadata"
      }
    }
  }

  # Encryption enforced via OpenSearch Serverless collection encryption
  # and S3 data source bucket encryption
}

resource "aws_opensearchserverless_security_policy" "encryption" {
  name = "bedrock-kb-encryption-policy"
  type = "encryption"
  policy = jsonencode({
    Rules = [{
      ResourceType = "collection"
      Resource     = ["collection/${aws_opensearchserverless_collection.kb_collection.name}"]
    }]
    AWSOwnedKey = false  # Use customer-managed key
    KmsARN      = aws_kms_key.bedrock_cmk.arn
  })
}
```

#### Bedrock Agents

**RESTRICTED and CONFIDENTIAL agents:**

```yaml
Encryption at rest:
  - Agent configuration: Encrypted via AWS service encryption
  - Session data: Encrypted in memory, ephemeral (not persisted)
  - Lambda function environment variables: Encrypted with KMS CMK
  - Action Group Lambda code: S3 encryption with KMS CMK

Encryption in transit:
  - Agent invocation: HTTPS with TLS 1.2+
  - VPC deployment: VPC endpoint access
  - Lambda communication: Within VPC, encrypted
  - Model invocation: HTTPS with TLS 1.2+

Guardrails:
  - Sensitive data detection: Enabled (PII/PHI/PCI)
  - Output filtering: Enabled
```

**Implementation (Terraform):**

```hcl
resource "aws_bedrockagent_agent" "encrypted_agent" {
  agent_name              = "secure-bedrock-agent"
  agent_resource_role_arn = aws_iam_role.bedrock_agent_role.arn
  foundation_model        = "anthropic.claude-v2"

  # Enable guardrails for sensitive data protection
  guardrail_configuration {
    guardrail_identifier = aws_bedrock_guardrail.pii_protection.id
    guardrail_version    = "1"
  }

  # Instruction with encryption expectations
  instruction = "You are a secure AI agent. Never expose PII, PHI, or PCI data."
}

# Lambda function for agent action group (encrypted)
resource "aws_lambda_function" "agent_action" {
  filename         = "agent_action.zip"
  function_name    = "bedrock-agent-action"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = "python3.12"

  environment {
    variables = {
      SENSITIVE_CONFIG = "encrypted-value"
    }
  }

  # Environment variable encryption with KMS CMK
  kms_key_arn = aws_kms_key.lambda_cmk.arn

  # VPC configuration for network isolation
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
}
```

#### Model Invocation Logging

```yaml
CloudWatch Logs encryption:
  - Log group: /aws/bedrock/modelinvocations
  - Encryption: KMS CMK
  - Retention: 7 years (compliance requirement)
  - Access: Restricted to security and compliance teams
```

**Implementation:**

```hcl
resource "aws_cloudwatch_log_group" "bedrock_model_invocation" {
  name              = "/aws/bedrock/modelinvocations"
  retention_in_days = 2557  # 7 years
  kms_key_id        = aws_kms_key.cloudwatch_cmk.arn
}
```

### 5.2 Amazon S3

**RESTRICTED and CONFIDENTIAL buckets:**

```yaml
Encryption at rest:
  - Default encryption: Enabled (KMS CMK)
  - Bucket key: Enabled (reduces KMS API calls)
  - Object Lock: Enabled for RESTRICTED data (compliance mode)
  - Versioning: Enabled

Encryption in transit:
  - SSL/TLS only: Enforced via bucket policy
  - TLS version: 1.2 minimum

Access control:
  - Block public access: All enabled
  - Bucket policy: Deny non-HTTPS requests
  - VPC endpoint: Required for RESTRICTED data
```

**Implementation:**

```hcl
resource "aws_s3_bucket" "encrypted_bucket" {
  bucket = "bedrock-restricted-data-${var.environment}"
}

# Enable versioning
resource "aws_s3_bucket_versioning" "encrypted_bucket" {
  bucket = aws_s3_bucket.encrypted_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption with KMS CMK
resource "aws_s3_bucket_server_side_encryption_configuration" "encrypted_bucket" {
  bucket = aws_s3_bucket.encrypted_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_cmk.arn
    }
    bucket_key_enabled = true
  }
}

# Enforce SSL/TLS
resource "aws_s3_bucket_policy" "enforce_tls" {
  bucket = aws_s3_bucket.encrypted_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyNonHttpsRequests"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.encrypted_bucket.arn,
          "${aws_s3_bucket.encrypted_bucket.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid       = "DenyWeakTLS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.encrypted_bucket.arn,
          "${aws_s3_bucket.encrypted_bucket.arn}/*"
        ]
        Condition = {
          NumericLessThan = {
            "s3:TlsVersion" = "1.2"
          }
        }
      }
    ]
  })
}

# Block public access
resource "aws_s3_bucket_public_access_block" "encrypted_bucket" {
  bucket = aws_s3_bucket.encrypted_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Object Lock for RESTRICTED data (immutability)
resource "aws_s3_bucket_object_lock_configuration" "encrypted_bucket" {
  bucket = aws_s3_bucket.encrypted_bucket.id

  rule {
    default_retention {
      mode = "COMPLIANCE"  # Cannot be overridden
      years = 7
    }
  }
}
```

### 5.3 AWS KMS (Key Management Service)

**Customer Managed Keys (CMK) Configuration:**

```yaml
Key specifications:
  - Key type: Symmetric
  - Key spec: SYMMETRIC_DEFAULT (AES-256-GCM)
  - Key usage: ENCRYPT_DECRYPT
  - Origin: AWS_KMS (AWS-generated key material)

Key policy:
  - Least privilege access
  - Separation of duties (key administrators vs. key users)
  - No wildcard principals
  - Explicit deny for key deletion without MFA

Key rotation:
  - Automatic rotation: Enabled (annual)
  - Manual rotation: Not recommended (use automatic)

Multi-region keys:
  - Usage: Prohibited for RESTRICTED data (data residency concerns)
  - Usage: Acceptable for CONFIDENTIAL data with justification

Key deletion:
  - Waiting period: 30 days minimum
  - Approval: CISO required for RESTRICTED data keys
  - Verification: Ensure no dependent resources
```

**Implementation:**

```hcl
resource "aws_kms_key" "bedrock_cmk" {
  description             = "Customer-managed key for Bedrock RESTRICTED data"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  multi_region            = false  # Prohibited for RESTRICTED data

  tags = {
    Classification = "RESTRICTED"
    Purpose        = "BedrockEncryption"
    Environment    = var.environment
  }
}

resource "aws_kms_alias" "bedrock_cmk" {
  name          = "alias/bedrock-restricted-${var.environment}"
  target_key_id = aws_kms_key.bedrock_cmk.id
}

resource "aws_kms_key_policy" "bedrock_cmk" {
  key_id = aws_kms_key.bedrock_cmk.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Key Administrators"
        Effect = "Allow"
        Principal = {
          AWS = [
            aws_iam_role.kms_admin.arn
          ]
        }
        Action = [
          "kms:Create*",
          "kms:Describe*",
          "kms:Enable*",
          "kms:List*",
          "kms:Put*",
          "kms:Update*",
          "kms:Revoke*",
          "kms:Disable*",
          "kms:Get*",
          "kms:Delete*",
          "kms:TagResource",
          "kms:UntagResource",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow Bedrock Service to Use Key"
        Effect = "Allow"
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = [
              "bedrock.${var.aws_region}.amazonaws.com"
            ]
          }
        }
      },
      {
        Sid    = "Allow S3 Service to Use Key"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = [
              "s3.${var.aws_region}.amazonaws.com"
            ]
          }
        }
      },
      {
        Sid    = "Prevent Key Deletion Without MFA"
        Effect = "Deny"
        Principal = "*"
        Action = [
          "kms:ScheduleKeyDeletion",
          "kms:Delete*"
        ]
        Resource = "*"
        Condition = {
          BoolIfExists = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      }
    ]
  })
}
```

### 5.4 AWS Lambda

**RESTRICTED and CONFIDENTIAL functions:**

```yaml
Environment variables:
  - Encryption helper: Enabled (automatic encryption)
  - KMS key: Customer-managed key (CMK)
  - Sensitive data: Never in plaintext environment variables

Code and configuration:
  - Deployment package (S3): Encrypted with KMS CMK
  - Lambda layer (S3): Encrypted with KMS CMK

Secrets:
  - Storage: AWS Secrets Manager (encrypted with KMS CMK)
  - Retrieval: At runtime via SDK (cached securely)
  - Rotation: Automated (90 days maximum)
```

**Implementation:**

```hcl
resource "aws_lambda_function" "bedrock_integration" {
  function_name = "bedrock-secure-function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "python3.12"

  # Code stored in encrypted S3 bucket
  s3_bucket = aws_s3_bucket.lambda_code_encrypted.id
  s3_key    = "bedrock-function.zip"

  # Environment variables encrypted with KMS CMK
  environment {
    variables = {
      SECRET_ARN = aws_secretsmanager_secret.api_key.arn
      KMS_KEY_ID = aws_kms_key.lambda_cmk.id
    }
  }

  kms_key_arn = aws_kms_key.lambda_cmk.arn

  # VPC configuration for network isolation
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
}

# Secret in Secrets Manager (encrypted)
resource "aws_secretsmanager_secret" "api_key" {
  name       = "bedrock-api-key-${var.environment}"
  kms_key_id = aws_kms_key.secrets_cmk.id
}

resource "aws_secretsmanager_secret_rotation" "api_key" {
  secret_id           = aws_secretsmanager_secret.api_key.id
  rotation_lambda_arn = aws_lambda_function.rotate_secret.arn

  rotation_rules {
    automatically_after_days = 90
  }
}
```

### 5.5 Amazon RDS / Amazon Aurora

**RESTRICTED and CONFIDENTIAL databases:**

```yaml
Encryption at rest:
  - Storage encryption: Enabled (KMS CMK)
  - Automated backups: Encrypted (same key as source)
  - Read replicas: Encrypted (same key as source)
  - Snapshots: Encrypted (same key as source)

Encryption in transit:
  - SSL/TLS: Required for all connections
  - Certificate validation: Enforced
  - TLS version: 1.2 minimum

Network:
  - Publicly accessible: false
  - VPC: Private subnets only
  - Security group: Restrictive ingress rules
```

**Implementation:**

```hcl
resource "aws_db_instance" "encrypted_db" {
  identifier = "bedrock-metadata-db-${var.environment}"
  engine     = "postgres"
  engine_version = "15.4"

  instance_class = "db.t3.medium"
  allocated_storage = 100
  storage_type      = "gp3"
  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds_cmk.arn

  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.private.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  publicly_accessible    = false

  # Backup configuration (encrypted)
  backup_retention_period = 35  # 5 weeks
  backup_window           = "03:00-04:00"

  # Enforce SSL/TLS
  ca_cert_identifier = "rds-ca-rsa4096-g1"

  # Enable deletion protection for production
  deletion_protection = var.environment == "prod" ? true : false

  # Parameter group enforcing SSL
  parameter_group_name = aws_db_parameter_group.postgres_ssl.name
}

resource "aws_db_parameter_group" "postgres_ssl" {
  name   = "bedrock-postgres-ssl-${var.environment}"
  family = "postgres15"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  parameter {
    name  = "ssl_min_protocol_version"
    value = "TLSv1.2"
  }
}
```

### 5.6 Amazon DynamoDB

**RESTRICTED and CONFIDENTIAL tables:**

```yaml
Encryption at rest:
  - Type: AWS KMS Customer Managed Key (CMK)
  - Backups: Encrypted (same key as table)
  - Streams: Encrypted (same key as table)
  - Global tables: Encrypted (separate CMK per region)

Encryption in transit:
  - VPC endpoint: Required for RESTRICTED data
  - TLS version: 1.2 minimum
  - SDK: HTTPS endpoint only
```

**Implementation:**

```hcl
resource "aws_dynamodb_table" "encrypted_table" {
  name         = "bedrock-session-data-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "SessionId"
  range_key    = "Timestamp"

  attribute {
    name = "SessionId"
    type = "S"
  }

  attribute {
    name = "Timestamp"
    type = "N"
  }

  # Encryption with KMS CMK
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb_cmk.arn
  }

  # Point-in-time recovery (encrypted backups)
  point_in_time_recovery {
    enabled = true
  }

  # TTL for automatic data expiration (data minimization)
  ttl {
    attribute_name = "ExpirationTime"
    enabled        = true
  }

  # DynamoDB Streams (encrypted)
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"
}
```

### 5.7 Amazon CloudWatch Logs

**RESTRICTED and CONFIDENTIAL log groups:**

```yaml
Encryption:
  - KMS CMK: Required
  - Automatic encryption: All new log events

Retention:
  - RESTRICTED: 7 years minimum (2557 days)
  - CONFIDENTIAL: 7 years minimum

Access:
  - IAM policies: Least privilege
  - Log subscription filters: Encrypted in transit
  - Cross-account access: Via KMS key policy
```

**Implementation:**

```hcl
resource "aws_cloudwatch_log_group" "bedrock_logs" {
  name              = "/aws/bedrock/${var.environment}/agents"
  retention_in_days = 2557  # 7 years
  kms_key_id        = aws_kms_key.cloudwatch_cmk.arn

  tags = {
    Classification = "RESTRICTED"
    Compliance     = "HIPAA,GDPR,PCI-DSS"
  }
}

# KMS key for CloudWatch Logs
resource "aws_kms_key" "cloudwatch_cmk" {
  description             = "CloudWatch Logs encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:CreateGrant",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/bedrock/*"
          }
        }
      }
    ]
  })
}
```

### 5.8 AWS Backup

**RESTRICTED and CONFIDENTIAL backups:**

```yaml
Encryption:
  - Backup vault: Locked (cannot delete backups)
  - Encryption key: Separate KMS CMK from source data
  - Cross-region copy: Encrypted with region-specific CMK

Access control:
  - Backup vault access policy: Restrictive
  - Cross-account backup: Requires explicit permission

Recovery:
  - Recovery point objectives (RPO): 1 hour for RESTRICTED data
  - Recovery time objectives (RTO): 4 hours for RESTRICTED data
  - Test restores: Quarterly for RESTRICTED data
```

**Implementation:**

```hcl
resource "aws_backup_vault" "encrypted_vault" {
  name        = "bedrock-backup-vault-${var.environment}"
  kms_key_arn = aws_kms_key.backup_cmk.arn
}

resource "aws_backup_vault_lock_configuration" "encrypted_vault" {
  backup_vault_name   = aws_backup_vault.encrypted_vault.name
  min_retention_days  = 2557  # 7 years (compliance)
  max_retention_days  = 3650  # 10 years
  changeable_for_days = 3     # 3-day grace period after creation
}

resource "aws_backup_plan" "bedrock_backup" {
  name = "bedrock-backup-plan-${var.environment}"

  rule {
    rule_name         = "daily_backup"
    target_vault_name = aws_backup_vault.encrypted_vault.name
    schedule          = "cron(0 5 ? * * *)"  # 5 AM UTC daily

    lifecycle {
      cold_storage_after = 90    # Move to Glacier after 90 days
      delete_after       = 2557  # Delete after 7 years
    }

    # Cross-region copy for disaster recovery
    copy_action {
      destination_vault_arn = aws_backup_vault.dr_vault.arn

      lifecycle {
        cold_storage_after = 90
        delete_after       = 2557
      }
    }
  }
}

resource "aws_backup_selection" "bedrock_resources" {
  name         = "bedrock-backup-selection"
  plan_id      = aws_backup_plan.bedrock_backup.id
  iam_role_arn = aws_iam_role.backup_role.arn

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Backup"
    value = "true"
  }

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Classification"
    value = "RESTRICTED"
  }
}
```

---

## 6. Key Management Procedures

### 6.1 Key Generation

**Process:**

1. **Request:** Data Owner submits key request via ticketing system
2. **Justification:** Business justification and data classification documented
3. **Approval:** Security team approves key specifications
4. **Generation:** Key generated using AWS KMS `CreateKey` API
5. **Configuration:**
   - Key policy defined (least privilege)
   - Key rotation enabled
   - Alias created (descriptive naming)
   - Tags applied (Classification, Owner, Purpose, Environment)
6. **Documentation:** Key ARN, purpose, and owner documented in key inventory
7. **Notification:** Data Owner and custodians notified

**Automated generation (Terraform/CloudFormation):**

- Infrastructure as Code (IaC) preferred
- Code review required before deployment
- Drift detection enabled (AWS Config)

### 6.2 Key Rotation

**Automatic Rotation (Recommended):**

- Enabled for all Customer Managed Keys
- Rotation frequency: Annual (AWS default)
- AWS KMS automatically rotates key material
- Old key material retained for decryption of existing ciphertext
- Application transparent (no code changes)

**Manual Rotation:**

- Discouraged (use automatic rotation)
- If required: Create new key, update applications, decrypt/re-encrypt data
- Used only when automatic rotation is insufficient (e.g., compliance
  requirement for immediate rotation)

**Rotation Verification:**

- CloudWatch alarm on rotation failure
- Monthly audit of rotation status (AWS Config rule)

**Implementation:**

```hcl
resource "aws_kms_key" "auto_rotate" {
  description             = "Auto-rotating CMK for Bedrock"
  deletion_window_in_days = 30
  enable_key_rotation     = true  # Automatic annual rotation

  tags = {
    RotationEnabled = "true"
    LastRotation    = "Auto"
  }
}

# CloudWatch alarm for rotation monitoring
resource "aws_cloudwatch_metric_alarm" "kms_rotation_alarm" {
  alarm_name          = "kms-rotation-failure-${aws_kms_key.auto_rotate.id}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "KeyRotation"
  namespace           = "AWS/KMS"
  period              = "86400"  # 24 hours
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "Alert if KMS key rotation fails"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  dimensions = {
    KeyId = aws_kms_key.auto_rotate.id
  }
}
```

### 6.3 Key Storage

**AWS KMS (Recommended):**

- Key material never leaves KMS (FIPS 140-2 Level 2 or higher)
- Key material never exposed to users or applications
- All cryptographic operations performed within KMS
- Multi-tenant hardware security modules (HSMs)

**AWS CloudHSM (High Assurance Requirements):**

- FIPS 140-2 Level 3 validated HSMs
- Single-tenant dedicated HSM
- Customer-controlled HSM cluster
- Use case: RESTRICTED data requiring dedicated HSMs

**Prohibited:**

- Storing keys in source code
- Storing keys in configuration files
- Storing keys in S3 without encryption
- Storing keys in environment variables (plaintext)
- Storing keys in databases (plaintext)

### 6.4 Key Access Control

**Principle of Least Privilege:**

- Separate roles: Key Administrators vs. Key Users
- Key Administrators: Manage key lifecycle (create, rotate, delete)
- Key Users: Use key for encryption/decryption only
- No user should have both administrative and usage permissions

**Key Policy Structure:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Enable IAM User Permissions",
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::ACCOUNT:root" },
      "Action": "kms:*",
      "Resource": "*"
    },
    {
      "Sid": "Allow Key Administrators",
      "Effect": "Allow",
      "Principal": { "AWS": ["arn:aws:iam::ACCOUNT:role/KMSAdminRole"] },
      "Action": [
        "kms:Create*",
        "kms:Describe*",
        "kms:Enable*",
        "kms:List*",
        "kms:Put*",
        "kms:Update*",
        "kms:Revoke*",
        "kms:Disable*",
        "kms:Get*",
        "kms:Delete*",
        "kms:ScheduleKeyDeletion",
        "kms:CancelKeyDeletion"
      ],
      "Resource": "*"
    },
    {
      "Sid": "Allow Key Users (Bedrock Service)",
      "Effect": "Allow",
      "Principal": { "Service": "bedrock.amazonaws.com" },
      "Action": ["kms:Decrypt", "kms:GenerateDataKey", "kms:CreateGrant"],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "kms:ViaService": "bedrock.us-east-1.amazonaws.com"
        }
      }
    },
    {
      "Sid": "Prevent Deletion Without MFA",
      "Effect": "Deny",
      "Principal": "*",
      "Action": ["kms:ScheduleKeyDeletion", "kms:Delete*"],
      "Resource": "*",
      "Condition": {
        "BoolIfExists": { "aws:MultiFactorAuthPresent": "false" }
      }
    }
  ]
}
```

### 6.5 Key Usage Monitoring

**CloudTrail Logging:**

- All KMS API calls logged (management and data events)
- Log file validation enabled
- Logs encrypted and stored in dedicated S3 bucket
- Cross-region log aggregation

**Monitored Events:**

- `CreateKey`, `ScheduleKeyDeletion`, `DisableKey`
- `Encrypt`, `Decrypt`, `GenerateDataKey`
- `PutKeyPolicy`, `CreateGrant`, `RevokeGrant`

**Alarms:**

- Unusual encryption/decryption volume (anomaly detection)
- Key deletion scheduled
- Key disabled
- Failed decryption attempts (potential ransomware)
- Grant creation by unauthorized principal

**Implementation:**

```hcl
resource "aws_cloudwatch_log_metric_filter" "kms_delete" {
  name           = "kms-key-deletion-scheduled"
  log_group_name = "/aws/cloudtrail/${var.environment}"
  pattern        = "{ ($.eventName = ScheduleKeyDeletion) || ($.eventName = DisableKey) }"

  metric_transformation {
    name      = "KMSKeyDeletionScheduled"
    namespace = "Security/KMS"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "kms_delete_alarm" {
  alarm_name          = "kms-key-deletion-alert"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "KMSKeyDeletionScheduled"
  namespace           = "Security/KMS"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Alert when KMS key deletion is scheduled"
  alarm_actions       = [aws_sns_topic.critical_security_alerts.arn]
}

resource "aws_cloudwatch_log_metric_filter" "kms_decrypt_failures" {
  name           = "kms-decrypt-failures"
  log_group_name = "/aws/cloudtrail/${var.environment}"
  pattern        = "{ ($.eventName = Decrypt) && ($.errorCode = AccessDeniedException) }"

  metric_transformation {
    name      = "KMSDecryptFailures"
    namespace = "Security/KMS"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "kms_decrypt_failures_alarm" {
  alarm_name          = "kms-decrypt-failures-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "KMSDecryptFailures"
  namespace           = "Security/KMS"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"  # Alert if more than 10 failures in 5 minutes
  alarm_description   = "High number of KMS decrypt failures (potential ransomware)"
  alarm_actions       = [aws_sns_topic.critical_security_alerts.arn]
}
```

### 6.6 Key Deletion

**Deletion Process:**

1. **Request:** Data Owner submits deletion request with justification
2. **Validation:**
   - Verify key is no longer in use (no dependent resources)
   - Check for encrypted data that requires migration
   - Verify backup keys are not needed for recovery
3. **Approval:**
   - Data Owner approval
   - CISO approval (for RESTRICTED data keys)
   - Compliance team notification
4. **Schedule Deletion:**
   - Minimum waiting period: 30 days
   - Key state: "Pending Deletion" (can be cancelled)
   - Automated alerts to stakeholders
5. **Monitoring:**
   - Any attempts to use key during waiting period logged and investigated
6. **Deletion:**
   - Automatic after waiting period
   - Irreversible (key material destroyed)
7. **Documentation:**
   - Deletion event logged
   - Key inventory updated
   - Compliance evidence retained

**Prevention Measures:**

- KMS key policy: Require MFA for deletion
- AWS Config rule: Alert on deletion scheduling
- IAM policy: Restrict deletion permissions
- Resource tags: "DeletionProtection": "true"

**Accidental Deletion Recovery:**

- During waiting period: Cancel deletion
- After deletion: No recovery possible
- Mitigation: Ensure backups encrypted with separate keys

**Implementation:**

```bash
# Schedule key deletion (requires approval)
aws kms schedule-key-deletion \
  --key-id <key-id> \
  --pending-window-in-days 30

# Cancel key deletion (if scheduled accidentally)
aws kms cancel-key-deletion \
  --key-id <key-id>
```

---

## 7. Compliance and Audit

### 7.1 Compliance Frameworks

**GDPR (Article 32 - Security of Processing):**

- Encryption of personal data at rest and in transit: **Compliant**
- Pseudonymization where applicable: **Implemented via Bedrock guardrails**
- Regular testing and evaluation: **Quarterly compliance audits**

**HIPAA (164.312(a)(2)(iv) and 164.312(e)(2)(ii)):**

- Encryption of ePHI at rest: **Compliant (KMS CMK)**
- Encryption of ePHI in transit: **Compliant (TLS 1.2+)**
- Encryption key management: **Compliant (AWS KMS)**

**PCI DSS v4.0 (Requirement 3):**

- Cardholder data encryption at rest: **Compliant (KMS CMK)**
- Strong cryptography: **Compliant (AES-256, RSA-2048+)**
- Key management: **Compliant (separation of duties, rotation, access control)**

**SOC 2 (CC6.7 - Restrict Access to Resources):**

- Encryption as access control: **Compliant**
- Key access restrictions: **Compliant (IAM policies, key policies)**

**ISO 27001 (A.10.1 - Cryptographic Controls):**

- Policy on cryptographic controls: **This document**
- Key management: **Compliant (AWS KMS)**
- Use of cryptography: **Compliant (approved algorithms)**

### 7.2 Automated Compliance Checks

**AWS Config Rules:**

```hcl
resource "aws_config_config_rule" "s3_bucket_encryption" {
  name = "s3-bucket-server-side-encryption-enabled"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_config_rule" "kms_cmk_not_scheduled_for_deletion" {
  name = "kms-cmk-not-scheduled-for-deletion"

  source {
    owner             = "AWS"
    source_identifier = "KMS_CMK_NOT_SCHEDULED_FOR_DELETION"
  }
}

resource "aws_config_config_rule" "cloudtrail_encryption_enabled" {
  name = "cloud-trail-encryption-enabled"

  source {
    owner             = "AWS"
    source_identifier = "CLOUD_TRAIL_ENCRYPTION_ENABLED"
  }
}

resource "aws_config_config_rule" "rds_storage_encrypted" {
  name = "rds-storage-encrypted"

  source {
    owner             = "AWS"
    source_identifier = "RDS_STORAGE_ENCRYPTED"
  }
}

resource "aws_config_config_rule" "dynamodb_table_encryption_enabled" {
  name = "dynamodb-table-encryption-enabled"

  source {
    owner             = "AWS"
    source_identifier = "DYNAMODB_TABLE_ENCRYPTION_ENABLED"
  }
}

# Custom rule for Bedrock encryption
resource "aws_config_config_rule" "bedrock_encryption" {
  name = "bedrock-knowledge-base-encryption-enabled"

  source {
    owner             = "CUSTOM_LAMBDA"
    source_identifier = aws_lambda_function.bedrock_encryption_check.arn
    source_detail {
      message_type = "ConfigurationItemChangeNotification"
    }
  }

  depends_on = [aws_lambda_permission.config]
}
```

**Security Hub Standards:**

- AWS Foundational Security Best Practices
- CIS AWS Foundations Benchmark
- PCI DSS
- HIPAA (via custom controls)

### 7.3 Audit Procedures

**Quarterly Audits:**

- Review all KMS keys for rotation status
- Verify encryption enabled on all RESTRICTED/CONFIDENTIAL resources
- Review key policies for least privilege compliance
- Audit key access logs for anomalous activity
- Test disaster recovery encryption procedures

**Annual Audits:**

- Full encryption inventory audit
- Cryptographic algorithm review (ensure no deprecated algorithms)
- Third-party penetration testing (encryption validation)
- Key management process review
- Policy review and update
- Compliance certification evidence collection

**Continuous Monitoring:**

- AWS Config compliance dashboard
- Security Hub compliance scores
- CloudWatch alarms for encryption violations
- Automated remediation for non-compliant resources

### 7.4 Audit Evidence

**Maintained Evidence:**

- Encryption configurations (AWS Config snapshots)
- Key creation and deletion logs (CloudTrail)
- Key rotation history (AWS KMS)
- Access logs (CloudTrail, VPC Flow Logs)
- Compliance reports (AWS Config, Security Hub)
- Penetration test results
- Vulnerability scan reports
- Policy acknowledgments (training records)

**Retention:** 7 years minimum

---

## 8. Exceptions and Waivers

### 8.1 Exception Process

**When Exceptions May Be Granted:**

- Technical infeasibility (legacy system constraints)
- Performance impact (with compensating controls)
- Cost prohibitive (for non-critical data)
- Temporary exception during migration (max 180 days)

**Exception Request:**

1. Business justification documented
2. Risk assessment conducted
3. Compensating controls identified
4. Exception duration specified (max 12 months)
5. Approval by Data Owner, CISO, and Compliance Officer
6. Documentation in exception register
7. Quarterly review of active exceptions

**Prohibited Exceptions:**

- No exception for RESTRICTED data encryption at rest
- No exception for RESTRICTED data encryption in transit
- No exception for use of prohibited algorithms (DES, 3DES, RC4, MD5, SHA-1 for
  security)
- No exception for hardcoded keys in source code

---

## 9. Incident Response

### 9.1 Encryption Incidents

**Types of Encryption Incidents:**

- Encryption key compromise or suspected compromise
- Unencrypted RESTRICTED/CONFIDENTIAL data discovered
- Encryption algorithm vulnerability (e.g., downgrade attack)
- Ransomware attack (encrypted by attacker)
- Key deletion (accidental or malicious)
- TLS certificate compromise

**Incident Response Procedures:**

**Key Compromise:**

1. **Immediate Actions:**
   - Disable compromised key (KMS: `DisableKey`)
   - Alert CISO and security team
   - Engage incident response team
2. **Investigation:**
   - Review CloudTrail logs for unauthorized key usage
   - Identify data encrypted with compromised key
   - Assess scope of compromise
3. **Containment:**
   - Revoke access to compromised key
   - Rotate credentials of users with key access
   - Create new encryption key
4. **Recovery:**
   - Decrypt data with compromised key (if still accessible)
   - Re-encrypt data with new key
   - Update applications to use new key
5. **Post-Incident:**
   - Root cause analysis
   - Implement preventive measures
   - Update key management procedures
   - Notify affected parties (if required by regulation)

**Unencrypted Sensitive Data:**

1. **Immediate Actions:**
   - Assess data classification and exposure
   - Enable encryption immediately
   - Alert Data Owner and CISO
2. **Investigation:**
   - Determine how long data was unencrypted
   - Identify who had access during unencrypted period
   - Assess potential unauthorized access or exfiltration
3. **Remediation:**
   - Enable encryption with appropriate KMS key
   - Review access logs (CloudTrail, S3 access logs, VPC Flow Logs)
   - Revoke access if unauthorized disclosure suspected
4. **Reporting:**
   - Data breach assessment (if exposure occurred)
   - Regulatory notification (if required: GDPR 72 hours, HIPAA 60 days, PCI DSS
     per card brand)

**Ransomware Attack:**

1. **Immediate Actions:**
   - Isolate affected systems (security group modification, network ACL)
   - Prevent deletion of backups
   - Alert CISO and incident response team
2. **Investigation:**
   - Identify ransomware variant
   - Determine entry vector
   - Assess encrypted data scope
3. **Recovery:**
   - Do NOT pay ransom
   - Restore from encrypted backups (AWS Backup)
   - Verify backup integrity before restoration
   - Decrypt using AWS KMS (backups encrypted independently)
4. **Prevention:**
   - Patch vulnerabilities exploited
   - Implement additional detective controls
   - Review and improve backup strategy
   - Conduct post-incident training

---

## 10. Training and Awareness

**All personnel must complete:**

- Annual encryption policy training
- Secure coding training (developers)
- Key management procedures training (key administrators)
- Data classification training (data owners)
- Incident response training (security team)

**Training Topics:**

- Encryption policy requirements
- Approved cryptographic algorithms
- Key management lifecycle
- TLS/SSL best practices
- Secure credential storage (Secrets Manager)
- Incident reporting procedures
- Regulatory compliance requirements (GDPR, HIPAA, PCI DSS)

**Records:**

- Training completion tracked
- Certificates maintained (7 years)
- Annual refresher required

---

## 11. Related Policies

- Data Classification Policy
- Access Control Policy
- Incident Response Policy
- Backup and Retention Policy
- Third-Party Risk Management Policy
- Acceptable Use Policy
- Cloud Security Policy

---

## 12. Definitions

**Encryption at Rest:** Encryption of data stored on persistent storage (disk,
database).

**Encryption in Transit:** Encryption of data being transmitted over a network.

**Customer Managed Key (CMK):** Encryption key created, owned, and managed by
the customer in AWS KMS.

**AWS Managed Key:** Encryption key created and managed by AWS on behalf of the
customer.

**Key Rotation:** Process of replacing encryption key material while maintaining
the same key ID.

**TLS (Transport Layer Security):** Cryptographic protocol for secure
communication over networks.

**FIPS 140-2:** US government standard for cryptographic module validation.

**Perfect Forward Secrecy (PFS):** Property where session keys are not
compromised even if long-term keys are compromised.

**Cipher Suite:** Set of cryptographic algorithms used for secure communication
(key exchange, authentication, encryption, MAC).

---

## 13. Policy Governance

**Policy Owner:** Chief Information Security Officer (CISO)

**Policy Review:** Annual or upon significant regulatory/technology changes

**Policy Approval:** Executive Leadership Team

**Policy Distribution:** All personnel via email, intranet, and training

**Policy Compliance:** Mandatory

**Policy Violations:** Subject to disciplinary action up to termination

---

## 14. Contact Information

**Policy Owner:** Chief Information Security Officer (CISO) Email:
ciso@organization.com

**Key Management:** Cloud Security Team Email: cloudsecurity@organization.com

**Incident Reporting:** Security Operations Center (SOC) Email:
security@organization.com Phone: +1-XXX-XXX-XXXX (24/7)

---

## Document Control

| Version | Date       | Author | Changes                 |
| ------- | ---------- | ------ | ----------------------- |
| 1.0     | 2025-11-17 | CISO   | Initial policy creation |

**Approval Signatures:**

---

Chief Information Security Officer

---

Chief Technology Officer

---

Chief Compliance Officer

**Next Review Date:** 2026-11-17
