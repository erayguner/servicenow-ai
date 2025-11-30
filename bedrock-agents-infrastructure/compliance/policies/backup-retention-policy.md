# Backup and Retention Policy

## Amazon Bedrock Agents Infrastructure

**Document Version:** 1.0 **Effective Date:** 2025-11-17 **Policy Owner:** Chief
Information Security Officer (CISO)

---

## 1. Purpose

This policy establishes backup and data retention requirements for Amazon
Bedrock Agents infrastructure to ensure business continuity, disaster recovery,
and regulatory compliance.

## 2. Backup Requirements

### 2.1 Backup Frequency

| Data Classification | Backup Frequency        | Retention Period | Cross-Region Copy |
| ------------------- | ----------------------- | ---------------- | ----------------- |
| RESTRICTED          | Continuous (1-hour RPO) | 7 years minimum  | Required          |
| CONFIDENTIAL        | Daily                   | 7 years          | Required          |
| INTERNAL            | Weekly                  | 3 years          | Recommended       |
| PUBLIC              | As needed               | 1 year           | Optional          |

### 2.2 Recovery Objectives

| Data Classification | RPO (Recovery Point Objective) | RTO (Recovery Time Objective) |
| ------------------- | ------------------------------ | ----------------------------- |
| RESTRICTED          | 1 hour                         | 4 hours                       |
| CONFIDENTIAL        | 24 hours                       | 24 hours                      |
| INTERNAL            | 7 days                         | 48 hours                      |
| PUBLIC              | Best effort                    | Best effort                   |

### 2.3 Bedrock-Specific Backups

**Knowledge Bases:**

- Data sources (S3): Versioning enabled + automated backups
- Vector databases: Daily snapshots
- Metadata: CloudFormation/Terraform state backups

**Agent Configurations:**

- Agent definitions: Version controlled in Git
- Lambda functions: Source code in CodeCommit/GitHub
- IAM roles and policies: Infrastructure as Code

**Model Artifacts:**

- Fine-tuned models: S3 versioning + lifecycle policies
- Training data: Encrypted backups with separate KMS key

### 2.4 Backup Encryption

All backups must be encrypted with AWS KMS Customer Managed Keys (CMK):

- Separate encryption key from production data
- Key rotation enabled
- Cross-region keys for disaster recovery

**Implementation:**

```hcl
resource "aws_kms_key" "backup_cmk" {
  description             = "KMS key for backup encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  multi_region            = true  # For cross-region DR

  tags = {
    Purpose        = "Backup Encryption"
    Classification = "RESTRICTED"
  }
}

resource "aws_backup_vault" "main" {
  name        = "bedrock-backup-vault-${var.environment}"
  kms_key_arn = aws_kms_key.backup_cmk.arn
}

resource "aws_backup_vault_lock_configuration" "main" {
  backup_vault_name   = aws_backup_vault.main.name
  min_retention_days  = 2557  # 7 years (RESTRICTED data)
  max_retention_days  = 3650  # 10 years
  changeable_for_days = 3
}
```

### 2.5 Backup Testing

**Test Frequency:**

- RESTRICTED data: Quarterly restore testing
- CONFIDENTIAL data: Semi-annual restore testing
- INTERNAL data: Annual restore testing

**Test Scope:**

- Full system restore to isolated environment
- Data integrity verification
- Application functionality validation
- RTO/RPO measurement
- Disaster recovery plan execution

## 3. Data Retention

### 3.1 Retention Schedules

**Regulatory Requirements:**

- GDPR: As needed for processing purpose (data minimization)
- HIPAA: 6 years from creation or last effective date
- PCI DSS: Per merchant agreement (typically 3-12 months for logs)
- SOC 2: 7 years for audit evidence
- ISO 27001: 7 years (best practice)
- Legal/Tax: 7-10 years depending on jurisdiction

**Organizational Policy:** | Data Type | Retention Period | Justification |
|-----------|------------------|---------------| | CloudTrail logs | 7 years |
Audit, compliance, forensics | | Bedrock invocation logs | 7 years | Compliance,
audit trail | | Customer data (PII/PHI) | As per consent or purpose | GDPR data
minimization | | Financial records | 10 years | Tax regulations | | Employee
records | 7 years post-termination | Legal requirements | | Contracts | 7 years
post-expiration | Legal requirements | | Backup data | Same as source data |
Consistency |

### 3.2 Automated Lifecycle Management

**S3 Lifecycle Policies:**

```hcl
resource "aws_s3_bucket_lifecycle_configuration" "bedrock_data" {
  bucket = aws_s3_bucket.bedrock_data.id

  rule {
    id     = "transition-to-glacier"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }

    expiration {
      days = 2557  # 7 years for RESTRICTED data
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
```

**CloudWatch Logs Retention:**

```hcl
resource "aws_cloudwatch_log_group" "bedrock_logs" {
  name              = "/aws/bedrock/${var.environment}/invocations"
  retention_in_days = 2557  # 7 years

  tags = {
    Classification = "RESTRICTED"
    Retention      = "7years"
  }
}
```

### 3.3 Legal Hold

When legal hold is required:

1. Legal counsel initiates hold
2. Automated deletion suspended
3. Data flagged with "LegalHold" tag
4. S3 Object Lock enabled (if not already)
5. Hold released only by legal counsel
6. Normal retention resumes after hold lifted

**Implementation:**

```hcl
resource "aws_s3_bucket_object_lock_configuration" "legal_hold" {
  bucket = aws_s3_bucket.bedrock_data.id

  rule {
    default_retention {
      mode = "COMPLIANCE"
      years = 7
    }
  }
}

# Object-level legal hold (applied via API/CLI when needed)
# aws s3api put-object-legal-hold --bucket bedrock-data --key sensitive-document.pdf --legal-hold Status=ON
```

## 4. Secure Disposal

### 4.1 Disposal Methods

**Digital Data (End of Retention Period):**

- **Cryptographic Erasure:** Delete KMS encryption keys (data becomes
  unrecoverable)
- **S3 Object Deletion:** Permanent deletion (all versions)
- **EBS Volume Deletion:** With KMS key deletion
- **Database Deletion:** RDS instance + snapshots + automated backups

**Process:**

1. Retention period expiration verified
2. Legal hold verification (none active)
3. Data Owner approval
4. Automated disposal execution
5. Disposal audit log entry
6. Certificate of destruction generated

**Manual Disposal Verification:**

```bash
# S3 object deletion with version purge
aws s3api delete-object --bucket bedrock-data --key sensitive-file.txt --version-id <version-id>
aws s3api delete-object --bucket bedrock-data --key sensitive-file.txt  # Delete marker

# KMS key deletion (7-30 day waiting period)
aws kms schedule-key-deletion --key-id <key-id> --pending-window-in-days 30
```

**Automated Disposal:**

```python
# Lambda function for automated disposal
import boto3
from datetime import datetime, timedelta

def lambda_handler(event, context):
    s3 = boto3.client('s3')
    bucket_name = event['bucket']

    # List objects with retention metadata
    objects = s3.list_objects_v2(Bucket=bucket_name)

    for obj in objects.get('Contents', []):
        tags = s3.get_object_tagging(Bucket=bucket_name, Key=obj['Key'])

        retention_date = None
        legal_hold = False

        for tag in tags.get('TagSet', []):
            if tag['Key'] == 'RetentionUntil':
                retention_date = datetime.fromisoformat(tag['Value'])
            if tag['Key'] == 'LegalHold' and tag['Value'] == 'true':
                legal_hold = True

        # Dispose if retention expired and no legal hold
        if retention_date and datetime.now() > retention_date and not legal_hold:
            dispose_object(s3, bucket_name, obj['Key'])
            log_disposal(bucket_name, obj['Key'], retention_date)

    return {'statusCode': 200, 'body': 'Disposal process completed'}

def dispose_object(s3, bucket, key):
    # Delete all versions
    versions = s3.list_object_versions(Bucket=bucket, Prefix=key)
    for version in versions.get('Versions', []):
        s3.delete_object(Bucket=bucket, Key=key, VersionId=version['VersionId'])
    # Delete delete markers
    for marker in versions.get('DeleteMarkers', []):
        s3.delete_object(Bucket=bucket, Key=key, VersionId=marker['VersionId'])
```

### 4.2 Certificate of Destruction

For RESTRICTED data disposal:

- Automated certificate generated
- Includes: Data description, retention period, disposal date, disposal method
- Signed by Data Owner and Security Officer
- Retained for audit purposes (7 years)

## 5. Disaster Recovery

### 5.1 Backup Strategy

**3-2-1 Backup Rule:**

- **3 copies** of data: Production + 2 backups
- **2 different media types**: S3 Standard + S3 Glacier
- **1 offsite copy**: Cross-region replication

**Multi-Region Backup:**

```hcl
resource "aws_backup_plan" "bedrock_dr" {
  name = "bedrock-disaster-recovery-plan"

  rule {
    rule_name         = "daily-backup-with-dr"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 5 ? * * *)"  # 5 AM daily

    lifecycle {
      cold_storage_after = 90
      delete_after       = 2557  # 7 years
    }

    # Cross-region copy for disaster recovery
    copy_action {
      destination_vault_arn = aws_backup_vault.dr_region.arn

      lifecycle {
        cold_storage_after = 90
        delete_after       = 2557
      }
    }
  }

  advanced_backup_setting {
    backup_options = {
      WindowsVSS = "enabled"
    }
    resource_type = "EC2"
  }
}

# DR region backup vault
resource "aws_backup_vault" "dr_region" {
  provider    = aws.dr_region
  name        = "bedrock-dr-backup-vault"
  kms_key_arn = aws_kms_key.dr_backup_cmk.arn
}
```

### 5.2 Disaster Recovery Testing

**Annual DR Drill:**

1. **Scenario:** Complete region failure
2. **Objective:** Restore Bedrock infrastructure in DR region within RTO
3. **Scope:**
   - Restore all RESTRICTED and CONFIDENTIAL data
   - Redeploy Bedrock agents and knowledge bases
   - Validate data integrity
   - Test application functionality
4. **Success Criteria:**
   - RTO met (4 hours for RESTRICTED data)
   - RPO met (1 hour data loss maximum)
   - All critical functions operational
5. **Documentation:** DR test report with lessons learned

## 6. Compliance and Audit

### 6.1 Backup Compliance Checks

**AWS Config Rules:**

- `backup-plan-min-frequency-and-min-retention-check`
- `backup-recovery-point-encrypted`
- `backup-recovery-point-manual-deletion-disabled`

**Security Hub Controls:**

- Backup compliance status monitoring
- Backup vault lock verification
- Cross-region backup validation

### 6.2 Audit Evidence

**Maintained Records:**

- Backup success/failure logs (CloudWatch)
- Restore test results (quarterly for RESTRICTED)
- Disaster recovery drill reports (annual)
- Disposal certificates (7 years retention)
- Retention policy exceptions (if any)

## 7. Exceptions

Exceptions to retention periods require:

- Business justification
- Legal counsel approval
- Data Owner approval
- CISO approval (for RESTRICTED data)
- Documented in exception register
- Annual review

## Document Control

| Version | Date       | Author | Changes        |
| ------- | ---------- | ------ | -------------- |
| 1.0     | 2025-11-17 | CISO   | Initial policy |

**Next Review:** 2026-11-17
