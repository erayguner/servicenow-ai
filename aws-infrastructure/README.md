# ServiceNow AI - AWS Infrastructure

This directory contains the complete AWS infrastructure implementation, equivalent to the GCP services in the parent directory. It follows AWS 2025 best practices with modern services and security configurations.

## Overview

This infrastructure provides a production-ready AWS deployment with:
- **Amazon EKS** for container orchestration (equivalent to GKE)
- **Amazon RDS PostgreSQL** for relational database (equivalent to Cloud SQL)
- **Amazon DynamoDB** for NoSQL database (equivalent to Firestore)
- **Amazon S3** for object storage (equivalent to Cloud Storage)
- **Amazon ElastiCache Redis** for caching (equivalent to Memorystore)
- **Amazon SNS + SQS** for messaging (equivalent to Pub/Sub)
- **AWS KMS** for encryption key management
- **AWS Secrets Manager** for secret management
- **AWS WAF** for web application firewall (equivalent to Cloud Armor)
- **Amazon Bedrock** ready for AI/ML workloads (equivalent to Vertex AI)

## Directory Structure

```
aws-infrastructure/
├── terraform/
│   ├── modules/
│   │   ├── vpc/                 # VPC with public/private/database subnets
│   │   ├── eks/                 # EKS cluster with node groups
│   │   ├── rds/                 # RDS PostgreSQL with Multi-AZ
│   │   ├── dynamodb/            # DynamoDB tables
│   │   ├── s3/                  # S3 buckets with lifecycle policies
│   │   ├── elasticache/         # ElastiCache Redis cluster
│   │   ├── sns-sqs/             # SNS topics + SQS queues
│   │   ├── kms/                 # KMS keys
│   │   ├── secrets-manager/    # Secrets Manager
│   │   └── waf/                 # WAF rules
│   └── environments/
│       ├── dev/                 # Development environment
│       ├── staging/             # Staging environment
│       └── prod/                # Production environment
├── backend/
│   └── src/
│       └── config/
│           └── aws-config.ts    # AWS SDK configuration
├── k8s/                         # Kubernetes manifests for EKS
└── docs/
    ├── GCP_TO_AWS_MAPPING.md    # Comprehensive service mapping
    └── DEPLOYMENT_GUIDE.md      # Step-by-step deployment guide

```

## Environments

This infrastructure supports multiple environments with different configurations:

### 🚀 Production Environment
- **Purpose**: Customer-facing production workloads
- **Cost**: ~$3,112/month (with Reserved Instances: ~$2,000/month)
- **Features**: Multi-AZ HA, Enhanced monitoring, 30-day backups
- **Documentation**: [Production README](terraform/environments/prod/README.md)

### 💻 Development Environment
- **Purpose**: Feature development and testing
- **Cost**: ~$50-80/month (with Spot instances and optimizations)
- **Features**: Single-AZ, Spot instances, minimal redundancy
- **Documentation**: [Development README](terraform/environments/dev/README.md)

**💰 Cost Savings**: Dev environment is **97.4% cheaper** than production!

For detailed cost comparison, see [COST_COMPARISON.md](docs/COST_COMPARISON.md)

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **Terraform** >= 1.11.0
3. **AWS CLI** configured with credentials
4. **kubectl** for Kubernetes management
5. **Node.js** >= 20 (for backend)

## Quick Start

### 1. Set Up Terraform Backend

First, create the S3 bucket and DynamoDB table for Terraform state:

```bash
# Create S3 bucket for Terraform state
aws s3api create-bucket \
  --bucket servicenow-ai-terraform-state \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket servicenow-ai-terraform-state \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket servicenow-ai-terraform-state \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### 2. Choose Your Environment

**For Development** (recommended for testing):
```bash
cd terraform/environments/dev
```

**For Production**:
```bash
cd terraform/environments/prod
```

### 3. Configure Variables

Create a `terraform.tfvars` file in the environment directory:

```bash
# If in dev:
cd terraform/environments/dev
cat > terraform.tfvars <<EOF
region                  = "us-east-1"
eks_public_access_cidrs = ["YOUR_IP/32"]
db_master_password      = "CHANGE_ME_USE_SECRETS_MANAGER"
redis_auth_token        = "CHANGE_ME_STRONG_PASSWORD"
budget_alert_emails     = ["your-email@example.com"]
EOF
```

### 4. Deploy Infrastructure

```bash
cd terraform/environments/prod

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply
```

This will create all AWS resources. The process takes approximately 20-30 minutes.

### 5. Configure kubectl

After EKS cluster is created:

```bash
aws eks update-kubeconfig --region us-east-1 --name prod-ai-agent-eks
kubectl get nodes
```

### 6. Deploy Application

```bash
# Update backend configuration
cd ../../../backend
cp .env.example .env
# Edit .env with AWS resource outputs

# Install dependencies
npm install

# Build
npm run build

# Start application
npm start
```

## Architecture

### Network Architecture

- **VPC**: 10.0.0.0/16
  - **Public Subnets**: For load balancers and NAT gateways
  - **Private Subnets**: For EKS worker nodes
  - **Database Subnets**: For RDS and ElastiCache
  - **3 Availability Zones** for high availability

### Security

- **VPC Endpoints**: For S3, DynamoDB, ECR, Secrets Manager (reduces NAT Gateway costs)
- **Security Groups**: Least privilege access control
- **KMS Encryption**: All data encrypted at rest
- **TLS Encryption**: All data encrypted in transit
- **AWS Secrets Manager**: For sensitive credentials
- **IAM Roles**: Pod-level permissions via EKS Pod Identity

### High Availability

- **Multi-AZ RDS**: Automatic failover
- **Multi-node ElastiCache**: 3 nodes across AZs
- **EKS**: Nodes distributed across 3 AZs
- **S3**: Automatically replicated
- **DynamoDB**: Global tables ready

## Cost Optimization

### 2025 Best Practices Applied

1. **VPC Endpoints**: Avoid NAT Gateway data transfer costs
2. **S3 Intelligent-Tiering**: Automatic storage class optimization
3. **RDS Storage Autoscaling**: Grow storage as needed
4. **DynamoDB On-Demand**: Pay only for what you use
5. **EKS Spot Instances**: Up to 90% savings for non-critical workloads
6. **Graviton3 Instances**: 40% better price/performance (when available)

### Estimated Monthly Costs (Production)

| Service | Configuration | Estimated Cost |
|---------|--------------|----------------|
| EKS Control Plane | 1 cluster | $72 |
| EKS Nodes (General) | 3x t3.xlarge | $450 |
| EKS Nodes (AI) | 2x r6i.2xlarge | $950 |
| RDS PostgreSQL | db.r6i.xlarge Multi-AZ | $850 |
| ElastiCache Redis | 3x cache.r7g.large | $550 |
| DynamoDB | On-Demand | $100 |
| S3 | 500GB + requests | $50 |
| Data Transfer | 1TB/month | $90 |
| **Total** | | **~$3,112/month** |

*Costs can be reduced by 30-40% using Spot instances and Graviton3*

## Monitoring & Logging

- **CloudWatch Logs**: Centralized logging for all services
- **CloudWatch Metrics**: Service metrics and dashboards
- **AWS X-Ray**: Distributed tracing
- **EKS Control Plane Logs**: API, audit, authenticator, controller manager, scheduler
- **VPC Flow Logs**: Network traffic analysis

## Security Best Practices

1. ✅ All data encrypted at rest (KMS)
2. ✅ All data encrypted in transit (TLS 1.3)
3. ✅ Secrets managed via AWS Secrets Manager
4. ✅ IAM roles for service accounts (EKS Pod Identity)
5. ✅ Security Groups with least privilege
6. ✅ AWS WAF for application protection
7. ✅ Multi-AZ deployment for HA
8. ✅ Automated backups enabled
9. ✅ CloudTrail enabled for audit logging
10. ✅ Budget alerts configured

## Maintenance

### Backup & Recovery

- **RDS**: Automated daily backups, 30-day retention, point-in-time recovery
- **DynamoDB**: Point-in-time recovery enabled
- **S3**: Versioning enabled, lifecycle policies for archival

### Updates

- **EKS**: Managed control plane, plan upgrades quarterly
- **RDS**: Auto minor version upgrades enabled
- **Node Groups**: Blue/green deployments via Terraform

## Troubleshooting

### EKS Cluster Access Issues

```bash
# Verify AWS credentials
aws sts get-caller-identity

# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name prod-ai-agent-eks

# Check cluster status
aws eks describe-cluster --name prod-ai-agent-eks --region us-east-1
```

### RDS Connection Issues

```bash
# Test connectivity from EKS pod
kubectl run -it --rm debug --image=postgres:16 --restart=Never -- \
  psql -h <RDS_ENDPOINT> -U postgres -d agentdb
```

### Redis Connection Issues

```bash
# Test connectivity from EKS pod
kubectl run -it --rm debug --image=redis:7 --restart=Never -- \
  redis-cli -h <REDIS_ENDPOINT> -a <AUTH_TOKEN> --tls
```

## Migration from GCP

See [GCP_TO_AWS_MAPPING.md](docs/GCP_TO_AWS_MAPPING.md) for detailed service mapping and migration guide.

## Additional Resources

- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## Support

For issues or questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review AWS service health dashboard
3. Check CloudWatch Logs for errors

## License

Same as parent project license
