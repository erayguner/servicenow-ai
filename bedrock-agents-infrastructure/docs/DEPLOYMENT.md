# Bedrock Agents Infrastructure - Deployment Guide

Complete step-by-step guide for deploying Bedrock Agents infrastructure on AWS.

## Prerequisites

### AWS Account Setup

1. **Create AWS Account** (if not existing)
2. **Configure IAM User** with programmatic access:
   - AmazonBedrockFullAccess
   - AmazonEC2FullAccess
   - AWSLambdaFullAccess
   - AmazonRDSFullAccess
   - AmazonDynamoDBFullAccess
   - AmazonS3FullAccess
   - SecretsManagerReadWrite
   - CloudWatchLogsFullAccess
   - AWSStepFunctionsFullAccess

3. **Enable Required AWS Services**:
   ```bash
   aws bedrock create-model-customization-job \
     --region us-east-1 \
     --enable-models all  # This enables Bedrock API
   ```

### Local Development Environment

```bash
# Verify Terraform
terraform -v  # >= 1.11.0

# Verify AWS CLI
aws --version  # >= 2.13.0

# Verify Python
python3 --version  # >= 3.9

# Verify Node.js
node --version  # >= 18.0.0
```

### Install Required Tools

```bash
# AWS CLI
pip install awscli --upgrade

# Terraform
brew install terraform  # macOS
# or download from https://www.terraform.io/downloads

# kubectl (for managing EKS if applicable)
brew install kubectl  # macOS

# AWS SAM (for local Lambda testing)
pip install aws-sam-cli

# Python dependencies
pip install -r requirements.txt
```

## Step 1: Clone Repository

```bash
git clone https://github.com/your-org/servicenow-ai.git
cd servicenow-ai/bedrock-agents-infrastructure
```

## Step 2: Configure AWS Credentials

### Option A: AWS CLI Configuration

```bash
aws configure

# Enter:
# AWS Access Key ID: [your access key]
# AWS Secret Access Key: [your secret key]
# Default region: us-east-1
# Default output format: json
```

### Option B: Environment Variables

```bash
export AWS_ACCESS_KEY_ID="your_access_key"
export AWS_SECRET_ACCESS_KEY="your_secret_key"
export AWS_DEFAULT_REGION="us-east-1"
```

### Option C: IAM Role (For EC2/Lambda)

Use instance profiles or Workload Identity for secure credential management.

## Step 3: Initialize Terraform Backend

Create S3 bucket for Terraform state (do this once per AWS account):

```bash
# Variables
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-east-1"
BUCKET_NAME="servicenow-ai-terraform-state-${ACCOUNT_ID}"

# Create S3 bucket
aws s3api create-bucket \
  --bucket "${BUCKET_NAME}" \
  --region "${REGION}"

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket "${BUCKET_NAME}" \
  --versioning-configuration Status=Enabled

# Enable server-side encryption
aws s3api put-bucket-encryption \
  --bucket "${BUCKET_NAME}" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block public access
aws s3api put-public-access-block \
  --bucket "${BUCKET_NAME}" \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

Create DynamoDB table for Terraform locking:

```bash
aws dynamodb create-table \
  --table-name servicenow-ai-terraform-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region "${REGION}"
```

Update `terraform/backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "servicenow-ai-terraform-state-ACCOUNT_ID"
    key            = "bedrock-agents/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "servicenow-ai-terraform-lock"
  }
}
```

## Step 4: Configure Environment Variables

Create environment-specific configurations:

```bash
# Copy example
cp terraform/environments/dev.tfvars.example terraform/environments/dev.tfvars

# Edit with your values
cat > terraform/environments/dev.tfvars << EOF
aws_region            = "us-east-1"
environment           = "dev"
project_name          = "servicenow-ai"
bedrock_model_id      = "anthropic.claude-3-sonnet-20240229-v1:0"
knowledge_base_name   = "servicenow-knowledge-base-dev"
lambda_timeout        = 60
lambda_memory         = 512
enable_xray_tracing   = true
tags = {
  Environment = "dev"
  ManagedBy   = "Terraform"
  Project     = "ServiceNow AI"
}
EOF
```

## Step 5: Initialize Terraform

```bash
cd terraform

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Format code
terraform fmt -recursive
```

## Step 6: Review Deployment Plan

```bash
# Generate execution plan
terraform plan -var-file="environments/dev.tfvars" -out=tfplan

# Review the plan carefully
cat tfplan  # for detailed view

# Save plan for later
terraform apply tfplan  # Use this to apply with exact plan
```

## Step 7: Deploy Infrastructure

### Development Environment

```bash
# Deploy with confirmed plan
terraform apply -var-file="environments/dev.tfvars" -auto-approve

# Or step-by-step
terraform apply -var-file="environments/dev.tfvars"
# Type 'yes' when prompted
```

### Production Environment

```bash
# ALWAYS review before production
terraform plan -var-file="environments/prod.tfvars" -out=tfplan_prod

# Have someone review the plan
# Then apply with plan
terraform apply tfplan_prod
```

Expected deployment time: **15-30 minutes**

## Step 8: Verify Deployment

```bash
# Get outputs
terraform output

# Export outputs for use
aws_account_id=$(terraform output -raw aws_account_id)
bedrock_agent_id=$(terraform output -raw bedrock_agent_id)
lambda_role_arn=$(terraform output -raw lambda_execution_role_arn)

echo "Agent ID: ${bedrock_agent_id}"
echo "Lambda Role: ${lambda_role_arn}"
```

### Test Bedrock Agent

```bash
# Invoke agent
aws bedrock-agent-runtime invoke-agent \
  --agent-id "${bedrock_agent_id}" \
  --agent-alias-id "AGENT_ALIAS_ID" \
  --session-id "test-session-$(date +%s)" \
  --input-text "Hello, test agent. Acknowledge that you received this message." \
  --region us-east-1 \
  response.json

# View response
cat response.json | jq '.'
```

## Step 9: Deploy Agent Code

```bash
# Create Python virtual environment
cd ../agents
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Deploy agents
python deploy.py \
  --environment dev \
  --agent-types core-agents,orchestration \
  --region us-east-1

# Verify deployment
python verify_agents.py --environment dev
```

## Step 10: Deploy Lambda Functions (Action Groups)

```bash
# Navigate to Lambda action groups
cd scripts

# Deploy action groups
python deploy_action_groups.py \
  --environment dev \
  --vpc-config "SubnetIds=subnet-xxx,SecurityGroupIds=sg-xxx"

# Test action groups
./test_action_groups.sh --environment dev
```

## Step 11: Configure Knowledge Base

```bash
# Upload documents to S3
aws s3 cp documents/ s3://servicenow-ai-knowledge-base-dev/ --recursive

# Ingest documents into knowledge base
python ../scripts/knowledge-base-loader.py \
  --knowledge-base-id "kb-xxx" \
  --s3-path "s3://servicenow-ai-knowledge-base-dev/" \
  --wait-for-completion

# Verify knowledge base
aws bedrock-agent list-knowledge-bases --region us-east-1
```

## Step 12: Set Up Monitoring

```bash
# Create CloudWatch dashboard
python ../scripts/monitoring/dashboard.py --environment dev

# Configure alarms
python ../scripts/monitoring/alerts.py \
  --environment dev \
  --sns-topic-arn "arn:aws:sns:region:account:bedrock-alerts"

# View logs
aws logs tail /aws/bedrock/agents/dev --follow
```

## Troubleshooting

### Common Issues

#### 1. Terraform Backend Lock

```bash
# If terraform is stuck:
aws dynamodb delete-item \
  --table-name servicenow-ai-terraform-lock \
  --key '{"LockID":{"S":"servicenow-ai/bedrock-agents/terraform.tfstate"}}'

# Clear and retry
rm -rf .terraform/
terraform init
```

#### 2. Lambda Execution Role Missing Permissions

```bash
# Check role
aws iam get-role --role-name bedrock-lambda-execution-role

# Attach policy
aws iam attach-role-policy \
  --role-name bedrock-lambda-execution-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole
```

#### 3. Bedrock Model Access Denied

```bash
# Verify model access
aws bedrock list-foundation-models --region us-east-1

# Grant access to model
aws bedrock grant-model-access \
  --account-id "$(aws sts get-caller-identity --query Account --output text)" \
  --model-id "anthropic.claude-3-sonnet-20240229-v1:0"
```

#### 4. Knowledge Base Indexing Failed

```bash
# Check status
aws bedrock-agent get-knowledge-base \
  --knowledge-base-id "kb-xxx"

# Retry ingestion
aws bedrock-agent start-ingestion-job \
  --knowledge-base-id "kb-xxx" \
  --data-source-id "ds-xxx"
```

#### 5. Network Connectivity Issues

```bash
# Test VPC connectivity
aws ec2 describe-security-groups \
  --filters "Name=group-id,Values=sg-xxx" \
  --query 'SecurityGroups[0].IpPermissions'

# Verify NAT Gateway
aws ec2 describe-nat-gateways \
  --filter "Name=state,Values=available"
```

## Rollback Procedures

### Full Infrastructure Rollback

```bash
cd terraform

# Plan destruction
terraform plan -destroy -var-file="environments/dev.tfvars"

# Destroy infrastructure
terraform destroy -var-file="environments/dev.tfvars"
```

### Selective Rollback

```bash
# Destroy specific resource
terraform destroy -target="aws_bedrock_agent.main" -var-file="environments/dev.tfvars"

# Or state removal
terraform state rm aws_bedrock_agent.main
```

### Database Backup & Restore

```bash
# Backup RDS
aws rds create-db-snapshot \
  --db-instance-identifier "servicenow-ai-db-dev" \
  --db-snapshot-identifier "servicenow-ai-db-backup-$(date +%s)"

# Restore from snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier "servicenow-ai-db-restored" \
  --db-snapshot-identifier "servicenow-ai-db-backup-xxx"
```

## Post-Deployment Configuration

### 1. Enable CloudTrail

```bash
aws cloudtrail create-trail \
  --name bedrock-agents-trail \
  --s3-bucket-name servicenow-ai-audit-logs \
  --is-multi-region-trail

aws cloudtrail start-logging --trail-name bedrock-agents-trail
```

### 2. Set Up Cost Alerts

```bash
aws budgets create-budget \
  --account-id "$(aws sts get-caller-identity --query Account --output text)" \
  --budget file://budget-config.json \
  --notifications-with-subscribers file://notifications.json
```

### 3. Configure Backup & Disaster Recovery

```bash
# Enable automatic backups
aws bedrock-agent update-knowledge-base \
  --knowledge-base-id "kb-xxx" \
  --backup-config "enabled=true,retention_days=30"
```

## Validation Checklist

- [ ] AWS credentials configured
- [ ] Terraform initialized and validated
- [ ] S3 backend and DynamoDB lock table created
- [ ] Environment variables configured
- [ ] Terraform plan reviewed and approved
- [ ] Infrastructure deployed successfully
- [ ] Bedrock agent created and callable
- [ ] Lambda execution role with correct permissions
- [ ] Knowledge base initialized and accessible
- [ ] Action groups deployed and tested
- [ ] CloudWatch monitoring configured
- [ ] CloudTrail logging enabled
- [ ] Cost alerts configured
- [ ] Backup and disaster recovery tested

## Next Steps

1. **Deploy Agents**: Follow [AGENTS.md](AGENTS.md)
2. **Configure Orchestration**: Follow [ORCHESTRATION.md](ORCHESTRATION.md)
3. **Test APIs**: Use examples in [API.md](API.md)
4. **Monitor Costs**: Track with [COST.md](COST.md)
5. **Implement Workflows**: Use patterns in [examples/](examples/)

## Support

For issues:

1. Check AWS CloudWatch Logs: `aws logs tail /aws/bedrock/agents/dev --follow`
2. Review Terraform state: `terraform show`
3. Verify IAM permissions: `aws iam simulate-principal-policy`
4. Check CloudTrail: `aws cloudtrail lookup-events --lookup-attributes AttributeKey=ResourceType,AttributeValue=Agent`

---

**Version**: 1.0.0
**Last Updated**: 2025-01-17
