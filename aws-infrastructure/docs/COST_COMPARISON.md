# AWS Cost Comparison: Dev vs Prod

Detailed cost analysis for development and production environments.

## Monthly Cost Summary

| Environment | Estimated Cost | Use Case |
|------------|----------------|----------|
| **Development** | **$50-80** | Feature development, testing |
| **Production** | **$3,112** | Production workloads, HA |

**Savings: 97.4%** when using dev environment for non-production work.

## Detailed Cost Breakdown

### Development Environment (~$50-80/month)

#### Compute & Networking
| Service | Configuration | Monthly Cost |
|---------|--------------|--------------|
| EKS Control Plane | 1 cluster | $72.00 |
| EKS Worker Nodes | 1x t3a.medium Spot | $8.06 |
| NAT Gateway | 1 gateway | $32.40 |
| **Subtotal** | | **$112.46** |

#### Databases
| Service | Configuration | Monthly Cost |
|---------|--------------|--------------|
| RDS PostgreSQL | db.t4g.micro, Single-AZ | $12.41 |
| ElastiCache Redis | cache.t4g.micro, 1 node | $11.52 |
| DynamoDB | On-Demand (10GB) | $2.50 |
| **Subtotal** | | **$26.43** |

#### Storage & Messaging
| Service | Configuration | Monthly Cost |
|---------|--------------|--------------|
| S3 | 10GB + requests | $2.00 |
| SNS/SQS | Light usage | $1.00 |
| CloudWatch Logs | 3-day retention | $3.00 |
| KMS | 1 key | $1.00 |
| Secrets Manager | 3 secrets | $1.20 |
| **Subtotal** | | **$8.20** |

#### Data Transfer
| Service | Configuration | Monthly Cost |
|---------|--------------|--------------|
| NAT Gateway Data | 20GB/month | $0.90 |
| Inter-AZ Transfer | Minimal (single AZ) | $0.50 |
| **Subtotal** | | **$1.40** |

**Development Total: ~$148/month**

**With optimizations:**
- VPC Endpoints: Save ~$20/month on NAT Gateway data transfer
- Spot Instances: Save ~$16/month (70% discount)
- Destroy when not in use: Save 100% during idle periods

**Optimized Total: ~$50-80/month** (depending on usage patterns)

---

### Production Environment (~$3,112/month)

#### Compute & Networking
| Service | Configuration | Monthly Cost |
|---------|--------------|--------------|
| EKS Control Plane | 1 cluster | $72.00 |
| EKS General Nodes | 3x t3.xlarge, On-Demand | $450.72 |
| EKS AI Nodes | 2x r6i.2xlarge, On-Demand | $950.40 |
| NAT Gateway | 3 gateways (Multi-AZ) | $97.20 |
| Application Load Balancer | 1 ALB | $22.63 |
| **Subtotal** | | **$1,592.95** |

#### Databases
| Service | Configuration | Monthly Cost |
|---------|--------------|--------------|
| RDS PostgreSQL | db.r6i.xlarge, Multi-AZ | $849.60 |
| ElastiCache Redis | 3x cache.r7g.xlarge | $554.40 |
| DynamoDB | On-Demand (100GB) | $25.00 |
| **Subtotal** | | **$1,429.00** |

#### Storage & Messaging
| Service | Configuration | Monthly Cost |
|---------|--------------|--------------|
| S3 | 500GB + requests | $50.00 |
| SNS/SQS | High usage | $10.00 |
| CloudWatch Logs | 30-day retention | $30.00 |
| KMS | 7 keys | $7.00 |
| Secrets Manager | 7 secrets | $2.80 |
| VPC Flow Logs | Enabled | $10.00 |
| **Subtotal** | | **$109.80** |

#### Data Transfer
| Service | Configuration | Monthly Cost |
|---------|--------------|--------------|
| NAT Gateway Data | 500GB/month | $22.50 |
| Inter-AZ Transfer | ~1TB/month | $20.00 |
| Internet Egress | 1TB/month | $90.00 |
| **Subtotal** | | **$132.50** |

#### Monitoring & Security
| Service | Configuration | Monthly Cost |
|---------|--------------|--------------|
| RDS Performance Insights | Enabled | $7.09 |
| RDS Enhanced Monitoring | 60s interval | $1.26 |
| WAF | With managed rules | $15.00 |
| CloudWatch Dashboards | 3 dashboards | $9.00 |
| X-Ray | Traces + analysis | $5.00 |
| **Subtotal** | | **$37.35** |

**Production Total: ~$3,301/month**

**With Reserved Instances (1-year):**
- RDS Reserved Instance: Save ~$255/month (30%)
- ElastiCache Reserved: Save ~$166/month (30%)

**Optimized Total: ~$2,880/month**

---

## Cost Optimization Strategies

### Development Environment

#### Implemented ✅
1. **Spot Instances** - 70% savings on EKS nodes
2. **Single NAT Gateway** - 67% savings vs Multi-AZ
3. **VPC Endpoints** - Reduce NAT Gateway data transfer
4. **Smallest Instance Sizes** - t4g.micro, t3a.medium
5. **Single Availability Zone** - No cross-AZ charges
6. **Minimal Backups** - 1-day retention
7. **No Enhanced Monitoring** - Basic CloudWatch only
8. **Shared KMS Key** - 1 key vs 7
9. **On-Demand DynamoDB** - Pay per request
10. **Auto-cleanup S3** - 7-day lifecycle policy

#### Additional Savings Opportunities 💡
1. **Destroy when not in use** - Save 100% during nights/weekends
2. **Use Fargate Spot** - Even cheaper than EC2 Spot for ephemeral workloads
3. **LocalStack** - Free local AWS emulation for unit tests
4. **AWS Free Tier** - First 12 months: free t2.micro, 750hrs/month

### Production Environment

#### Recommended Optimizations 💰
1. **Reserved Instances** (1-year commitment)
   - RDS: Save ~30% ($255/month)
   - ElastiCache: Save ~30% ($166/month)
   - **Potential savings: ~$420/month**

2. **Graviton Instances** (ARM architecture)
   - EKS nodes: t3 → t4g (10% cheaper)
   - RDS: r6i → r7g (20% cheaper)
   - ElastiCache: Already using r7g ✅
   - **Potential savings: ~$150/month**

3. **Savings Plans** (1 or 3-year commitment)
   - Compute Savings Plans: Up to 72% discount
   - SageMaker Savings Plans: Up to 64% discount
   - **Potential savings: ~$500/month**

4. **S3 Intelligent-Tiering** (already enabled ✅)
   - Automatically moves data to cheaper tiers
   - **Saves: 10-30% on S3 costs**

5. **DynamoDB Reserved Capacity** (for predictable workloads)
   - Save up to 77% vs On-Demand
   - Consider if usage is consistent
   - **Potential savings: ~$15/month**

6. **CloudWatch Logs Optimization**
   - Export old logs to S3 (20x cheaper)
   - Use Contributor Insights sparingly
   - **Potential savings: ~$15/month**

7. **VPC Endpoints** (already enabled ✅)
   - Avoid NAT Gateway data transfer charges
   - **Saves: ~$10/month**

**Total Production Optimization Potential: ~$1,100/month (35% reduction)**
**Optimized Production Cost: ~$2,000/month**

---

## Cost Control Mechanisms

### Budget Alerts
- **Dev**: $200/month threshold (80% and 100% alerts)
- **Prod**: $15,000/month threshold (50%, 80%, 100% alerts)

### Monitoring
```bash
# Check current month costs
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE

# Forecast next month
aws ce get-cost-forecast \
  --time-period Start=$(date -d "next month" +%Y-%m-01),End=$(date -d "next month" +%Y-%m-%d) \
  --granularity MONTHLY \
  --metric BLENDED_COST
```

### Cost Allocation Tags
All resources tagged with:
- `Environment`: dev/prod
- `Project`: servicenow-ai
- `ManagedBy`: Terraform
- `CostCenter`: development/production

Use AWS Cost Explorer to filter by these tags.

---

## When to Use Each Environment

### Development Environment ✅
- Feature development
- Integration testing
- Code reviews
- Demos
- Learning/experimentation

**Cost-effective because:**
- Can be destroyed when not in use
- Spot instances acceptable (interruptions OK)
- Single-AZ sufficient
- Minimal redundancy needed

### Production Environment ✅
- Customer-facing applications
- 24/7 availability required
- Business-critical workloads
- Compliance requirements
- High traffic volumes

**Justifies higher cost because:**
- Multi-AZ high availability
- Automatic failover
- Enhanced monitoring
- Long-term backups
- Production SLAs

---

## Real-World Cost Scenarios

### Scenario 1: Active Development (8hrs/day, 5 days/week)
- **Strategy**: Keep dev environment running during work hours only
- **Monthly hours**: ~160 hours
- **Cost**: ~$30-50/month (70% savings from 24/7)

### Scenario 2: Weekend Testing
- **Strategy**: Deploy Friday, destroy Monday
- **Monthly hours**: ~96 hours (4 weekends)
- **Cost**: ~$20-30/month

### Scenario 3: Continuous Integration
- **Strategy**: Ephemeral environments for CI/CD
- **Per test run**: ~2 hours
- **Monthly runs**: 100 tests
- **Cost**: ~$40/month (using Fargate Spot)

### Scenario 4: Production with Reservations
- **Strategy**: 1-year Reserved Instances + Graviton
- **Monthly cost**: ~$2,000/month (36% savings)
- **Upfront payment**: ~$12,000/year
- **Total annual cost**: ~$24,000 vs $37,344 (save $13,344/year)

---

## Cost Comparison with GCP

| Service | AWS (Prod) | GCP Equivalent | Difference |
|---------|-----------|----------------|------------|
| Kubernetes | EKS: $72/mo | GKE: $72/mo | Same |
| Compute | t3.xlarge: $150 | n1-standard-4: $140 | AWS +7% |
| Database | r6i.xlarge RDS: $425 | db-n1-highmem-4: $400 | AWS +6% |
| Cache | r7g.xlarge: $185 | m2-highmem-1: $175 | AWS +6% |
| Storage | S3: $0.023/GB | GCS: $0.020/GB | AWS +15% |
| Egress | $0.09/GB | $0.12/GB | GCP +33% |

**Overall**: AWS and GCP costs are comparable for this workload. Choose based on:
- Team expertise
- Existing infrastructure
- Regional requirements
- Service availability

---

## Recommendations

### For Development Teams
1. ✅ Use dev environment for all non-production work
2. ✅ Destroy when not actively developing (save 70-90%)
3. ✅ Use Spot instances (already configured)
4. ✅ Consider LocalStack for local development (free)
5. ✅ Set up budget alerts (already configured)

### For Production Workloads
1. ✅ Purchase 1-year Reserved Instances for stable workloads
2. ✅ Use Savings Plans for flexible commitments
3. ✅ Migrate to Graviton instances (20% savings)
4. ✅ Enable S3 Intelligent-Tiering (already enabled)
5. ✅ Review costs monthly and optimize

### Cost Monitoring Checklist
- [ ] Weekly AWS Cost Explorer review
- [ ] Monthly Reserved Instance utilization check
- [ ] Quarterly rightsizing analysis
- [ ] Annual commitment renewal evaluation
- [ ] Continuous budget alert monitoring

---

## Appendix: Detailed Pricing (as of January 2025)

### Compute (us-east-1)
- t3a.medium: $0.0376/hr ($27.41/mo)
- t3.xlarge: $0.1664/hr ($121.47/mo)
- r6i.2xlarge: $0.504/hr ($367.92/mo)
- r7g.xlarge: $0.2016/hr ($147.17/mo)

### Database
- db.t4g.micro: $0.017/hr ($12.41/mo)
- db.r6i.xlarge: $0.29/hr ($211.70/mo, Multi-AZ = $423.40/mo)

### Cache
- cache.t4g.micro: $0.016/hr ($11.68/mo)
- cache.r7g.xlarge: $0.252/hr ($184.00/mo)

### Networking
- NAT Gateway: $0.045/hr + $0.045/GB processed
- VPC Endpoint: $0.01/hr per AZ + $0.01/GB

### Storage
- S3 Standard: $0.023/GB/mo
- S3 Standard-IA: $0.0125/GB/mo
- S3 Glacier Instant: $0.004/GB/mo

For latest pricing, visit: https://aws.amazon.com/pricing/
