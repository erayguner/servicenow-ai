# Encryption Guide

## Table of Contents

1. [Encryption Architecture](#encryption-architecture)
2. [Encryption at Rest](#encryption-at-rest)
3. [Encryption in Transit](#encryption-in-transit)
4. [KMS Key Management](#kms-key-management)
5. [Key Rotation Procedures](#key-rotation-procedures)
6. [Certificate Management](#certificate-management)
7. [Secrets Management](#secrets-management)
8. [Encryption Best Practices](#encryption-best-practices)
9. [Encryption Compliance](#encryption-compliance)
10. [Troubleshooting Encryption Issues](#troubleshooting-encryption-issues)

## Encryption Architecture

### Overview

The encryption architecture protects data at multiple layers:

```
┌──────────────────────────────────────────────────────────┐
│                   Data Classification                     │
├──────────────────────────────────────────────────────────┤
│ Public    │ Internal  │ Confidential │ Restricted        │
└──────────────────────────────────────────────────────────┘
                      │
        ┌─────────────┴─────────────┐
        │                           │
        ▼                           ▼
┌──────────────────┐        ┌──────────────────┐
│ Encryption at    │        │ Encryption in    │
│ Rest             │        │ Transit          │
├──────────────────┤        ├──────────────────┤
│ S3: AES-256      │        │ TLS 1.3          │
│ RDS: AES-256     │        │ Mutual TLS       │
│ DynamoDB: AES-256
│ EBS: AES-256     │        │ VPN Encryption   │
│ Backup: AES-256  │        │ Signature        │
└──────────────────┘        └──────────────────┘
        │                           │
        └──────────────┬────────────┘
                       │
                       ▼
           ┌──────────────────────────┐
           │   KMS Key Management     │
           │ - Master keys (HSM)      │
           │ - Data encryption keys   │
           │ - Key rotation          │
           │ - Access control        │
           └──────────────────────────┘
```

### Encryption Principles

1. **Data Classification First**: Determine sensitivity before encryption
2. **Encrypt Everything**: Even internal data encrypted
3. **Separate Keys**: Different keys for different classifications
4. **Automated Encryption**: Default to encrypted, not opt-in
5. **Strong Algorithms**: AES-256, TLS 1.3, RSA-2048+
6. **Key Rotation**: Annual for master keys, regular for data keys

## Encryption at Rest

### S3 Bucket Encryption

#### Configuration via Bucket Policy
```json
{
  "Bucket": "bedrock-agents-data",
  "ServerSideEncryptionConfiguration": {
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "aws:kms",
          "KMSMasterKeyID": "arn:aws:kms:REGION:ACCOUNT:key/KEY-ID"
        },
        "BucketKeyEnabled": true
      }
    ]
  }
}
```

#### Object-Level Encryption
```bash
# Upload with specific key
aws s3api put-object \
  --bucket bedrock-agents-data \
  --key "data/sensitive.json" \
  --body sensitive.json \
  --sse KMS \
  --sse-kms-key-id arn:aws:kms:REGION:ACCOUNT:key/KEY-ID

# Verify encryption
aws s3api head-object \
  --bucket bedrock-agents-data \
  --key "data/sensitive.json" \
  --query 'ServerSideEncryption'
```

#### Default Encryption Policy
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyUnencryptedObjectUploads",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::bedrock-agents-data/*",
      "Condition": {
        "StringNotEquals": {
          "s3:x-amz-server-side-encryption": "aws:kms"
        }
      }
    }
  ]
}
```

### RDS Database Encryption

#### Enable Encryption at Creation
```bash
aws rds create-db-instance \
  --db-instance-identifier bedrock-database \
  --engine postgres \
  --storage-encrypted \
  --kms-key-id arn:aws:kms:REGION:ACCOUNT:key/KEY-ID \
  --allocated-storage 100 \
  --db-instance-class db.r5.large
```

#### Enable Encryption on Existing Database
```bash
# Create snapshot
aws rds create-db-snapshot \
  --db-instance-identifier bedrock-database \
  --db-snapshot-identifier bedrock-db-encrypted

# Copy snapshot with encryption
aws rds copy-db-snapshot \
  --source-db-snapshot-identifier bedrock-db-encrypted \
  --target-db-snapshot-identifier bedrock-db-encrypted-final \
  --kms-key-id arn:aws:kms:REGION:ACCOUNT:key/KEY-ID

# Restore from encrypted snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier bedrock-database-new \
  --db-snapshot-identifier bedrock-db-encrypted-final
```

### DynamoDB Encryption

#### Table Encryption
```json
{
  "TableName": "agent-state",
  "SSESpecification": {
    "Enabled": true,
    "SSEType": "KMS",
    "KMSMasterKeyId": "arn:aws:kms:REGION:ACCOUNT:key/KEY-ID"
  }
}
```

#### Point-in-Time Recovery
```bash
aws dynamodb update-continuous-backups \
  --table-name agent-state \
  --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true
```

### EBS Volume Encryption

#### Launch Encrypted Instance
```bash
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \
  --instance-type t3.medium \
  --block-device-mappings '[
    {
      "DeviceName": "/dev/xvda",
      "Ebs": {
        "VolumeSize": 100,
        "VolumeType": "gp3",
        "Encrypted": true,
        "KmsKeyId": "arn:aws:kms:REGION:ACCOUNT:key/KEY-ID"
      }
    }
  ]'
```

## Encryption in Transit

### TLS 1.3 Configuration

#### API Gateway with TLS 1.3
```json
{
  "restApiId": "api-id",
  "stageName": "prod",
  "securityPolicy": "TLS_1_3"
}
```

#### ALB with TLS 1.3
```bash
aws elbv2 create-listener \
  --load-balancer-arn arn:aws:elasticloadbalancing:REGION:ACCOUNT:loadbalancer/app/bedrock-alb/1234567890abcdef \
  --protocol HTTPS \
  --port 443 \
  --certificates CertificateArn=arn:aws:acm:REGION:ACCOUNT:certificate/cert-id \
  --ssl-policy ELBSecurityPolicy-TLS13-1-3-2021-06
```

### Certificate Configuration

#### Certificate for API
```bash
# Request certificate
aws acm request-certificate \
  --domain-name bedrock-api.example.com \
  --validation-method DNS \
  --certificate-transparency-logging-preference ENABLED

# Validate and wait for issuance
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:REGION:ACCOUNT:certificate/cert-id \
  --query 'Certificate.Status'
```

### Mutual TLS (mTLS)

#### Client Certificate Authentication
```bash
# Create private CA
aws acm-pca create-certificate-authority \
  --certificate-authority-configuration \
  'KeyAlgorithm=RSA_2048,SigningAlgorithm=SHA256WITHRSA' \
  --certificate-authority-type ROOT

# Issue client certificate
aws acm-pca request-certificate \
  --certificate-authority-arn arn:aws:acm-pca:REGION:ACCOUNT:certificate-authority/ca-id \
  --csr fileb://client.csr \
  --signing-algorithm SHA256WITHRSA
```

### VPN Encryption

#### VPN Connection with Encryption
```bash
aws ec2 create-vpn-connection \
  --type ipsec.1 \
  --customer-gateway-id cgw-12345678 \
  --vpn-gateway-id vgw-87654321 \
  --options 'StaticRoutesOnly=false,TunnelOptions=[
    {
      Phase1EncryptionAlgorithms=[
        {Value=AES256}
      ],
      Phase2EncryptionAlgorithms=[
        {Value=AES256}
      ]
    }
  ]'
```

## KMS Key Management

### Key Hierarchy

```
Master Key (Customer Managed)
│
├─ Data Encryption Key (Per object)
├─ Data Encryption Key (Per object)
└─ Data Encryption Key (Per object)

Each DEK:
- Encrypted with CMK
- Valid for single object
- Discarded after use
- Never stored plaintext
```

### Key Creation

#### Create Customer-Managed Key
```bash
aws kms create-key \
  --origin AWS_KMS \
  --description "Bedrock Agents Data Encryption Key" \
  --key-usage ENCRYPT_DECRYPT \
  --key-spec SYMMETRIC_DEFAULT

# Returned: KeyId and Arn
```

#### Key Alias
```bash
aws kms create-alias \
  --alias-name alias/bedrock-agents-key \
  --target-key-id KEY-ID
```

### Key Policy

#### Customer-Managed Key Policy
```json
{
  "Sid": "Enable Root Account Permissions",
  "Effect": "Allow",
  "Principal": {
    "AWS": "arn:aws:iam::ACCOUNT:root"
  },
  "Action": "kms:*",
  "Resource": "*"
}
```

```json
{
  "Sid": "Allow Services to Use Key",
  "Effect": "Allow",
  "Principal": {
    "Service": [
      "s3.amazonaws.com",
      "rds.amazonaws.com",
      "logs.amazonaws.com"
    ]
  },
  "Action": [
    "kms:Decrypt",
    "kms:GenerateDataKey",
    "kms:DescribeKey"
  ],
  "Resource": "*"
}
```

```json
{
  "Sid": "Allow Lambda Execution Role",
  "Effect": "Allow",
  "Principal": {
    "AWS": "arn:aws:iam::ACCOUNT:role/LambdaExecutionRole"
  },
  "Action": [
    "kms:Decrypt",
    "kms:GenerateDataKey"
  ],
  "Resource": "*"
}
```

```json
{
  "Sid": "Deny Unencrypted Operations",
  "Effect": "Deny",
  "Principal": "*",
  "Action": "kms:Decrypt",
  "Resource": "*",
  "Condition": {
    "Bool": {
      "kms:EncryptionContextEquals:Service": "bedrock"
    }
  }
}
```

### Key Monitoring

#### CloudTrail Logging
```bash
# Enable CloudTrail logging for key
aws kms put-key-policy \
  --key-id KEY-ID \
  --policy-name default \
  --policy '...' # Include CloudTrail action logging

# View key usage
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=KEY-ID \
  --max-results 50
```

#### CloudWatch Metrics
```bash
# Disable or enable key rotation
aws kms enable-key-rotation \
  --key-id KEY-ID

# View key state
aws kms describe-key \
  --key-id KEY-ID \
  --query 'KeyMetadata.[KeyState,KeyUsage]'
```

## Key Rotation Procedures

### Automatic Key Rotation

#### Enable Annual Rotation
```bash
aws kms enable-key-rotation \
  --key-id KEY-ID

# Verify
aws kms get-key-rotation-status \
  --key-id KEY-ID
```

#### Rotation Timeline
```
Timeline:
- Year 0: Initial key generation
- Year 1: Rotation triggered automatically
- Month 1-2: New key version used for new encryptions
- Month 2-3: Old keys still available for decryption
- Month 12: Next rotation triggered
```

### Manual Key Rotation

#### Scenario: Key Compromise Suspected
```bash
# Step 1: Create new key immediately
aws kms create-key \
  --origin AWS_KMS \
  --description "Bedrock Emergency Rotation Key"

# Step 2: Update aliases to point to new key
aws kms update-alias \
  --alias-name alias/bedrock-agents-key \
  --target-key-id NEW-KEY-ID

# Step 3: Re-encrypt existing data
# For S3: Use S3 batch operations to re-encrypt objects
# For RDS: Create encrypted snapshot with new key
# For DynamoDB: Export and re-import with new key

# Step 4: Disable old key after re-encryption
aws kms disable-key \
  --key-id OLD-KEY-ID

# Step 5: Schedule key deletion (7-30 day wait)
aws kms schedule-key-deletion \
  --key-id OLD-KEY-ID \
  --pending-window-in-days 30
```

### Data Re-encryption Process

#### S3 Objects
```bash
# Use S3 batch operations
aws s3control create-job \
  --account-id ACCOUNT \
  --operation 'LambdaInvoke' \
  --manifest '{"Spec": {"Format": "S3BatchOperations_CSV_20180820"}, "Location": "s3://bucket/manifest.csv"}' \
  --report '{
    "Bucket": "s3://bucket/reports",
    "Prefix": "re-encryption",
    "Format": "Report_CSV_20180820",
    "Enabled": true,
    "ReportScope": "AllTasks"
  }' \
  --priority 1 \
  --tags 'Key=Purpose,Value=ReEncryption'
```

#### RDS Database
```bash
# Create snapshot with old key
aws rds create-db-snapshot \
  --db-instance-identifier bedrock-database \
  --db-snapshot-identifier bedrock-db-rekey

# Copy with new key
aws rds copy-db-snapshot \
  --source-db-snapshot-identifier bedrock-db-rekey \
  --target-db-snapshot-identifier bedrock-db-rekey-new \
  --kms-key-id arn:aws:kms:REGION:ACCOUNT:key/NEW-KEY-ID

# Restore from new snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier bedrock-database-new \
  --db-snapshot-identifier bedrock-db-rekey-new

# Point applications to new instance
# Delete old instance after validation
```

## Certificate Management

### Certificate Lifecycle

```
Timeline:
0-30 days: Fresh certificate, monitor
30-60 days: No action needed
60-90 days: No action needed
90+ days: Consider renewal
60 days to expiration: AWS ACM auto-renews
30 days to expiration: Alerts if renewal fails
Expiration: Certificate invalid, service failure
```

### Certificate Renewal

#### Automatic Renewal (ACM)
```bash
# Enable transparency logging
aws acm update-certificate-options \
  --certificate-arn arn:aws:acm:REGION:ACCOUNT:certificate/cert-id \
  --options CertificateTransparencyLoggingPreference=ENABLED

# Monitor renewal
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:REGION:ACCOUNT:certificate/cert-id \
  --query 'Certificate.[Status,NotAfter,RenewalEligibility]'
```

#### Manual Renewal if Needed
```bash
# Request new certificate
aws acm request-certificate \
  --domain-name bedrock-api.example.com \
  --validation-method DNS

# Wait for validation
# Update listeners to use new certificate
aws elbv2 modify-listener \
  --listener-arn arn:aws:elasticloadbalancing:... \
  --certificates CertificateArn=arn:aws:acm:REGION:ACCOUNT:certificate/NEW-CERT-ID
```

### Certificate Monitoring

#### CloudWatch Alarms
```bash
aws cloudwatch put-metric-alarm \
  --alarm-name bedrock-certificate-expiration \
  --alarm-description "Alert when certificate expires in 30 days" \
  --metric-name DaysToExpiry \
  --namespace AWS/CertificateManager \
  --statistic Minimum \
  --period 86400 \
  --threshold 30 \
  --comparison-operator LessThanOrEqualToThreshold \
  --alarm-actions arn:aws:sns:REGION:ACCOUNT:security-alerts
```

## Secrets Management

### Secrets Manager Integration

#### Store Sensitive Data
```bash
# Store database password
aws secretsmanager create-secret \
  --name bedrock/rds/password \
  --description "RDS master password" \
  --kms-key-id arn:aws:kms:REGION:ACCOUNT:key/KEY-ID \
  --secret-string '{"username":"admin","password":"SuperSecure123!"}'

# Store API key
aws secretsmanager create-secret \
  --name bedrock/api/key \
  --kms-key-id arn:aws:kms:REGION:ACCOUNT:key/KEY-ID \
  --secret-string "api-key-value-here"
```

#### Retrieve Secret in Lambda
```python
import json
import boto3

client = boto3.client('secretsmanager')

def lambda_handler(event, context):
    response = client.get_secret_value(SecretId='bedrock/rds/password')

    if 'SecretString' in response:
        secret = json.loads(response['SecretString'])
        db_password = secret['password']

    return {'statusCode': 200}
```

### Automatic Rotation

#### Configure Rotation Function
```bash
aws secretsmanager rotate-secret \
  --secret-id bedrock/rds/password \
  --rotation-lambda-arn arn:aws:lambda:REGION:ACCOUNT:function:RDSPasswordRotation \
  --rotation-rules AutomaticallyAfterDays=30
```

#### Rotation Lambda Lifecycle
```
1. Create Secret: Generate new password
2. Set Secret: Apply new password to RDS
3. Test Secret: Connect to RDS with new password
4. Finish Secret: Mark rotation complete
```

## Encryption Best Practices

### 1. Encrypt by Default
- Enable encryption on all new resources
- Enable encryption on existing resources
- Use customer-managed keys for sensitive data
- Use service-managed keys for general data

### 2. Key Management
- Use separate keys for different classifications
- Enable automatic key rotation (annual)
- Restrict key access via key policies
- Monitor key usage via CloudTrail

### 3. Certificate Management
- Use AWS ACM for certificate automation
- Monitor certificate expiration
- Enforce TLS 1.3 minimum
- Use SAN certificates for flexibility

### 4. Secrets Rotation
- Rotate credentials every 30-90 days
- Automate rotation where possible
- Test rotation procedures regularly
- Monitor rotation failures

### 5. Compliance
- Document encryption for each resource
- Maintain encryption audit trail
- Review encryption configuration quarterly
- Test encryption/decryption regularly

## Encryption Compliance

### Supported Standards
- FIPS 140-2 Level 2: AWS KMS
- FIPS 140-2 Level 3: AWS CloudHSM
- NIST SP 800-38D: AES-GCM mode
- Common Criteria EAL 2+: AWS services

### Compliance Verification
```bash
# Verify S3 encryption
aws s3api get-bucket-encryption \
  --bucket bedrock-agents-data

# Verify RDS encryption
aws rds describe-db-instances \
  --db-instance-identifier bedrock-database \
  --query 'DBInstances[0].StorageEncrypted'

# Verify DynamoDB encryption
aws dynamodb describe-table \
  --table-name agent-state \
  --query 'Table.SSEDescription'

# Verify KMS key rotation
aws kms get-key-rotation-status \
  --key-id KEY-ID
```

## Troubleshooting Encryption Issues

### KMS Key Access Errors

#### Problem: "AccessDenied" on Decrypt
```
Cause: IAM role lacks kms:Decrypt permission

Solution:
1. Check role's KMS policy
2. Verify key policy allows role
3. Add kms:Decrypt to role trust policy
4. Check CloudTrail for denied actions
```

#### Problem: "InvalidKeyId" Error
```
Cause: Key doesn't exist or access denied

Solution:
1. Verify key ID/ARN is correct
2. Check key is in same region
3. Verify key is enabled (not disabled)
4. Check key status: aws kms describe-key
```

### Certificate Issues

#### Problem: Certificate Validation Failed
```
Cause: DNS validation not completed

Solution:
1. Check DNS records for CNAME validation
2. Verify CNAME propagation (can take 15+ min)
3. Check certificate status in ACM console
4. Request new certificate if timeout
```

#### Problem: Certificate Expired
```
Cause: Auto-renewal failed or missed

Solution:
1. Request new certificate immediately
2. Update resources to use new cert
3. Investigate renewal failure in logs
4. Set up monitoring for future renewals
```

---

**Document Version**: 1.0
**Last Updated**: November 2024
**Next Review**: May 2025
