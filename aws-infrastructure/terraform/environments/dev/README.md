# AWS Development Environment

Minimal, cost-optimized AWS environment for testing and feature development.

## 💰 Estimated Monthly Cost: **$50-80**

### Cost Breakdown (Monthly)

| Service               | Configuration            | Est. Cost       |
| --------------------- | ------------------------ | --------------- |
| **EKS Control Plane** | 1 cluster                | $72             |
| **EKS Nodes**         | 1x t3a.medium Spot       | $8              |
| **RDS PostgreSQL**    | db.t4g.micro Single-AZ   | $12             |
| **ElastiCache**       | cache.t4g.micro (1 node) | $11             |
| **DynamoDB**          | On-Demand (light usage)  | $5              |
| **S3**                | 10GB storage + requests  | $2              |
| **NAT Gateway**       | Single gateway           | $32             |
| **Data Transfer**     | 50GB/month               | $5              |
| **CloudWatch Logs**   | Minimal retention        | $3              |
| **Total**             |                          | **~$150/month** |

**With Spot instances and VPC endpoints**: **~$50-80/month**

## 🎯 Cost Optimizations Applied

### Infrastructure

- ✅ **Single NAT Gateway** (vs 3 in prod) - Save ~$64/month
- ✅ **VPC Endpoints** enabled - Reduce NAT Gateway data transfer costs
- ✅ **Single Availability Zone** - No cross-AZ data transfer charges
- ✅ **No VPC Flow Logs** - Save ~$10/month

### Compute (EKS)

- ✅ **Spot Instances** (70% cheaper than On-Demand)
- ✅ **t3a.medium** (AMD instances, 10% cheaper than t3)
- ✅ **1 node minimum** (vs 3 in prod)
- ✅ **No AI node group** - Save ~$950/month
- ✅ **Minimal logging** (api, audit only) - Reduce CloudWatch costs

### Database (RDS)

- ✅ **db.t4g.micro** (Graviton, smallest instance)
- ✅ **Single-AZ** (vs Multi-AZ in prod) - 50% cost reduction
- ✅ **20GB storage** (vs 200GB in prod)
- ✅ **1-day backup retention** (vs 30 days)
- ✅ **No Performance Insights** - Save $7/month
- ✅ **No Enhanced Monitoring** - Save $1/month

### Cache (ElastiCache)

- ✅ **cache.t4g.micro** (Graviton, smallest)
- ✅ **Single node** (vs 3 in prod) - Save ~$540/month
- ✅ **No snapshots** - Save storage costs

### Storage (S3)

- ✅ **No versioning** - Reduce storage costs
- ✅ **7-day lifecycle** on uploads - Auto-cleanup
- ✅ **No Intelligent-Tiering** - Avoid overhead for small datasets

### NoSQL (DynamoDB)

- ✅ **On-Demand billing** - Pay per request (perfect for dev)
- ✅ **No Point-in-Time Recovery** - Save 20% of table cost
- ✅ **No Streams** - Save unless needed

### Other

- ✅ **Shared KMS key** - 1 key vs 7 in prod
- ✅ **3-day log retention** - Reduce CloudWatch storage
- ✅ **$200 budget alert** - Catch unexpected costs early

## 📋 Prerequisites

1. AWS Account with appropriate permissions
2. Terraform >= 1.11.0
3. AWS CLI configured
4. S3 backend set up (run once):
   ```bash
   aws s3api create-bucket --bucket servicenow-ai-terraform-state --region us-east-1
   aws dynamodb create-table --table-name terraform-state-lock \
     --attribute-definitions AttributeName=LockID,AttributeType=S \
     --key-schema AttributeName=LockID,KeyType=HASH \
     --billing-mode PAY_PER_REQUEST --region us-east-1
   ```

## 🚀 Quick Start

### 1. Configure Variables

```bash
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 2. Deploy

```bash
terraform init
terraform plan
terraform apply
```

Deployment takes ~15-20 minutes.

### 3. Configure kubectl

```bash
aws eks update-kubeconfig --region us-east-1 --name dev-ai-agent-eks
kubectl get nodes
```

### 4. Access Resources

```bash
# Get RDS endpoint
terraform output -raw rds_endpoint

# Get Redis endpoint
terraform output -raw redis_endpoint

# Get S3 buckets
terraform output s3_bucket_arns
```

## 🔧 Development Workflow

### Testing Features

```bash
# Deploy your changes
kubectl apply -f your-manifests.yaml

# Check logs
kubectl logs -f deployment/your-app

# Test endpoints
curl https://your-alb-url/api/test
```

### Cleanup When Not in Use

**IMPORTANT**: To minimize costs, destroy the environment when not actively
developing:

```bash
terraform destroy
```

This will remove all resources and stop billing (except S3 state bucket).

### Re-deploy for Next Session

```bash
terraform apply
```

Resources will be recreated from your Terraform state.

## 🛡️ Security Notes

### Dev-Specific Relaxations

- ✅ Public EKS API endpoint (restrict via `eks_public_access_cidrs`)
- ✅ Deletion protection disabled (easy teardown)
- ✅ Skip final RDS snapshot (faster deletion)
- ⚠️ Single NAT Gateway (single point of failure - OK for dev)

### Still Secure

- ✅ All data encrypted at rest (KMS)
- ✅ All data encrypted in transit (TLS)
- ✅ Secrets in AWS Secrets Manager
- ✅ Security groups with least privilege
- ✅ WAF enabled
- ✅ Private subnets for workloads

## 📊 Monitoring

### CloudWatch Dashboards

- EKS cluster metrics
- RDS performance
- DynamoDB capacity

### Budget Alerts

- 80% threshold: Warning email
- 100% threshold: Critical email

### Access Logs

```bash
# View EKS API logs
aws logs tail /aws/eks/dev-ai-agent-eks/cluster --follow

# View application logs
aws logs tail /aws/eks/dev-ai-agent-eks/application --follow
```

## 🔄 Scaling Up for Load Testing

If you need to test with more resources temporarily:

```terraform
# In terraform.tfvars, increase node count:
general_node_group = {
  min_size     = 2
  max_size     = 5
  desired_size = 3
}
```

Then `terraform apply`. **Remember to scale back down** after testing.

## 🆚 Dev vs Prod Differences

| Feature                 | Dev                     | Prod                            |
| ----------------------- | ----------------------- | ------------------------------- |
| **Monthly Cost**        | ~$50-80                 | ~$3,112                         |
| **EKS Nodes**           | 1x t3a.medium Spot      | 3x t3.xlarge + 2x r6i.2xlarge   |
| **RDS**                 | db.t4g.micro, Single-AZ | db.r6i.xlarge, Multi-AZ         |
| **Redis**               | 1x cache.t4g.micro      | 3x cache.r7g.xlarge             |
| **NAT Gateway**         | 1 (Single)              | 3 (HA)                          |
| **Backups**             | 1 day                   | 30 days                         |
| **Monitoring**          | Basic                   | Enhanced + Performance Insights |
| **High Availability**   | No                      | Yes (Multi-AZ)                  |
| **Deletion Protection** | No                      | Yes                             |

## 🐛 Troubleshooting

### Spot Instance Interruptions

Spot instances can be reclaimed. If a node disappears:

```bash
# Check node status
kubectl get nodes

# If needed, manually adjust desired capacity
aws eks update-nodegroup-config --cluster-name dev-ai-agent-eks \
  --nodegroup-name dev-ai-agent-eks-general \
  --scaling-config desiredSize=2
```

### RDS Connection Issues

```bash
# Test from EKS pod
kubectl run -it --rm debug --image=postgres:16 --restart=Never -- \
  psql -h $(terraform output -raw rds_endpoint | cut -d: -f1) -U postgres
```

### Cost Spikes

Check your budget alerts and review:

```bash
aws ce get-cost-and-usage --time-period Start=2025-01-01,End=2025-01-31 \
  --granularity MONTHLY --metrics BlendedCost
```

## 📝 Best Practices

1. **Destroy when not in use** - Save ~90% of costs
2. **Use Spot instances** - Already configured
3. **Monitor your budget** - Alerts set at $160 (80%)
4. **Restrict access** - Set `eks_public_access_cidrs` to your IP
5. **Use separate AWS account** - Isolate dev from prod
6. **Tag everything** - Already done with common_tags
7. **Review costs weekly** - Check AWS Cost Explorer

## 🔗 Related Documentation

- [Production Environment](../prod/README.md)
- [GCP to AWS Mapping](../../docs/GCP_TO_AWS_MAPPING.md)
- [Main README](../../README.md)

## 📧 Support

For issues:

1. Check CloudWatch Logs
2. Review AWS Cost Explorer for unexpected charges
3. Verify Security Group rules
4. Check EKS cluster status

---

**Remember**: This is a dev environment. Don't store production data here!
