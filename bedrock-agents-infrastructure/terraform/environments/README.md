# Bedrock Agents Infrastructure - Environment Configurations

This directory contains environment-specific Terraform configurations for
deploying AWS Bedrock agents across development, staging, and production
environments.

## Directory Structure

```
environments/
├── dev/                    # Development environment
│   ├── main.tf            # Main configuration
│   ├── variables.tf       # Environment variables
│   ├── outputs.tf         # Output values
│   ├── providers.tf       # AWS provider configuration
│   └── terraform.tfvars.example  # Example variable values
├── staging/               # Staging environment
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf
│   └── terraform.tfvars.example
└── prod/                  # Production environment
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    ├── providers.tf
    └── terraform.tfvars.example
```

## Environment Comparison

| Feature             | Dev                           | Staging                      | Production                      |
| ------------------- | ----------------------------- | ---------------------------- | ------------------------------- |
| **Agent Instances** | 1                             | 3                            | 5-20 (auto-scaling)             |
| **Pricing Model**   | On-demand                     | On-demand                    | Provisioned throughput          |
| **Knowledge Base**  | Basic (OpenSearch Serverless) | Full (OpenSearch Serverless) | Enterprise (Provisioned)        |
| **Action Groups**   | Limited                       | All                          | All + Security                  |
| **Auto-scaling**    | No                            | No                           | Yes                             |
| **Multi-region**    | No                            | No                           | Yes (3 regions)                 |
| **Monitoring**      | Basic CloudWatch              | Enhanced + X-Ray             | Full observability + Synthetics |
| **Backup**          | Disabled                      | 7 days                       | 30 days + PITR                  |
| **Log Retention**   | 7 days                        | 30 days                      | 90 days                         |
| **Cost Estimate**   | $50-100/month                 | $300-500/month               | $2,500-4,000/month              |

## Prerequisites

### 1. AWS Account Setup

- AWS account(s) configured for each environment
- IAM permissions for Bedrock, S3, Lambda, CloudWatch, OpenSearch
- KMS keys created for encryption
- S3 buckets for data sources

### 2. Terraform Setup

```bash
# Install Terraform >= 1.11.0
terraform version

# Configure AWS CLI
aws configure
```

### 3. Backend Resources

Each environment requires:

- S3 bucket for Terraform state
- DynamoDB table for state locking
- KMS key for state encryption

Create backend resources:

```bash
# Dev environment
aws s3 mb s3://servicenow-ai-terraform-state-dev --region us-east-1
aws dynamodb create-table \
  --table-name servicenow-ai-terraform-locks-dev \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1

# Repeat for staging and prod
```

## Deployment Guide

### Development Environment

**Purpose**: Individual developer testing, experimentation, rapid iteration

**Steps**:

1. Navigate to dev environment:

```bash
cd bedrock-agents-infrastructure/terraform/environments/dev
```

2. Copy and configure variables:

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

3. Initialize Terraform:

```bash
terraform init \
  -backend-config="bucket=servicenow-ai-terraform-state-dev"
```

4. Plan and apply:

```bash
terraform plan -var-file="terraform.tfvars" -out=dev.plan
terraform apply dev.plan
```

5. Verify deployment:

```bash
terraform output
```

**Key Features**:

- Single agent instance
- Auto-shutdown outside business hours (cost savings)
- Minimal monitoring
- On-demand pricing
- 7-day log retention

**Estimated Cost**: $50-100/month

### Staging Environment

**Purpose**: QA testing, integration testing, pre-production validation

**Steps**:

1. Navigate to staging environment:

```bash
cd bedrock-agents-infrastructure/terraform/environments/staging
```

2. Copy and configure variables:

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

3. Initialize Terraform:

```bash
terraform init \
  -backend-config="bucket=servicenow-ai-terraform-state-staging"
```

4. Plan and apply:

```bash
terraform plan -var-file="terraform.tfvars" -out=staging.plan
terraform apply staging.plan
```

5. Run validation tests:

```bash
# Test agent invocation
aws bedrock-agent-runtime invoke-agent \
  --agent-id $(terraform output -raw agent_id) \
  --agent-alias-id $(terraform output -raw agent_alias_id) \
  --session-id test-$(date +%s) \
  --input-text "Test query" \
  --region us-east-1
```

**Key Features**:

- 3 agent instances
- Full action groups enabled
- Enhanced monitoring with X-Ray
- Load testing capabilities
- 30-day log retention

**Estimated Cost**: $300-500/month

### Production Environment

**Purpose**: Live production workloads, customer-facing services

**Steps**:

1. Navigate to production environment:

```bash
cd bedrock-agents-infrastructure/terraform/environments/prod
```

2. Copy and configure variables:

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with PRODUCTION values
# NEVER commit terraform.tfvars to git!
```

3. Initialize Terraform:

```bash
terraform init \
  -backend-config="bucket=servicenow-ai-terraform-state-prod"
```

4. Create workspace (optional, for blue/green):

```bash
terraform workspace new prod
terraform workspace select prod
```

5. Plan changes (review carefully):

```bash
terraform plan -var-file="terraform.tfvars" -out=prod.plan
```

6. Apply changes (requires approval):

```bash
terraform apply prod.plan
```

7. Verify deployment:

```bash
# Check health
terraform output global_endpoint

# Monitor dashboards
terraform output operational_dashboards
```

**Key Features**:

- 5-20 auto-scaling agent instances
- Multi-region deployment (3 regions)
- Provisioned throughput
- Full observability suite
- Synthetic monitoring
- WAF + Shield Advanced
- 90-day log retention
- 30-day backups with PITR

**Estimated Cost**: $2,500-4,000/month

## Configuration Variables

### Required Variables (All Environments)

```hcl
aws_region             = "eu-west-2"
owner_email            = "your-email@example.com"
data_source_bucket_arn = "arn:aws:s3:::your-data-bucket"
action_lambda_arn      = "arn:aws:lambda:us-east-1:123456789012:function:your-function"
alert_email            = "alerts@example.com"
```

### Environment-Specific Variables

**Dev**:

- `enable_debug_mode` - Enable verbose logging
- `auto_shutdown_enabled` - Auto-shutdown outside business hours
- `dev_team_members` - List of developer emails

**Staging**:

- `enable_load_testing` - Enable load testing tools
- `enable_chaos_testing` - Enable chaos engineering
- `qa_team_members` - List of QA team emails

**Prod**:

- `secondary_region` - Failover region
- `enable_pagerduty` - PagerDuty integration
- `kms_key_id` - KMS key for encryption
- `operational_contacts` - On-call contacts

## Cost Optimization

### Development

- ✅ Auto-shutdown outside business hours
- ✅ On-demand pricing (no provisioned throughput)
- ✅ Minimal logging (7 days)
- ✅ Single instance
- ✅ No X-Ray tracing
- ✅ OpenSearch Serverless

### Staging

- ⚠️ No auto-shutdown (testing availability)
- ✅ On-demand pricing
- ⚠️ Enhanced monitoring (30 days)
- ⚠️ 3 instances for load testing
- ⚠️ X-Ray enabled

### Production

- ❌ Always on (99.9% SLA)
- ❌ Provisioned throughput (better performance)
- ❌ Full monitoring (90 days)
- ❌ 5-20 instances (auto-scaling)
- ❌ Multi-region (HA)
- ❌ Enterprise features (WAF, Shield)

## Monitoring & Alerts

### Development

- CloudWatch Logs (7 days)
- Basic metrics
- No alerting (optional)

### Staging

- CloudWatch Logs (30 days)
- CloudWatch metrics
- X-Ray tracing
- Email alerts
- Load testing metrics

### Production

- CloudWatch Logs (90 days)
- CloudWatch metrics
- X-Ray tracing
- CloudWatch Synthetics
- PagerDuty integration
- Slack notifications
- Custom dashboards
- SLA monitoring

## Security & Compliance

### All Environments

- ✅ Encryption at rest (KMS)
- ✅ Encryption in transit (TLS)
- ✅ IAM least privilege
- ✅ VPC endpoints (optional)

### Production Only

- ✅ WAF enabled
- ✅ AWS Shield Advanced
- ✅ SOX/PCI/HIPAA compliance
- ✅ Audit logging
- ✅ MFA required
- ✅ Secrets rotation
- ✅ IP whitelisting

## Backup & Disaster Recovery

| Environment | Backup | Retention | PITR | Multi-region    |
| ----------- | ------ | --------- | ---- | --------------- |
| Dev         | No     | N/A       | No   | No              |
| Staging     | Yes    | 7 days    | No   | No              |
| Prod        | Yes    | 30 days   | Yes  | Yes (3 regions) |

## Troubleshooting

### Common Issues

**1. Backend initialization fails**

```bash
# Verify S3 bucket exists
aws s3 ls s3://servicenow-ai-terraform-state-dev

# Verify DynamoDB table exists
aws dynamodb describe-table --table-name servicenow-ai-terraform-locks-dev
```

**2. Permission denied errors**

```bash
# Check IAM permissions
aws sts get-caller-identity
aws iam get-user
```

**3. State lock errors**

```bash
# Force unlock (use with caution)
terraform force-unlock LOCK_ID
```

**4. Module not found**

```bash
# Re-initialize modules
terraform init -upgrade
```

### Validation Commands

```bash
# Validate configuration
terraform validate

# Format code
terraform fmt -recursive

# Check security
tfsec .

# Check costs
terraform plan -out=plan.tfplan
terraform show -json plan.tfplan | infracost breakdown --path -
```

## Maintenance

### Regular Tasks

**Weekly** (Dev/Staging):

- Review logs for errors
- Check cost reports
- Update dependencies

**Monthly** (All):

- Review IAM permissions
- Check compliance status
- Review backup integrity
- Update Terraform providers

**Quarterly** (Production):

- Disaster recovery drill
- Security audit
- Performance review
- Cost optimization review

### Upgrade Process

1. Test in dev environment
2. Validate in staging
3. Create change request for prod
4. Deploy during change window
5. Monitor and validate
6. Rollback if needed

## Resources

- [AWS Bedrock Documentation](https://docs.aws.amazon.com/bedrock/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Bedrock Agents Guide](https://docs.aws.amazon.com/bedrock/latest/userguide/agents.html)
- [OpenSearch Serverless](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/serverless.html)

## Support

- **Development Issues**: dev-team@example.com
- **Staging Issues**: qa-team@example.com
- **Production Issues**: prod-oncall@example.com (PagerDuty)
- **Security Issues**: security@example.com

## License

Copyright © 2025 ServiceNow AI Team. All rights reserved.
