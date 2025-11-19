# Access Control Policy
## Amazon Bedrock Agents Infrastructure

**Document Version:** 1.0
**Effective Date:** 2025-11-17
**Last Reviewed:** 2025-11-17
**Next Review:** 2026-11-17
**Policy Owner:** Chief Information Security Officer (CISO)
**Approved By:** Executive Leadership Team

---

## 1. Purpose

This Access Control Policy establishes requirements for managing access to Amazon Bedrock Agents infrastructure and data. The policy ensures that only authorized individuals can access resources based on business needs, regulatory requirements, and the principle of least privilege.

## 2. Scope

This policy applies to:
- All AWS accounts and resources in the Bedrock agents infrastructure
- All Amazon Bedrock agents, knowledge bases, and models
- All users, groups, roles, and service principals
- All access methods (console, CLI, SDK, API)
- All environments (development, staging, production)
- All employees, contractors, and third parties

## 3. Access Control Principles

### 3.1 Least Privilege
Users and services receive minimum permissions necessary to perform assigned functions.

### 3.2 Separation of Duties
No single individual has control over all phases of a critical or sensitive operation.

### 3.3 Defense in Depth
Multiple layers of access controls are implemented.

### 3.4 Need-to-Know
Access to data is granted only when required for job function.

### 3.5 Deny by Default
Access is explicitly denied unless explicitly allowed.

---

## 4. Identity Management

### 4.1 User Provisioning

**New User Onboarding:**
1. Manager submits access request via ticketing system
2. HR verification of employment status
3. Background check completed (for RESTRICTED data access)
4. Role assignment based on job function
5. Account provisioning:
   - IAM Identity Center (SSO) for human users
   - IAM roles for service accounts
6. Security training completion required before access granted
7. Acceptable Use Policy acknowledgment
8. Initial password/MFA device setup (in-person or secure channel)

**Account Types:**
- **Human Users:** IAM Identity Center (AWS SSO)
- **Service Accounts:** IAM roles (no long-term credentials)
- **Federated Access:** SAML 2.0 integration with corporate IdP
- **Emergency Access:** Break-glass accounts (highly restricted)

**Prohibited:**
- Shared user accounts
- Generic user accounts (e.g., "admin", "service")
- Root account usage for daily operations

### 4.2 User Deprovisioning

**Termination Process:**
1. HR notifies security team of termination
2. Immediate access revocation (within 1 hour):
   - IAM user disabled/deleted
   - SSO access revoked
   - MFA devices deactivated
   - Access keys deactivated
   - Session tokens revoked
3. Resource ownership transfer to manager
4. Exit interview including return of company devices
5. 30-day grace period for data retrieval by manager (read-only)
6. Audit log review for final 90 days of activity
7. Account deletion after retention period

**Change of Role:**
1. Manager submits role change request
2. New permissions granted (if additional access needed)
3. Old permissions removed (if no longer needed)
4. Access review within 7 days of role change

### 4.3 Identity Lifecycle

**Identity States:**
- **Active:** Full access based on assigned permissions
- **Inactive:** No login for 90 days, disabled automatically
- **Suspended:** Temporary suspension (e.g., leave of absence)
- **Terminated:** Access revoked, account deleted

**Automated Processes:**
- Inactive account detection (90 days no login)
- Inactive credential detection (90 days no use)
- Unused permission identification (AWS IAM Access Analyzer)
- Quarterly access reviews

---

## 5. Authentication

### 5.1 Password Policy

**IAM Password Policy (Fallback only - SSO preferred):**
```yaml
Minimum password length: 14 characters
Require uppercase letters: Yes
Require lowercase letters: Yes
Require numbers: Yes
Require symbols: Yes
Allow users to change password: Yes
Require password change: 90 days
Password reuse prevention: 24 passwords
Password complexity: High
Hard expiry: No (to avoid password cycling)
```

**AWS SSO Password Policy:**
- Enforced via corporate Identity Provider (IdP)
- Minimum 14 characters
- Complexity requirements
- Password history: 24 previous passwords
- Maximum age: 90 days
- Account lockout: 5 failed attempts, 30-minute lockout

### 5.2 Multi-Factor Authentication (MFA)

**MFA Requirements by Classification:**

| User Type | Data Classification | MFA Requirement |
|-----------|---------------------|-----------------|
| All users | RESTRICTED | **Mandatory** (hardware/U2F preferred) |
| All users | CONFIDENTIAL | **Mandatory** |
| All users | INTERNAL | Recommended |
| Root account | N/A | **Mandatory** (hardware token required) |
| Privileged users | N/A | **Mandatory** |
| Break-glass accounts | N/A | **Mandatory** |
| Service accounts (IAM roles) | N/A | Not applicable |

**Approved MFA Methods (in order of preference):**
1. **Hardware U2F/WebAuthn tokens** (YubiKey, Titan Security Key) - **Recommended for RESTRICTED**
2. **TOTP hardware tokens** (RSA SecurID)
3. **Virtual MFA apps** (Authy, Microsoft Authenticator, Google Authenticator)

**Prohibited MFA Methods:**
- SMS-based MFA (vulnerable to SIM swapping)
- Email-based MFA
- Voice call-based MFA

**MFA Enforcement:**
```hcl
# IAM policy requiring MFA for all actions
resource "aws_iam_policy" "require_mfa" {
  name        = "RequireMFA"
  description = "Deny all actions if MFA not present"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyAllExceptListedIfNoMFA"
        Effect = "Deny"
        NotAction = [
          "iam:CreateVirtualMFADevice",
          "iam:EnableMFADevice",
          "iam:GetUser",
          "iam:ListMFADevices",
          "iam:ListVirtualMFADevices",
          "iam:ResyncMFADevice",
          "sts:GetSessionToken"
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

### 5.3 Federated Authentication

**Corporate Identity Provider Integration:**
- SAML 2.0 federation with AWS IAM Identity Center
- Single Sign-On (SSO) for all human users
- Centralized authentication via corporate IdP (Okta, Azure AD, etc.)
- Automatic user provisioning and deprovisioning (SCIM)

**Benefits:**
- Centralized identity management
- Consistent password policy enforcement
- Automatic access revocation on termination
- Audit trail of authentication events
- Conditional access policies (IP restrictions, device compliance)

**Implementation:**
```hcl
resource "aws_ssoadmin_account_assignment" "bedrock_admin" {
  instance_arn       = aws_ssoadmin_instance.main.arn
  permission_set_arn = aws_ssoadmin_permission_set.bedrock_admin.arn
  principal_id       = data.aws_identitystore_group.bedrock_admins.group_id
  principal_type     = "GROUP"
  target_id          = data.aws_caller_identity.current.account_id
  target_type        = "AWS_ACCOUNT"
}
```

### 5.4 Session Management

**Session Timeouts:**
- **AWS Console:** 12 hours maximum, 1 hour recommended for RESTRICTED data
- **Programmatic access (STS):** 12 hours maximum, 1 hour recommended for RESTRICTED data
- **Idle timeout:** 15 minutes of inactivity (console)

**Session Security:**
- Session tokens encrypted in transit
- Session invalidation on logout
- Concurrent session limits (3 active sessions per user)
- Session hijacking prevention (IP address binding)

**Implementation:**
```hcl
# IAM role with maximum session duration
resource "aws_iam_role" "bedrock_restricted_access" {
  name                 = "BedrockRestrictedAccess"
  max_session_duration = 3600  # 1 hour for RESTRICTED data

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          IpAddress = {
            "aws:SourceIp" = var.allowed_cidr_blocks
          }
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
        }
      }
    ]
  })
}
```

---

## 6. Authorization

### 6.1 Role-Based Access Control (RBAC)

**Standard Roles:**

#### Bedrock Administrator
**Responsibilities:** Manage Bedrock infrastructure, agents, knowledge bases
**Permissions:**
- Full access to Bedrock services
- KMS key usage for Bedrock encryption
- S3 access to Bedrock data sources
- CloudWatch Logs access for Bedrock logs
- IAM role creation for Bedrock agents

**Implementation:**
```hcl
resource "aws_iam_policy" "bedrock_administrator" {
  name        = "BedrockAdministrator"
  description = "Full access to Bedrock services for administrators"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "BedrockFullAccess"
        Effect   = "Allow"
        Action   = "bedrock:*"
        Resource = "*"
      },
      {
        Sid    = "KMSAccessForBedrock"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "bedrock.${var.aws_region}.amazonaws.com"
          }
        }
      },
      {
        Sid      = "S3AccessForBedrockDataSources"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = "arn:aws:s3:::bedrock-*"
      },
      {
        Sid      = "CloudWatchLogsAccess"
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:log-group:/aws/bedrock/*"
      }
    ]
  })
}
```

#### Bedrock User (Read-Only)
**Responsibilities:** Invoke Bedrock agents, query knowledge bases
**Permissions:**
- Invoke Bedrock agents (read-only)
- Query knowledge bases
- No configuration changes

**Implementation:**
```hcl
resource "aws_iam_policy" "bedrock_user" {
  name        = "BedrockUser"
  description = "Read-only access to invoke Bedrock agents"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "BedrockReadOnly"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeAgent",
          "bedrock:InvokeModel",
          "bedrock:Retrieve",
          "bedrock:RetrieveAndGenerate"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyBedrockWrite"
        Effect = "Deny"
        Action = [
          "bedrock:Create*",
          "bedrock:Update*",
          "bedrock:Delete*",
          "bedrock:Put*"
        ]
        Resource = "*"
      }
    ]
  })
}
```

#### Security Auditor
**Responsibilities:** Review security configurations, audit logs, compliance status
**Permissions:**
- Read-only access to all resources
- CloudTrail log access
- Config compliance reports
- Security Hub findings

**Implementation:**
```hcl
data "aws_iam_policy" "security_audit" {
  arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

resource "aws_iam_policy" "security_auditor_additional" {
  name = "SecurityAuditorAdditional"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudTrailAccess"
        Effect = "Allow"
        Action = [
          "cloudtrail:LookupEvents",
          "cloudtrail:GetTrailStatus",
          "cloudtrail:DescribeTrails",
          "cloudtrail:ListPublicKeys",
          "cloudtrail:GetEventSelectors"
        ]
        Resource = "*"
      },
      {
        Sid    = "SecurityHubAccess"
        Effect = "Allow"
        Action = [
          "securityhub:Get*",
          "securityhub:List*",
          "securityhub:Describe*"
        ]
        Resource = "*"
      }
    ]
  })
}
```

#### Data Owner
**Responsibilities:** Classify data, approve access, manage data lifecycle
**Permissions:**
- Data classification tagging
- Access approval workflows
- Data retention configuration
- Backup management

#### Break-Glass Administrator
**Responsibilities:** Emergency access for incident response
**Permissions:**
- Full administrative access
- Usage: Emergency only, all actions logged and reviewed
- MFA required
- Approval: CISO notification required within 1 hour

**Implementation:**
```hcl
resource "aws_iam_user" "break_glass" {
  name          = "break-glass-admin"
  force_destroy = false

  tags = {
    Purpose       = "Emergency access only"
    Notification  = "CISO immediate notification required"
    ReviewRequired = "All actions audited"
  }
}

resource "aws_iam_user_policy_attachment" "break_glass_admin" {
  user       = aws_iam_user.break_glass.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# CloudWatch alarm for break-glass account usage
resource "aws_cloudwatch_log_metric_filter" "break_glass_usage" {
  name           = "break-glass-account-usage"
  log_group_name = "/aws/cloudtrail/management"
  pattern        = "{ $.userIdentity.userName = \"break-glass-admin\" }"

  metric_transformation {
    name      = "BreakGlassAccountUsage"
    namespace = "Security/AccessControl"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "break_glass_usage_alarm" {
  alarm_name          = "break-glass-account-used"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "BreakGlassAccountUsage"
  namespace           = "Security/AccessControl"
  period              = "60"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "CRITICAL: Break-glass account has been used - immediate CISO notification"
  alarm_actions       = [aws_sns_topic.critical_security_alerts.arn]
}
```

### 6.2 Attribute-Based Access Control (ABAC)

**Use Case:** Fine-grained access control based on resource tags and user attributes

**Example: Data classification-based access**
```hcl
resource "aws_iam_policy" "abac_data_classification" {
  name        = "ABACDataClassification"
  description = "Access based on data classification tags"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAccessToInternalData"
        Effect = "Allow"
        Action = ["bedrock:InvokeAgent", "bedrock:Retrieve"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Classification" = ["Public", "Internal"]
          }
        }
      },
      {
        Sid    = "DenyAccessToRestrictedData"
        Effect = "Deny"
        Action = "*"
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Classification" = "RESTRICTED"
          }
          StringNotEquals = {
            "aws:PrincipalTag/ClearanceLevel" = "RESTRICTED"
          }
        }
      }
    ]
  })
}
```

### 6.3 Service Control Policies (SCPs)

**Organization-wide guardrails:**
```hcl
resource "aws_organizations_policy" "bedrock_scp" {
  name        = "BedrockSecurityControls"
  description = "Security controls for Bedrock services"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyBedrockPublicAccess"
        Effect = "Deny"
        Action = ["bedrock:*"]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "aws:RequestedRegion" = ["us-east-1", "us-west-2", "eu-west-1"]
          }
        }
      },
      {
        Sid    = "DenyBedrockWithoutEncryption"
        Effect = "Deny"
        Action = [
          "bedrock:CreateKnowledgeBase",
          "bedrock:UpdateKnowledgeBase"
        ]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "bedrock:EncryptionKeyArn" = "*"
          }
        }
      },
      {
        Sid    = "RequireVPCEndpointForRestrictedData"
        Effect = "Deny"
        Action = "bedrock:*"
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Classification" = "RESTRICTED"
          }
          StringNotEquals = {
            "aws:SourceVpce" = var.bedrock_vpc_endpoint_id
          }
        }
      }
    ]
  })
}
```

### 6.4 Permission Boundaries

**Limit maximum permissions for IAM entities:**
```hcl
resource "aws_iam_policy" "permission_boundary" {
  name        = "BedrockPermissionBoundary"
  description = "Maximum permissions for Bedrock users"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowBedrockOperations"
        Effect   = "Allow"
        Action   = "bedrock:*"
        Resource = "*"
      },
      {
        Sid    = "AllowSupportingServices"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Sid      = "DenyDangerousOperations"
        Effect   = "Deny"
        Action   = [
          "bedrock:DeleteFoundationModel",
          "bedrock:DeleteProvisionedModelThroughput",
          "iam:*",
          "organizations:*",
          "account:*"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_user" "bedrock_developer" {
  name                 = "bedrock-developer"
  permissions_boundary = aws_iam_policy.permission_boundary.arn
}
```

---

## 7. Network Access Control

### 7.1 VPC Endpoints for Bedrock

**RESTRICTED data requirements:**
- All Bedrock API calls via VPC endpoints (AWS PrivateLink)
- No internet-routable access
- Interface VPC endpoints in private subnets
- Security groups restricting access to authorized sources

**Implementation:**
```hcl
resource "aws_vpc_endpoint" "bedrock" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.bedrock-runtime"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.bedrock_vpc_endpoint.id]
  private_dns_enabled = true

  tags = {
    Name           = "bedrock-runtime-vpc-endpoint"
    Classification = "RESTRICTED"
  }
}

resource "aws_security_group" "bedrock_vpc_endpoint" {
  name        = "bedrock-vpc-endpoint-sg"
  description = "Security group for Bedrock VPC endpoint"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from authorized subnets"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.authorized_cidr_blocks
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# VPC endpoint policy restricting access
resource "aws_vpc_endpoint_policy" "bedrock" {
  vpc_endpoint_id = aws_vpc_endpoint.bedrock.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowBedrockInvocation"
        Effect    = "Allow"
        Principal = "*"
        Action    = [
          "bedrock:InvokeAgent",
          "bedrock:InvokeModel",
          "bedrock:Retrieve"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:PrincipalAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid       = "DenyNonVPCAccess"
        Effect    = "Deny"
        Principal = "*"
        Action    = "bedrock:*"
        Resource  = "*"
        Condition = {
          StringNotEquals = {
            "aws:SourceVpce" = aws_vpc_endpoint.bedrock.id
          }
        }
      }
    ]
  })
}
```

### 7.2 IP Allowlisting

**Conditional access based on source IP:**
```hcl
resource "aws_iam_policy" "ip_restriction" {
  name        = "BedrockIPRestriction"
  description = "Restrict Bedrock access to corporate IP ranges"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowFromCorporateNetwork"
        Effect = "Allow"
        Action = "bedrock:*"
        Resource = "*"
        Condition = {
          IpAddress = {
            "aws:SourceIp" = var.corporate_ip_ranges
          }
        }
      },
      {
        Sid    = "DenyFromOtherIPs"
        Effect = "Deny"
        Action = "bedrock:*"
        Resource = "*"
        Condition = {
          NotIpAddress = {
            "aws:SourceIp" = var.corporate_ip_ranges
          }
        }
      }
    ]
  })
}
```

---

## 8. Access Reviews and Audits

### 8.1 Access Review Schedule

**RESTRICTED Data Access:**
- **Frequency:** Monthly
- **Scope:** All users with RESTRICTED data access
- **Process:**
  1. Generate access report (IAM Access Analyzer)
  2. Data Owner reviews and approves/revokes access
  3. Unused permissions removed
  4. Exceptions documented
  5. Access review results logged
- **Approval:** Data Owner and CISO

**CONFIDENTIAL Data Access:**
- **Frequency:** Quarterly
- **Scope:** All users with CONFIDENTIAL data access
- **Approval:** Data Owner

**INTERNAL Data Access:**
- **Frequency:** Annual
- **Scope:** Sample-based review (20% of users)
- **Approval:** Manager

**Automated Access Review:**
```hcl
# EventBridge rule for monthly access review reminder
resource "aws_cloudwatch_event_rule" "monthly_access_review" {
  name                = "monthly-access-review-reminder"
  description         = "Monthly reminder for RESTRICTED data access review"
  schedule_expression = "cron(0 9 1 * ? *)"  # 9 AM on 1st of each month
}

resource "aws_cloudwatch_event_target" "access_review_notification" {
  rule      = aws_cloudwatch_event_rule.monthly_access_review.name
  target_id = "AccessReviewSNS"
  arn       = aws_sns_topic.access_review_reminders.arn

  input = jsonencode({
    subject = "REQUIRED: Monthly RESTRICTED Data Access Review"
    message = "Please review access to RESTRICTED data resources. Generate report from IAM Access Analyzer and approve/revoke access accordingly."
  })
}
```

### 8.2 Unused Access Detection

**IAM Access Analyzer Integration:**
- Unused access detection (90 days of inactivity)
- External access findings (public resources)
- Unused permissions identification
- Automated alerts for unused access

**Implementation:**
```hcl
resource "aws_accessanalyzer_analyzer" "bedrock_access" {
  analyzer_name = "bedrock-access-analyzer"
  type          = "ACCOUNT"

  tags = {
    Environment = var.environment
    Compliance  = "AccessControl"
  }
}

# CloudWatch alarm for external access findings
resource "aws_cloudwatch_metric_alarm" "external_access_finding" {
  alarm_name          = "iam-external-access-detected"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ExternalAccessFindingCount"
  namespace           = "AWS/AccessAnalyzer"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Alert when external access to resources detected"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  dimensions = {
    AnalyzerArn = aws_accessanalyzer_analyzer.bedrock_access.arn
  }
}
```

### 8.3 Privileged Access Monitoring

**Real-time monitoring of privileged actions:**
- Root account usage
- IAM policy changes
- KMS key deletion
- S3 bucket policy changes
- Security group modifications
- Bedrock agent/knowledge base deletion

**Implementation:**
```hcl
# CloudWatch log metric filter for root account usage
resource "aws_cloudwatch_log_metric_filter" "root_account_usage" {
  name           = "root-account-usage"
  log_group_name = "/aws/cloudtrail/management"
  pattern        = "{ $.userIdentity.type = \"Root\" && $.userIdentity.invokedBy NOT EXISTS && $.eventType != \"AwsServiceEvent\" }"

  metric_transformation {
    name      = "RootAccountUsageCount"
    namespace = "Security/AccessControl"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "root_account_usage_alarm" {
  alarm_name          = "root-account-usage-detected"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "RootAccountUsageCount"
  namespace           = "Security/AccessControl"
  period              = "60"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "CRITICAL: Root account has been used"
  alarm_actions       = [aws_sns_topic.critical_security_alerts.arn]
}
```

---

## 9. Compliance and Enforcement

### 9.1 Automated Enforcement

**AWS Config Rules:**
- `iam-user-mfa-enabled`: Ensure all IAM users have MFA
- `iam-root-access-key-check`: No access keys for root account
- `iam-password-policy`: Password policy compliance
- `iam-user-no-policies-check`: No inline policies on users
- `access-keys-rotated`: Access keys rotated within 90 days

**Implementation:**
```hcl
resource "aws_config_config_rule" "iam_user_mfa_enabled" {
  name = "iam-user-mfa-enabled"

  source {
    owner             = "AWS"
    source_identifier = "IAM_USER_MFA_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_config_rule" "root_access_key_check" {
  name = "iam-root-access-key-check"

  source {
    owner             = "AWS"
    source_identifier = "IAM_ROOT_ACCESS_KEY_CHECK"
  }
}

resource "aws_config_config_rule" "iam_password_policy" {
  name = "iam-password-policy"

  source {
    owner             = "AWS"
    source_identifier = "IAM_PASSWORD_POLICY"
  }

  input_parameters = jsonencode({
    RequireUppercaseCharacters = "true"
    RequireLowercaseCharacters = "true"
    RequireSymbols             = "true"
    RequireNumbers             = "true"
    MinimumPasswordLength      = "14"
    PasswordReusePrevention    = "24"
    MaxPasswordAge             = "90"
  })
}
```

### 9.2 Continuous Monitoring

**Security Hub Integration:**
- CIS AWS Foundations Benchmark
- AWS Foundational Security Best Practices
- PCI DSS standard
- Custom access control standards

**Audit Trail:**
- CloudTrail: All API calls logged
- VPC Flow Logs: Network traffic logged
- S3 access logs: Object-level access logged
- CloudWatch Logs: Application logs
- Bedrock invocation logs: AI agent activity logged

---

## 10. Policy Violations and Enforcement

**Violations:**
- Unauthorized access attempts
- Sharing credentials
- Accessing data without business need
- Bypassing access controls
- Excessive privilege escalation

**Consequences:**
- First violation: Warning and remedial training
- Second violation: Temporary access suspension (30 days)
- Third violation: Permanent access revocation and termination
- Criminal activity: Law enforcement referral

**Enforcement:**
- Automated detection (AWS Config, Security Hub, GuardDuty)
- Security team investigation
- Manager notification
- HR disciplinary process
- Legal review (if applicable)

---

## 11. Related Policies

- Data Classification Policy
- Encryption Policy
- Incident Response Policy
- Acceptable Use Policy
- Third-Party Risk Management Policy

---

## Document Control

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-11-17 | CISO | Initial policy creation |

**Next Review Date:** 2026-11-17
