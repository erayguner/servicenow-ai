# Development Environment Deployment Summary

## Overview

This document lists all resources created by Terraform in the development environment.

**Environment**: Development
**Region**: europe-west2
**Zone**: europe-west2-a (zonal cluster for cost optimization)
**Estimated Cost**: $50-100/day

---

## Deployed Resources

### Compute Resources (GKE)

| Resource | Name | Type | Configuration |
|----------|------|------|---------------|
| GKE Cluster | `dev-ai-agent-gke` | Zonal | 3 nodes, n2-standard-4 |
| Node Pool | `default-pool` | Standard | Autoscaling 2-5 nodes |
| Master | Private endpoint | Control plane | europe-west2-a |

**GKE Features**:
- ✅ Workload Identity enabled
- ✅ Private cluster
- ✅ Binary Authorization
- ✅ GKE Autopilot disabled (standard mode)
- ✅ Network Policy enabled
- ✅ HTTP Load Balancing enabled
- ✅ Horizontal Pod Autoscaling enabled

### Networking

| Resource | Name | CIDR | Purpose |
|----------|------|------|---------|
| VPC Network | `dev-ai-agent-vpc` | - | Main network |
| Subnet (GKE) | `dev-ai-agent-gke-subnet` | 10.0.0.0/20 | GKE pods/nodes |
| Subnet (CloudSQL) | `dev-ai-agent-cloudsql-subnet` | 10.1.0.0/24 | Private services |
| Secondary Range (Pods) | `gke-pods` | 10.4.0.0/14 | GKE pod IPs |
| Secondary Range (Services) | `gke-services` | 10.8.0.0/20 | GKE service IPs |
| GKE Master CIDR | - | 172.16.0.0/28 | Control plane |
| Cloud Router | `dev-ai-agent-router` | - | NAT gateway |
| Cloud NAT | `dev-ai-agent-nat` | - | Egress traffic |

**Firewall Rules**:
- Internal communication: 10.0.0.0/8
- SSH access (optional): 22/tcp
- HTTPS: 443/tcp
- Health checks: Load balancer ranges

### Databases

#### CloudSQL PostgreSQL

| Resource | Name | Configuration |
|----------|------|---------------|
| Instance | `dev-ai-agent-cloudsql` | PostgreSQL 15 |
| Tier | `db-custom-2-7680` | 2 vCPU, 7.5GB RAM |
| Disk | 10GB SSD | Auto-resize enabled |
| High Availability | Disabled | Dev environment |
| Backup | Enabled | Daily at 03:00 UTC |
| Private IP | Enabled | VPC peering |

**Databases**:
- `servicenow_dev` - Main application database
- `postgres` - Default admin database

**Users**:
- `servicenow_user` - Application user
- `postgres` - Admin user (via Secret Manager)

#### Firestore

| Resource | Name | Configuration |
|----------|------|---------------|
| Database | `dev-ai-agent-firestore` | Native mode |
| Location | `europe-west2` | Regional |

**Collections**:
- `conversations` - Chat history
- `users` - User profiles
- `sessions` - Active sessions

#### Redis (Memorystore)

| Resource | Name | Configuration |
|----------|------|---------------|
| Instance | `dev-ai-agent-redis` | Basic tier |
| Version | Redis 7.0 | Latest stable |
| Memory | 1GB | Standard |
| Private IP | Enabled | VPC connected |

### Storage

| Resource | Name | Purpose |
|----------|------|---------|
| GCS Bucket | `dev-ai-agent-models` | ML model artifacts |
| GCS Bucket | `dev-ai-agent-logs` | Application logs |
| GCS Bucket | `dev-ai-agent-backups` | Database backups |

**Lifecycle Policies**:
- Logs: Delete after 30 days
- Backups: Delete after 90 days
- Models: Retain indefinitely

### Pub/Sub

| Resource | Name | Purpose |
|----------|------|---------|
| Topic | `dev-ai-agent-events` | Application events |
| Topic | `dev-ai-agent-llm-requests` | LLM request queue |
| Topic | `dev-ai-agent-notifications` | System notifications |
| Subscription | `dev-ai-agent-events-sub` | Event consumer |
| Subscription | `dev-ai-agent-llm-requests-sub` | LLM processor |

### Security

#### KMS (Key Management)

| Resource | Name | Purpose |
|----------|------|---------|
| Keyring | `dev-ai-agent-keyring` | Main keyring |
| Key | `cloudsql-key` | CloudSQL encryption |
| Key | `gke-key` | GKE secrets encryption |
| Key | `storage-key` | GCS bucket encryption |

**Key Rotation**: Automatic 90-day rotation

#### Secret Manager

| Secret | Purpose | Rotation |
|--------|---------|----------|
| `cloudsql-password` | CloudSQL admin password | Manual |
| `servicenow-credentials` | ServiceNow API creds | 90 days |
| `llm-api-keys` | LLM provider API keys | 30 days |
| `github-token` | CI/CD GitHub token | 90 days |

### Identity & Access Management

#### Service Accounts

| Service Account | Purpose | Workload Identity |
|-----------------|---------|-------------------|
| `dev-ai-agent-gke-sa` | GKE node service account | No |
| `dev-ai-agent-llm-gateway-sa` | LLM gateway pods | Yes (Kubernetes SA) |
| `dev-ai-agent-backend-sa` | Backend application | Yes (Kubernetes SA) |
| `dev-ai-agent-cloudsql-sa` | CloudSQL proxy | Yes (Kubernetes SA) |

#### Workload Identity Bindings

| Kubernetes SA | Namespace | GCP SA | Role |
|---------------|-----------|--------|------|
| `llm-gateway-sa` | `production` | `dev-ai-agent-llm-gateway-sa` | Vertex AI User |
| `backend-sa` | `production` | `dev-ai-agent-backend-sa` | Storage Admin |
| `cloudsql-client` | `production` | `dev-ai-agent-cloudsql-sa` | Cloud SQL Client |

### AI/ML Services

#### Vertex AI

| Resource | Configuration |
|----------|---------------|
| Region | europe-west2 |
| Models | gemini-1.5-pro, gemini-1.5-flash |
| Endpoints | 2 endpoints (pro, flash) |
| Quotas | Default quotas |

**Configured Models**:
- `gemini-1.5-pro-001` - Complex reasoning, long context
- `gemini-1.5-flash-001` - Fast inference, cost-effective

### Kubernetes Resources

#### Namespaces

- `production` - Main application namespace
- `observability` - Monitoring and logging
- `gpu-operator` - NVIDIA GPU operator (if enabled)

#### Deployments

| Deployment | Namespace | Replicas | Purpose |
|------------|-----------|----------|---------|
| `backend` | `production` | 3 | Node.js backend API |
| `frontend` | `production` | 2 | Next.js frontend |
| `vertex-ai-gateway` | `production` | 3 | Vertex AI proxy |
| `llm-router` | `production` | 3 | Hybrid LLM routing |
| `conversation-manager` | `production` | 2 | Chat orchestration |

#### Services

| Service | Type | Port | Purpose |
|---------|------|------|---------|
| `backend-service` | LoadBalancer | 8080 | Backend API |
| `frontend-service` | LoadBalancer | 3000 | Frontend UI |
| `vertex-ai-gateway` | ClusterIP | 80 | Internal Vertex AI |
| `llm-router` | ClusterIP | 80 | Internal LLM routing |

### Monitoring & Observability

| Resource | Configuration |
|----------|---------------|
| Cloud Logging | All services enabled |
| Cloud Monitoring | Custom dashboards |
| Cloud Trace | Distributed tracing |
| Cloud Profiler | Performance profiling |

**Prometheus Stack** (if deployed):
- Prometheus Server
- Grafana Dashboard
- AlertManager
- Node Exporter
- kube-state-metrics

---

## Resource Counts

| Category | Count |
|----------|-------|
| **Compute** | 1 GKE cluster (3 nodes) |
| **Networking** | 1 VPC, 2 subnets, 1 NAT gateway |
| **Databases** | 1 CloudSQL, 1 Firestore, 1 Redis |
| **Storage** | 3 GCS buckets |
| **Pub/Sub** | 3 topics, 2 subscriptions |
| **Security** | 1 keyring, 3 KMS keys, 4 secrets |
| **IAM** | 4 service accounts, 3 WI bindings |
| **Kubernetes** | 5 deployments, 4 services |
| **Total Estimated** | ~55-60 resources |

---

## Endpoints and Access

### External Endpoints

```bash
# Backend API
http://BACKEND_LB_IP:8080
http://BACKEND_LB_IP:8080/health
http://BACKEND_LB_IP:8080/api/v1

# Frontend
http://FRONTEND_LB_IP:3000

# Get LoadBalancer IPs
kubectl get svc -n production
```

### Internal Endpoints

```bash
# Vertex AI Gateway
http://vertex-ai-gateway.production.svc.cluster.local

# LLM Router
http://llm-router.production.svc.cluster.local

# CloudSQL (via proxy)
localhost:5432 (when using cloud_sql_proxy)
```

### Management Endpoints

```bash
# GKE Cluster
gcloud container clusters get-credentials dev-ai-agent-gke \
  --zone=europe-west2-a --project=PROJECT_ID

# CloudSQL
gcloud sql connect dev-ai-agent-cloudsql --user=postgres

# Redis
gcloud redis instances describe dev-ai-agent-redis --region=europe-west2
```

---

## Cost Breakdown

### Daily Estimated Costs (Development)

| Service | Configuration | Daily Cost |
|---------|---------------|------------|
| GKE Cluster | 3x n2-standard-4 nodes | $3-5 |
| CloudSQL | db-custom-2-7680 | $2-3 |
| Redis | 1GB Basic | $1 |
| GCS Storage | 100GB | $0.20 |
| Vertex AI | Pay-per-use | $1-5 |
| Networking | Egress/NAT | $0.50-2 |
| **Total** | | **$8-18/day** |

### Monthly Estimated Costs

| | Cost |
|---|------|
| Minimum | $240/month |
| Average | $400/month |
| Maximum | $540/month |

**Cost Optimization Tips**:
- Stop GKE cluster after hours: `gcloud container clusters resize --num-nodes=0`
- Use Cloud SQL scheduled backups instead of continuous replication
- Delete unused GCS objects
- Monitor Vertex AI usage (pay-per-use)

---

## Verification Commands

```bash
# List all GCP resources
gcloud compute instances list --project=PROJECT_ID
gcloud container clusters list --project=PROJECT_ID
gcloud sql instances list --project=PROJECT_ID
gcloud redis instances list --region=europe-west2 --project=PROJECT_ID

# Kubernetes resources
kubectl get all -n production
kubectl get pvc,pv -A
kubectl get secrets -n production

# Check service health
kubectl get deployments -n production
kubectl get pods -n production -o wide
```

---

## Cleanup Procedure

To delete all resources:

```bash
cd terraform/environments/dev

# Destroy infrastructure
terraform destroy -auto-approve

# Verify deletion
gcloud compute instances list --project=PROJECT_ID
gcloud container clusters list --project=PROJECT_ID
```

**Warning**: This deletes ALL resources including data. Backup before destroying.

---

## Next Steps

1. ✅ **Verify deployment** - Run post-deployment verification from [DEPLOYMENT_RUNBOOK.md](DEPLOYMENT_RUNBOOK.md)
2. Configure monitoring alerts
3. Set up CI/CD pipelines
4. Deploy applications
5. Configure backup schedules
6. Review security settings

---

## Support

- **Documentation**: [README.md](../../../README.md)
- **Troubleshooting**: [terraform/docs/TROUBLESHOOTING.md](../../docs/TROUBLESHOOTING.md)
- **Issues**: https://github.com/erayguner/servicenow-ai/issues
