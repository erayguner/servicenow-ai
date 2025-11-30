# Bedrock Agents Security Modules

Comprehensive security Terraform modules for Amazon Bedrock agents
infrastructure with enterprise-grade security features.

## Overview

This directory contains 6 security modules designed to provide defense-in-depth
protection for Bedrock agent deployments:

1. **bedrock-security-iam** - Identity and Access Management
2. **bedrock-security-kms** - Key Management Service encryption
3. **bedrock-security-guardduty** - Threat detection
4. **bedrock-security-hub** - Security posture management
5. **bedrock-security-waf** - Web Application Firewall
6. **bedrock-security-secrets** - Secrets management with rotation

## Module Structure

Each module follows Terraform best practices with the following files:

- `main.tf` - Primary resource definitions
- `variables.tf` - Input variables with validation
- `outputs.tf` - Output values for module composition
- `versions.tf` - Terraform and provider version constraints

## Security Modules

### 1. bedrock-security-iam (16K main.tf)

**Purpose**: Least-privilege IAM policies and roles for Bedrock agents

**Key Features**:

- Bedrock agent execution roles with least-privilege access
- Lambda execution roles for action groups
- Step Functions orchestration roles
- Cross-account access roles with external ID
- Permission boundaries for privilege escalation prevention
- Attribute-Based Access Control (ABAC)
- CloudWatch alarms for unauthorized API calls and IAM policy changes

**Resources Created**:

- IAM roles for Bedrock agents, Lambda, Step Functions
- Permission boundary policies
- CloudWatch metric filters and alarms
- IAM policies with service-specific access

**Use Cases**:

- Secure Bedrock agent execution
- Multi-account deployments
- Compliance-driven access control

---

### 2. bedrock-security-kms (13K main.tf)

**Purpose**: KMS encryption for all Bedrock agent data

**Key Features**:

- Separate KMS keys for different data types:
  - Bedrock data encryption
  - Secrets Manager encryption
  - S3 bucket encryption
- Automatic key rotation (enabled by default)
- Multi-region keys for disaster recovery
- Key aliases for easy reference
- Service-specific key policies
- KMS grants with encryption context
- CloudWatch alarms for key usage and API errors

**Resources Created**:

- 3 KMS keys with rotation
- KMS key aliases
- KMS grants for role-based access
- CloudWatch alarms for key monitoring
- Metric filters for key deletion attempts

**Use Cases**:

- Data encryption at rest
- Compliance requirements (HIPAA, PCI-DSS)
- Multi-region data replication

---

### 3. bedrock-security-guardduty (13K main.tf)

**Purpose**: Intelligent threat detection for Bedrock infrastructure

**Key Features**:

- S3 data events protection
- EKS/Kubernetes audit logs monitoring
- Lambda network logs analysis
- RDS login events tracking
- Malware protection for EBS volumes
- Cryptocurrency mining detection
- Custom threat intelligence sets
- Trusted IP sets (whitelisting)
- EventBridge integration for automated responses
- Lambda function for findings processing

**Resources Created**:

- GuardDuty detector with all protection features
- GuardDuty filters for high-severity findings
- EventBridge rules for finding notifications
- CloudWatch alarms for threat metrics
- Optional Lambda function for finding enrichment
- IP sets for custom filtering

**Use Cases**:

- Real-time threat detection
- Automated incident response
- Security operations center (SOC) integration

---

### 4. bedrock-security-hub (13K main.tf)

**Purpose**: Centralized security posture management and compliance

**Key Features**:

- Security standards subscriptions:
  - AWS Foundational Security Best Practices
  - CIS AWS Foundations Benchmark v1.2.0
  - PCI-DSS v3.2.1
  - NIST 800-53 Rev 5
- Custom security insights:
  - Critical findings aggregation
  - Failed compliance checks
  - Bedrock-specific findings
  - IAM security issues
- Product integrations:
  - GuardDuty
  - AWS Config
  - AWS Inspector
  - IAM Access Analyzer
- Automated remediation Lambda (optional)
- EventBridge rules for finding notifications

**Resources Created**:

- Security Hub account with standards
- 4+ custom security insights
- EventBridge rules for findings
- CloudWatch alarms for critical findings
- Optional auto-remediation Lambda
- Product subscriptions

**Use Cases**:

- Compliance monitoring (SOC2, HIPAA, PCI-DSS)
- Security posture assessment
- Automated compliance reporting
- Multi-account security aggregation

---

### 5. bedrock-security-waf (13K main.tf)

**Purpose**: Web Application Firewall protection for API Gateway

**Key Features**:

- Rate limiting per IP address
- AWS Managed Rules:
  - Core Rule Set
  - SQL injection protection
  - Known bad inputs blocking
  - Amazon IP reputation list
  - Anonymous IP list (VPN/Tor blocking)
- Geo-blocking by country code
- IP whitelisting and blacklisting
- Custom header validation (API key)
- WAF logging to CloudWatch
- CloudWatch alarms for blocked requests
- EventBridge integration

**Resources Created**:

- WAF Web ACL with 10 rule groups
- IP sets for whitelist/blacklist
- WAF association with API Gateway
- CloudWatch log group for WAF logs
- CloudWatch alarms for security events
- EventBridge rules for blocked requests

**Use Cases**:

- API Gateway protection
- DDoS mitigation
- Application-layer attack prevention
- Geographic access control

---

### 6. bedrock-security-secrets (14K main.tf)

**Purpose**: Secrets management with automatic rotation

**Key Features**:

- Secrets storage for:
  - Bedrock API keys
  - Database credentials
  - Third-party API keys
- Automatic secrets rotation (configurable interval)
- Cross-region replication for disaster recovery
- KMS encryption for all secrets
- Lambda function for custom rotation logic
- VPC support for Lambda rotation function
- Resource policies for IAM access control
- CloudWatch alarms for access patterns
- EventBridge notifications for rotation events

**Resources Created**:

- Secrets Manager secrets with versions
- Lambda function for rotation
- IAM role for Lambda execution
- Secrets rotation schedules
- CloudWatch metric filters and alarms
- EventBridge rules for rotation events
- Secret replicas in multiple regions

**Use Cases**:

- API key management
- Database credential rotation
- Zero-trust secret access
- Disaster recovery secret replication

---

## Common Features Across All Modules

### Security

- KMS encryption for all data at rest
- Least-privilege IAM policies
- CloudWatch logging for all activities
- Resource tagging for compliance tracking
- SNS notifications for security events

### Monitoring

- CloudWatch metric filters
- CloudWatch alarms with SNS integration
- EventBridge rules for automated responses
- Comprehensive logging to CloudWatch Logs

### Compliance

- Tags for SOC2, HIPAA, PCI-DSS compliance
- Audit logging via CloudTrail integration
- Metric filters for security events
- Automated compliance checking (Security Hub)

### High Availability

- Multi-region support (KMS, Secrets Manager)
- Cross-region replication (Secrets Manager)
- Automatic failover capabilities
- Regional redundancy

## Usage Example

```hcl
# Example: Complete security stack for Bedrock agents

module "security_iam" {
  source = "./modules/security/bedrock-security-iam"

  project_name = "my-bedrock-project"
  environment  = "prod"
  aws_region   = "us-east-1"

  enable_permission_boundary = true
  enable_step_functions      = true

  cloudtrail_log_group_name = module.cloudtrail.log_group_name
  sns_topic_arn            = module.notifications.security_topic_arn

  knowledge_base_arns = [module.bedrock.knowledge_base_arn]
  kms_key_arns       = [module.security_kms.bedrock_data_key_arn]
}

module "security_kms" {
  source = "./modules/security/bedrock-security-kms"

  project_name = "my-bedrock-project"
  environment  = "prod"
  aws_region   = "us-east-1"

  enable_key_rotation  = true
  enable_multi_region  = true

  iam_role_arns = [
    module.security_iam.bedrock_agent_execution_role_arn,
    module.security_iam.lambda_execution_role_arn
  ]

  key_admin_arns = [
    "arn:aws:iam::123456789012:user/security-admin"
  ]

  sns_topic_arn             = module.notifications.security_topic_arn
  cloudtrail_log_group_name = module.cloudtrail.log_group_name
}

module "security_guardduty" {
  source = "./modules/security/bedrock-security-guardduty"

  project_name = "my-bedrock-project"
  environment  = "prod"

  enable_s3_protection      = true
  enable_eks_protection     = true
  enable_lambda_protection  = true
  enable_rds_protection     = true
  enable_malware_protection = true

  enable_crypto_mining_detection = true

  sns_topic_arn = module.notifications.security_topic_arn
}

module "security_hub" {
  source = "./modules/security/bedrock-security-hub"

  project_name = "my-bedrock-project"
  environment  = "prod"

  enable_aws_foundational_standard = true
  enable_cis_aws_foundations      = true
  enable_pci_dss                  = true

  enable_guardduty_integration = true
  enable_config_integration    = true
  enable_inspector_integration = true

  enable_auto_remediation = true
  remediation_dry_run     = false

  sns_topic_arn = module.notifications.security_topic_arn
}

module "security_waf" {
  source = "./modules/security/bedrock-security-waf"

  project_name = "my-bedrock-project"
  environment  = "prod"

  waf_scope  = "REGIONAL"
  rate_limit = 2000

  enable_anonymous_ip_list = true
  blocked_countries        = ["CN", "RU", "KP"]

  api_gateway_arn = module.api_gateway.arn
  kms_key_arn     = module.security_kms.bedrock_data_key_arn
  sns_topic_arn   = module.notifications.security_topic_arn
}

module "security_secrets" {
  source = "./modules/security/bedrock-security-secrets"

  project_name = "my-bedrock-project"
  environment  = "prod"

  kms_key_id  = module.security_kms.secrets_key_id
  kms_key_arn = module.security_kms.secrets_key_arn

  enable_rotation = true
  rotation_days   = 30

  enable_cross_region_replication = true
  replica_regions                = ["us-west-2"]
  replica_kms_key_ids = {
    "us-west-2" = "arn:aws:kms:us-west-2:123456789012:key/..."
  }

  bedrock_api_keys = {
    primary   = var.bedrock_api_key_primary
    secondary = var.bedrock_api_key_secondary
  }

  enable_database_secrets = true
  database_username       = "bedrock_user"
  database_password       = var.db_password
  database_host           = module.database.endpoint
  database_port           = 5432
  database_name           = "bedrock_db"

  iam_role_arns = [
    module.security_iam.lambda_execution_role_arn
  ]

  sns_topic_arn             = module.notifications.security_topic_arn
  cloudtrail_log_group_name = module.cloudtrail.log_group_name
}
```

## Security Best Practices

### 1. IAM Best Practices

- Always use permission boundaries in production
- Enable ABAC for fine-grained access control
- Regularly rotate access keys
- Use service roles instead of user credentials
- Monitor unauthorized API calls

### 2. Encryption Best Practices

- Enable automatic KMS key rotation
- Use separate keys for different data types
- Enable multi-region keys for DR
- Monitor key usage with CloudWatch alarms
- Use encryption contexts in KMS grants

### 3. Monitoring Best Practices

- Enable all GuardDuty protection features
- Set up EventBridge rules for automated responses
- Configure SNS topics for security team alerts
- Review Security Hub findings regularly
- Enable WAF logging for forensics

### 4. Secrets Management Best Practices

- Rotate secrets automatically every 30-90 days
- Use cross-region replication for DR
- Never hardcode secrets in code
- Use IAM policies to restrict secret access
- Enable deletion protection (recovery window)

### 5. Compliance Best Practices

- Enable all relevant Security Hub standards
- Tag all resources with compliance identifiers
- Set up automated remediation where possible
- Regular security audits with Security Hub
- Document security controls for auditors

## CloudWatch Alarms

All modules include comprehensive CloudWatch alarms:

### IAM Module

- Unauthorized API calls
- IAM policy changes

### KMS Module

- KMS key disabled
- KMS API errors
- KMS key deletion attempts

### GuardDuty Module

- High findings count
- High severity findings
- SQL injection attempts

### Security Hub Module

- Critical findings
- Failed compliance checks

### WAF Module

- Blocked requests threshold
- Rate limit exceeded
- SQL injection attempts

### Secrets Module

- High secrets access rate
- Rotation failures

## SNS Integration

All modules support SNS topic ARN for notifications:

- Security events
- Compliance violations
- Rotation events
- Alarm triggers

Configure a single SNS topic and subscribe security team members, SIEM systems,
or incident response tools.

## Dependencies

### Required AWS Services

- AWS IAM
- AWS KMS
- AWS Secrets Manager
- Amazon GuardDuty
- AWS Security Hub
- AWS WAF v2
- Amazon CloudWatch
- Amazon EventBridge
- AWS CloudTrail (for metric filters)

### Terraform Requirements

- Terraform >= 1.11.0
- AWS Provider >= 5.80.0

## Cost Considerations

### KMS

- $1/month per CMK
- $0.03 per 10,000 API requests

### GuardDuty

- Varies by data volume analyzed
- ~$4.50 per million CloudTrail events
- ~$1.40 per GB of VPC flow logs

### Security Hub

- $0.0010 per finding ingested
- $0.0010 per compliance check

### WAF

- $5/month per Web ACL
- $1/month per rule
- $0.60 per million requests

### Secrets Manager

- $0.40 per secret per month
- $0.05 per 10,000 API calls

## Support and Contributions

For issues, questions, or contributions:

1. Check existing documentation
2. Review CloudWatch logs for errors
3. Verify IAM permissions
4. Check resource quotas

## License

These modules are part of the Bedrock Agents Infrastructure project.

## Version

Module Version: 1.0.0 Last Updated: 2025-11-17

---

**Note**: Always review and test security configurations in a non-production
environment before deploying to production. Security requirements vary by
organization and compliance framework.
