# IAM Security Guide

## Table of Contents

1. [IAM Architecture for Bedrock](#iam-architecture-for-bedrock)
2. [Service Roles and Policies](#service-roles-and-policies)
3. [Least Privilege Implementation](#least-privilege-implementation)
4. [Role-Based Access Control](#role-based-access-control)
5. [Service Control Policies](#service-control-policies)
6. [Permission Boundaries](#permission-boundaries)
7. [Cross-Account Access](#cross-account-access)
8. [Credential Management](#credential-management)
9. [Access Reviews and Audit](#access-reviews-and-audit)
10. [Best Practices](#best-practices)

## IAM Architecture for Bedrock

### Overview

The IAM architecture implements zero trust principles with multiple layers of access control:

```
┌────────────────────────────────────────────────────────────┐
│              Organization (AWS Organizations)              │
├────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Root Account (Minimal use, emergency only)         │  │
│  │  - AWS Organizations setup only                     │  │
│  │  - Billing and account management                   │  │
│  │  - MFA delete on S3 buckets                         │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Delegated Administrator Account                    │  │
│  │  - Cross-account access from member accounts        │  │
│  │  - Security and compliance monitoring               │  │
│  │  - Centralized audit logs                           │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Production Account                                 │  │
│  │  - Bedrock Agents infrastructure                    │  │
│  │  - Service roles for Lambda, ECS, etc.             │  │
│  │  - Resource-based policies                          │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Development Account                                │  │
│  │  - Testing and development                          │  │
│  │  - Non-production services                          │  │
│  │  - Experimentation allowed                          │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Logging and Audit Account                          │  │
│  │  - CloudTrail logs aggregation                      │  │
│  │  - CloudWatch log archival                          │  │
│  │  - Security Hub centralization                      │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
└────────────────────────────────────────────────────────────┘
```

### IAM Principles

1. **Least Privilege**: Grant minimum required permissions
2. **Separation of Duties**: Different roles for different functions
3. **Defense in Depth**: Multiple control layers
4. **Audit Trail**: Log all access decisions
5. **Regular Review**: Quarterly access reviews
6. **Automated Enforcement**: Use SCPs for boundary enforcement

## Service Roles and Policies

### Lambda Execution Role

#### Purpose
Lambda functions need permissions to:
- Write logs to CloudWatch
- Access other AWS services (RDS, DynamoDB, Bedrock, etc.)
- Assume other roles (if needed)

#### Policy Structure
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CloudWatchLogs",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:REGION:ACCOUNT:log-group:/aws/lambda/*"
    },
    {
      "Sid": "BedrockAccess",
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:CreateAgent",
        "bedrock:GetAgent"
      ],
      "Resource": "arn:aws:bedrock:REGION:ACCOUNT:*"
    },
    {
      "Sid": "DatabaseAccess",
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:Query",
        "dynamodb:BatchGetItem"
      ],
      "Resource": "arn:aws:dynamodb:REGION:ACCOUNT:table/agent-*"
    },
    {
      "Sid": "SecretsAccess",
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "arn:aws:secretsmanager:REGION:ACCOUNT:secret:bedrock/*"
    },
    {
      "Sid": "KMSDecrypt",
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ],
      "Resource": "arn:aws:kms:REGION:ACCOUNT:key/*",
      "Condition": {
        "StringEquals": {
          "aws:ResourceOrgID": "ORGANIZATION_ID"
        }
      }
    }
  ]
}
```

#### Trust Relationship
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

### ECS Task Execution Role

#### Purpose
ECS container runtime needs permissions to:
- Pull images from ECR
- Access CloudWatch logs
- Access Secrets Manager for sensitive data
- KMS decryption for encrypted data

#### Policy Structure
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ECRAccess",
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer"
      ],
      "Resource": "*"
    },
    {
      "Sid": "CloudWatchLogs",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:REGION:ACCOUNT:log-group:/ecs/*"
    },
    {
      "Sid": "SecretsAccess",
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "arn:aws:secretsmanager:REGION:ACCOUNT:secret:ecs/*"
    }
  ]
}
```

### ECS Task Role

#### Purpose
Container application needs permissions to:
- Access Bedrock API
- Read/write to databases
- Access object storage
- Invoke other services

#### Policy Structure
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "BedrockAccess",
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream"
      ],
      "Resource": "arn:aws:bedrock:REGION:ACCOUNT:inference-profile/*"
    },
    {
      "Sid": "DynamoDBAccess",
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:Query",
        "dynamodb:UpdateItem"
      ],
      "Resource": "arn:aws:dynamodb:REGION:ACCOUNT:table/agent-state"
    },
    {
      "Sid": "S3Access",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::bedrock-agents-*/*"
    }
  ]
}
```

### API Gateway Execution Role

#### Purpose
API Gateway needs permissions to:
- Write logs to CloudWatch
- Call Lambda functions
- Access other services

#### Policy Structure
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CloudWatchLogs",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogDeliveryService",
        "logs:GetLogDeliveryServices",
        "logs:UpdateLogDeliveryService",
        "logs:DeleteLogDeliveryService",
        "logs:PutResourcePolicy",
        "logs:DescribeResourcePolicies",
        "logs:DescribeLogGroups"
      ],
      "Resource": "*"
    }
  ]
}
```

## Least Privilege Implementation

### Principle Definition

Least privilege means:
- Grant minimum permissions needed to perform job
- Deny everything not explicitly allowed
- Use specific resource ARNs, not wildcards
- Restrict actions to essential operations
- Apply conditions to limit context

### Policy Construction Template

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DescriptiveName",
      "Effect": "Allow",
      "Action": [
        "service:Action1",
        "service:Action2"
      ],
      "Resource": "arn:aws:service:REGION:ACCOUNT:resourcetype/resource-name",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": "REGION"
        },
        "DateGreaterThan": {
          "aws:CurrentTime": "2024-01-01T00:00:00Z"
        },
        "DateLessThan": {
          "aws:CurrentTime": "2025-01-01T00:00:00Z"
        }
      }
    }
  ]
}
```

### Resource-Level Specificity

#### Bad: Overly Permissive
```json
{
  "Effect": "Allow",
  "Action": "dynamodb:*",
  "Resource": "*"
}
```

#### Good: Specific Resources
```json
{
  "Effect": "Allow",
  "Action": [
    "dynamodb:GetItem",
    "dynamodb:Query"
  ],
  "Resource": "arn:aws:dynamodb:us-east-1:123456789:table/agent-state"
}
```

### Action-Level Specificity

#### Bad: Broad Actions
```json
{
  "Effect": "Allow",
  "Action": "s3:*",
  "Resource": "arn:aws:s3:::bedrock-agents/*"
}
```

#### Good: Specific Actions
```json
{
  "Effect": "Allow",
  "Action": [
    "s3:GetObject",
    "s3:PutObject"
  ],
  "Resource": "arn:aws:s3:::bedrock-agents/*/data/*"
}
```

### Condition-Based Restrictions

#### IP Restriction
```json
{
  "Effect": "Allow",
  "Action": "ec2:*",
  "Resource": "*",
  "Condition": {
    "IpAddress": {
      "aws:SourceIp": ["10.0.0.0/8", "203.0.113.0/24"]
    }
  }
}
```

#### Time-Based Restriction
```json
{
  "Effect": "Allow",
  "Action": "iam:*",
  "Resource": "*",
  "Condition": {
    "DateGreaterThan": {
      "aws:CurrentTime": "2024-01-01T00:00:00Z"
    },
    "DateLessThan": {
      "aws:CurrentTime": "2024-12-31T23:59:59Z"
    }
  }
}
```

#### MFA Requirement
```json
{
  "Effect": "Allow",
  "Action": [
    "iam:DeleteUser",
    "iam:PutUserPolicy"
  ],
  "Resource": "arn:aws:iam::ACCOUNT:user/*",
  "Condition": {
    "Bool": {
      "aws:MultiFactorAuthPresent": "true"
    }
  }
}
```

## Role-Based Access Control

### Role Hierarchy

```
Organization Structure:

┌─────────────────────────────────────┐
│  Organization Admin Role            │
│  - Account creation/management      │
│  - SCP management                   │
│  - Billing and reservations         │
│  - Limited to 2-3 people            │
└─────────────────────────────────────┘
              │
┌─────────────┴─────────────┬──────────────────┬──────────────┐
│                           │                  │              │
▼                           ▼                  ▼              ▼
Security Admin         Operations Admin    Development Lead  Audit Role
- IAM policies         - EC2 management    - Lambda deploy   - Read-only
- KMS keys             - RDS management    - Code review     - Report
- GuardDuty            - Network config    - Testing         - Assessment
- Security Hub         - Monitoring        - Dev tools       - No modify
- Audit logs           - Incident response
```

### Predefined Role Set

#### 1. Bedrock Agents Coordinator
```
Permissions:
- bedrock:InvokeModel
- bedrock:InvokeModelWithResponseStream
- bedrock:CreateAgent
- bedrock:GetAgent
- bedrock:UpdateAgent
- bedrock:CreateAgentAction
- iam:PassRole (for agent execution role only)
- logs:PutLogEvents

Used by: Lambda coordinator function
Trust: Lambda service
```

#### 2. Bedrock Agents Executor
```
Permissions:
- bedrock:InvokeModel
- dynamodb:GetItem
- dynamodb:PutItem
- dynamodb:UpdateItem
- dynamodb:Query
- s3:GetObject
- s3:PutObject
- kms:Decrypt
- kms:GenerateDataKey
- secretsmanager:GetSecretValue

Used by: Lambda agent executor, ECS containers
Trust: Lambda, ECS services
```

#### 3. Knowledge Processor
```
Permissions:
- s3:GetObject
- s3:PutObject
- textract:*
- dynamodb:PutItem
- dynamodb:UpdateItem
- logs:PutLogEvents

Used by: Document processing Lambda
Trust: Lambda service
```

#### 4. Development Team
```
Permissions:
- lambda:CreateFunction
- lambda:UpdateFunctionCode
- lambda:DeleteFunction
- logs:FilterLogEvents
- dynamodb:Scan (limited tables)
- iam:PassRole (to specific roles)

Restrictions:
- No production deployment
- Limited to dev environment
- No KMS key management
- No IAM policy creation
```

#### 5. Operations Team
```
Permissions:
- cloudwatch:*
- logs:*
- ec2:DescribeInstances
- rds:DescribeDBInstances
- dynamodb:DescribeTable
- autoscaling:*
- elasticloadbalancing:*

Restrictions:
- No creation/deletion of resources
- No security group changes
- Read-only for sensitive services
```

#### 6. Security Team
```
Permissions:
- iam:*
- kms:*
- secretsmanager:*
- guardduty:*
- securityhub:*
- cloudtrail:*
- config:*

Restrictions:
- No deletion of audit logs
- No removal of security controls
- Requires dual approval for changes
```

## Service Control Policies

### SCP Strategy

SCPs act as permission boundaries at the organization level:

```
Effect on Permissions:

┌──────────────────────────────────────┐
│     Organization SCP                 │
│  (Applies to all accounts)           │
├──────────────────────────────────────┤
│     Account SCP (if any)             │
│  (Further restricts permissions)     │
├──────────────────────────────────────┤
│     Identity-based Policy            │
│  (Lambda role policy)                │
├──────────────────────────────────────┤
│     Resource-based Policy            │
│  (S3 bucket policy)                  │
└──────────────────────────────────────┘

Result: LEAST RESTRICTIVE of all policies
```

### Recommended SCPs

#### 1. Prevent Disabling Security Controls
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PreventDisablingCloudTrail",
      "Effect": "Deny",
      "Action": [
        "cloudtrail:DeleteTrail",
        "cloudtrail:StopLogging",
        "cloudtrail:UpdateTrail"
      ],
      "Resource": "*"
    },
    {
      "Sid": "PreventDisablingGuardDuty",
      "Effect": "Deny",
      "Action": [
        "guardduty:DeleteDetector",
        "guardduty:DisassociateFromMasterAccount"
      ],
      "Resource": "*"
    },
    {
      "Sid": "PreventModifyingConfigRules",
      "Effect": "Deny",
      "Action": [
        "config:DeleteConfigRule",
        "config:StopConfigurationRecorder"
      ],
      "Resource": "*"
    }
  ]
}
```

#### 2. Restrict Region Usage
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowedRegions",
      "Effect": "Deny",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:RequestedRegion": [
            "us-east-1",
            "us-west-2",
            "eu-west-1"
          ]
        }
      }
    }
  ]
}
```

#### 3. Prevent Public Access to Data
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyPublicS3Access",
      "Effect": "Deny",
      "Action": [
        "s3:PutAccountPublicAccessBlock",
        "s3:PutBucketPublicAccessBlock"
      ],
      "Resource": "*",
      "Condition": {
        "Bool": {
          "s3:BlockPublicAcls": "false"
        }
      }
    },
    {
      "Sid": "DenyUnencryptedUploads",
      "Effect": "Deny",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::*/*",
      "Condition": {
        "StringNotEquals": {
          "s3:x-amz-server-side-encryption": "AES256"
        }
      }
    }
  ]
}
```

## Permission Boundaries

### Boundary Purpose

Permission boundaries define maximum permissions a role can have:
- Role's identity-based policy cannot exceed boundary
- AND logic with role policies
- Prevents accidental over-permission

### Boundary Policy Template

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowedServices",
      "Effect": "Allow",
      "Action": [
        "lambda:*",
        "dynamodb:GetItem",
        "dynamodb:Query",
        "dynamodb:PutItem",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "s3:GetObject",
        "s3:PutObject",
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ],
      "Resource": "*"
    },
    {
      "Sid": "DenyHighRiskActions",
      "Effect": "Deny",
      "Action": [
        "iam:*",
        "organizations:*",
        "account:*",
        "s3:DeleteBucket",
        "dynamodb:DeleteTable",
        "kms:ScheduleKeyDeletion",
        "ec2:*"
      ],
      "Resource": "*"
    }
  ]
}
```

### Boundary Application

#### For Development Team
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "lambda:*",
        "dynamodb:*",
        "s3:*",
        "logs:*",
        "cloudformation:DescribeStacks"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Deny",
      "Action": [
        "iam:*",
        "kms:*",
        "secretsmanager:*",
        "ec2:*",
        "rds:*"
      ],
      "Resource": "*"
    }
  ]
}
```

## Cross-Account Access

### Use Cases
- Multi-account organization
- Customer tenants (if multi-tenant)
- Disaster recovery failover
- Development/staging/production separation

### Architecture

```
Account A (Production)          Account B (Disaster Recovery)
┌────────────────────────┐     ┌────────────────────────┐
│ IAM Role: ProdAccess   │     │ IAM Role: DRAccess    │
│ Trust: Account B       │<--->│ Trust: Account A      │
│ Policy: Full access    │     │ Policy: Limited access│
└────────────────────────┘     └────────────────────────┘
```

### Trust Relationship for Cross-Account

#### In Account A (Trusted Account)
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::ACCOUNT_B:role/CrossAccountRole"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "unique-external-id-123"
        }
      }
    }
  ]
}
```

#### In Account B (Principal Account)
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::ACCOUNT_A:role/CrossAccountRole"
    }
  ]
}
```

### Cross-Account Bedrock Access Pattern

```
Step 1: Service in Account A assumes role in Account B
    aws sts assume-role \
      --role-arn arn:aws:iam::ACCOUNT_B:role/BedrockExecutor \
      --role-session-name bedrock-session \
      --external-id unique-id

Step 2: Receive temporary credentials (AccessKeyId, SecretAccessKey, SessionToken)

Step 3: Use temporary credentials to call Bedrock in Account B
    bedrock:InvokeModel (with assumed role credentials)

Step 4: Audit trail shows Account A assumed role and made calls
    CloudTrail logs both assume-role and API calls
```

## Credential Management

### Human User Credentials

#### Best Practices
1. **No long-lived API keys**
   - Use temporary credentials via IAM roles
   - If keys needed, rotate every 90 days
   - Delete old keys immediately

2. **MFA for all users**
   - Virtual MFA device (authenticator app)
   - Hardware security key (preferred)
   - U2F USB key (highest security)

3. **SSH Key Management**
   - Store in AWS Systems Manager Session Manager
   - Avoid storing locally when possible
   - Use certificate-based SSH (short-lived)

4. **Console Access**
   - SSO for human users (not IAM users)
   - Temporary credentials only
   - Enforced MFA
   - Session timeout (1 hour idle)

#### Implementation
```
User Access Flow:

AWS SSO (Okta/AzureAD)
    │
    ├─ MFA Authentication
    │
    ├─ Temporary AWS Credentials (12-hour max)
    │
    ├─ Federated role assumption
    │
    └─ Access to AWS services
```

### Service Credentials

#### Lambda/ECS Service Credentials
- Use IAM roles (not API keys)
- No manual credential management
- Automatic rotation (credentials valid ~15 minutes)
- CloudTrail logs include role ARN

#### API Keys for External Consumers
```
Management Process:

1. Create API key in API Gateway
2. Store in Secrets Manager
3. Rotate every 90 days
4. Audit usage in CloudTrail
5. Revoke immediately if compromised

Rotation Process:
   New key created
   Both old and new valid for 7 days
   Alert consumers of change
   Old key revoked
```

### Database Credentials

#### Managed by Secrets Manager
```
Rotation Procedure:

1. Lambda rotation function triggered
2. New credentials generated
3. Applied to RDS instance
4. Test connection with new credentials
5. Old credentials removed
6. Audit log created

Rotation Schedule: Every 30 days
```

## Access Reviews and Audit

### Quarterly Access Review

#### Process (1 month duration)

**Week 1-2: Data Collection**
```
Gather:
- All IAM users and roles
- Current permissions
- Last access date per service
- Recent changes
- Security findings related to IAM
```

**Week 2-3: Management Review**
```
Managers review:
- Team members' access
- Necessity of permissions
- Recent activity
- Compliance with least privilege

Managers certify:
- Access is appropriate
- Remove unnecessary access
- Document exceptions
```

**Week 4: Remediation**
```
Security team:
- Revoke unnecessary access
- Update documentation
- Report findings to leadership
- Plan for next quarter
```

### Annual Access Certification

#### Comprehensive Review
```
Scope: All IAM users and service roles

Assessment:
1. Permission necessity
2. Least privilege compliance
3. Segregation of duties
4. Access control effectiveness
5. Compliance with policies

Output:
- Certification report
- Findings and recommendations
- Remediation plan
- Management sign-off
```

### Audit Procedures

#### CloudTrail Analysis
```
Reviews:
- New user/role creation
- Permission changes
- Assume role events
- Cross-account access
- Sensitive operations
```

#### Config Rules
```
Continuously monitors:
- iam-user-mfa-enabled
- iam-policy-no-statements-with-admin-access
- iam-user-no-policies-check
- iam-role-managed-policy-check
- iam-inline-policy-blacklist-check
```

#### GuardDuty IAM Findings
```
Detects:
- Unusual assume role activity
- API calls from suspicious IPs
- Credential compromise
- Unusual API access patterns
```

## Best Practices

### 1. Principal of Least Privilege
- Grant minimum permissions needed
- Deny everything else by default
- Use specific resource ARNs
- Regular audit and cleanup

### 2. Segregation of Duties
- Different roles for different functions
- No "super admin" for single person
- Require multiple approvals for sensitive actions
- Cross-account separation for environments

### 3. Regular Access Reviews
- Quarterly reviews mandatory
- Remove unused roles/policies
- Update documentation
- Enforce least privilege

### 4. Audit and Monitoring
- CloudTrail for all API calls
- Config Rules for policy compliance
- GuardDuty for threat detection
- Regular compliance assessments

### 5. Credential Rotation
- Service roles: Automatic (AWS managed)
- Human users: MFA always enabled
- API keys: Rotate every 90 days
- Database passwords: Every 30 days

### 6. Documentation
- Maintain role inventory
- Document permission justification
- Audit trail of changes
- Keep playbooks updated

---

**Document Version**: 1.0
**Last Updated**: November 2024
**Next Review**: May 2025
