# Development Environment Deployment Runbook

Complete end-to-end deployment guide for the Development environment.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Pre-Deployment Checklist](#pre-deployment-checklist)
- [Deployment Steps](#deployment-steps)
- [Post-Deployment Verification](#post-deployment-verification)
- [Troubleshooting](#troubleshooting)
- [Rollback Procedure](#rollback-procedure)

---

## Prerequisites

### Required Tools

```bash
# Terraform 1.11+
terraform -v

# Google Cloud SDK
gcloud version

# kubectl
kubectl version --client

# Pre-commit hooks
pre-commit --version

# Make
make --version
```

### Required Permissions

- **GCP Project Owner** or the following roles:
  - Compute Admin
  - Kubernetes Engine Admin
  - Service Account Admin
  - Security Admin
  - Project IAM Admin
- **Billing Account User** role for cost tracking
- **GitHub Repository** write access (for CI/CD)

### Required Information

Before starting, collect:

```bash
export PROJECT_ID="your-dev-project-id"
export BILLING_ACCOUNT="XXXXXX-XXXXXX-XXXXXX"
export REGION="europe-west2"
export ZONE="europe-west2-a"          # Zonal for dev (quota optimization)
export GKE_MASTER_CIDR="172.16.0.0/28"
```

---

## Pre-Deployment Checklist

### 1. Verify Quotas

```bash
# Check current quota usage
gcloud compute project-info describe --project=$PROJECT_ID \
  | grep -E "CPUS|IN_USE_ADDRESSES|SSD_TOTAL_GB"

# Required quotas for dev:
# - CPUs: 24+
# - SSD_TOTAL_GB: 500+
# - IN_USE_ADDRESSES: 10+
```

### 2. Enable Required APIs

```bash
gcloud services enable \
  compute.googleapis.com \
  container.googleapis.com \
  sqladmin.googleapis.com \
  cloudkms.googleapis.com \
  secretmanager.googleapis.com \
  servicenetworking.googleapis.com \
  redis.googleapis.com \
  firestore.googleapis.com \
  pubsub.googleapis.com \
  storage.googleapis.com \
  aiplatform.googleapis.com \
  run.googleapis.com \
  --project=$PROJECT_ID
```

### 3. Authenticate

```bash
# Application Default Credentials with quota project
gcloud auth application-default login --project=$PROJECT_ID

# Set active project
gcloud config set project $PROJECT_ID

# Verify authentication
gcloud auth list
```

### 4. Create Terraform Backend (First Time Only)

```bash
# Create GCS bucket for Terraform state
gsutil mb -p $PROJECT_ID -l $REGION gs://${PROJECT_ID}-terraform-state

# Enable versioning
gsutil versioning set on gs://${PROJECT_ID}-terraform-state

# Set lifecycle policy (optional - keep 10 versions)
cat > lifecycle.json <<EOF
{
  "lifecycle": {
    "rule": [{
      "action": {"type": "Delete"},
      "condition": {"numNewerVersions": 10}
    }]
  }
}
EOF
gsutil lifecycle set lifecycle.json gs://${PROJECT_ID}-terraform-state
rm lifecycle.json
```

---

## Deployment Steps

### Step 1: Clone and Setup Repository

```bash
# Clone repository
git clone https://github.com/erayguner/servicenow-ai.git
cd servicenow-ai

# Install pre-commit hooks
make pre-commit-install

# Verify setup
make help
```

### Step 2: Configure Terraform Variables

```bash
cd terraform/environments/dev

# Create terraform.tfvars
cat > terraform.tfvars <<EOF
project_id      = "$PROJECT_ID"
region          = "$REGION"
zone            = "$ZONE"
billing_account = "$BILLING_ACCOUNT"
gke_master_cidr = "$GKE_MASTER_CIDR"

# Optional: customize cluster configuration
gke_node_count        = 3
gke_machine_type      = "n2-standard-4"
gke_disk_size_gb      = 100

# Optional: database configuration
cloudsql_tier         = "db-custom-2-7680"
cloudsql_disk_size    = 10

# Optional: Redis configuration
redis_memory_size_gb  = 1
redis_tier            = "BASIC"
EOF
```

### Step 3: Initialize Terraform

```bash
# Initialize providers and modules
terraform init

# Validate configuration
terraform validate

# Check formatting
terraform fmt -check
```

### Step 4: Plan Infrastructure

```bash
# Generate and review execution plan
terraform plan -out=tfplan

# Review the plan carefully:
# - Verify resource names
# - Check region/zone configuration
# - Confirm cost estimates
# - Validate security settings
```

**Expected resources to be created:**
- ~50-60 resources total
- GKE cluster (zonal)
- VPC network with subnets
- CloudSQL PostgreSQL instance
- Firestore database
- Redis instance
- Cloud KMS keys
- Secret Manager secrets
- Workload Identity bindings
- IAM service accounts
- Pub/Sub topics

### Step 5: Apply Infrastructure

```bash
# Apply the plan (takes ~15-20 minutes)
terraform apply tfplan

# Monitor progress
# - GKE cluster: ~10-12 minutes
# - CloudSQL: ~8-10 minutes
# - Other resources: ~2-5 minutes
```

**Critical Success Indicators:**
- ✅ All resources created successfully
- ✅ No permission errors
- ✅ State saved to GCS backend

### Step 6: Configure Kubernetes Access

```bash
# Get GKE credentials (ZONAL cluster for dev)
gcloud container clusters get-credentials dev-ai-agent-gke \
  --zone=$ZONE \
  --project=$PROJECT_ID

# Verify cluster access
kubectl cluster-info
kubectl get nodes
kubectl get namespaces
```

### Step 7: Deploy Kubernetes Manifests

```bash
# Return to repository root
cd ../../..

# Apply Kubernetes resources in order
kubectl apply -f k8s/service-accounts/
kubectl apply -f k8s/network-policies/
kubectl apply -f k8s/pod-security/
kubectl apply -f k8s/deployments/

# Wait for deployments to be ready
kubectl wait --for=condition=available --timeout=300s \
  deployment --all -n production
```

### Step 8: Configure Secrets

```bash
# Create required secrets
kubectl create secret generic servicenow-credentials \
  --from-literal=instance-url=https://dev123456.service-now.com \
  --from-literal=username=admin \
  --from-literal=password=your-password \
  -n production

# Verify secrets
kubectl get secrets -n production
```

### Step 9: Deploy LLM Serving Infrastructure

```bash
# Deploy KServe runtime
kubectl apply -f k8s/llm-serving/kserve-runtime.yaml

# Deploy foundational models (Vertex AI gateway)
kubectl apply -f k8s/llm-serving/foundational-models.yaml

# Deploy hybrid routing (optional)
kubectl apply -f k8s/llm-serving/hybrid-routing.yaml

# Verify LLM services
kubectl get inferenceservice -n production
kubectl get pods -n production -l app=llm-router
```

---

## Post-Deployment Verification

### 1. Infrastructure Health Check

```bash
# GKE cluster
gcloud container clusters describe dev-ai-agent-gke \
  --zone=$ZONE --format="value(status)"
# Expected: RUNNING

# CloudSQL
gcloud sql instances describe dev-ai-agent-cloudsql \
  --format="value(state)"
# Expected: RUNNABLE

# Redis
gcloud redis instances describe dev-ai-agent-redis \
  --region=$REGION --format="value(state)"
# Expected: READY
```

### 2. Kubernetes Resources

```bash
# Check all pods are running
kubectl get pods --all-namespaces | grep -v Running
# Should be empty or only show Completed

# Check deployments
kubectl get deployments -n production
# All should show READY replicas

# Check services
kubectl get services -n production
```

### 3. Workload Identity Verification

```bash
# Test workload identity binding
kubectl run -it --rm test-wi \
  --image=google/cloud-sdk:slim \
  --serviceaccount=llm-gateway-sa \
  --namespace=production \
  -- gcloud auth list

# Should show: dev-ai-agent-llm-gateway@PROJECT_ID.iam.gserviceaccount.com
```

### 4. Database Connectivity

```bash
# Test CloudSQL connection via proxy
cloud_sql_proxy -instances=$PROJECT_ID:$REGION:dev-ai-agent-cloudsql=tcp:5432 &

# Connect to database
psql "host=127.0.0.1 port=5432 dbname=servicenow_dev user=servicenow_user"
\dt  # List tables
\q   # Quit
```

### 5. Application Endpoints

```bash
# Get Load Balancer IP
kubectl get svc -n production | grep LoadBalancer

# Test backend health endpoint
LB_IP=$(kubectl get svc backend-service -n production -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl http://$LB_IP/health

# Expected: {"status":"healthy"}
```

### 6. Observability Stack

```bash
# Check Prometheus
kubectl port-forward -n observability svc/prometheus 9090:9090 &
curl http://localhost:9090/-/healthy
# Expected: Prometheus is Healthy.

# Check Grafana
kubectl port-forward -n observability svc/grafana 3000:3000 &
# Access: http://localhost:3000
```

### 7. Cost Verification

```bash
# Check current spend
gcloud billing accounts describe $BILLING_ACCOUNT

# Expected dev environment cost: $50-100/day
# - GKE cluster: ~$3-5/day (n2-standard-4 x 3)
# - CloudSQL: ~$2-3/day (db-custom-2-7680)
# - Redis: ~$1/day (BASIC, 1GB)
# - Other services: ~$1-2/day
```

---

## Troubleshooting

### Common Issues

#### Issue: Terraform Apply Fails with Quota Errors

```bash
# Error: Quota 'SSD_TOTAL_GB' exceeded
# Solution: Use zonal cluster or reduce node disk size

# Check current usage
gcloud compute project-info describe --project=$PROJECT_ID

# Reduce disk size in terraform.tfvars
gke_disk_size_gb = 50  # Instead of 100
```

#### Issue: GKE Cluster Not Accessible

```bash
# Error: Unable to connect to the server
# Solution: Re-fetch credentials and check firewall

gcloud container clusters get-credentials dev-ai-agent-gke \
  --zone=$ZONE --project=$PROJECT_ID

# Check authorized networks
gcloud container clusters describe dev-ai-agent-gke \
  --zone=$ZONE --format="value(masterAuthorizedNetworksConfig)"
```

#### Issue: Pods Stuck in Pending

```bash
# Check node resources
kubectl describe nodes

# Check pod events
kubectl describe pod POD_NAME -n production

# Common causes:
# - Insufficient CPU/memory
# - Image pull errors
# - PVC binding issues
```

For more troubleshooting, see [TROUBLESHOOTING.md](../../docs/TROUBLESHOOTING.md).

---

## Rollback Procedure

### Option 1: Terraform Destroy (Complete Rollback)

```bash
cd terraform/environments/dev

# Destroy all resources
terraform destroy

# Confirm when prompted
# Note: This deletes ALL infrastructure
```

### Option 2: Partial Rollback (Kubernetes Only)

```bash
# Delete Kubernetes resources
kubectl delete -f k8s/llm-serving/ --ignore-not-found
kubectl delete -f k8s/deployments/ --ignore-not-found
kubectl delete -f k8s/network-policies/ --ignore-not-found

# Keep infrastructure intact
```

### Option 3: State Rollback

```bash
# List state versions
gsutil ls -l gs://${PROJECT_ID}-terraform-state/

# Download previous version
gsutil cp gs://${PROJECT_ID}-terraform-state/default.tfstate#VERSION terraform.tfstate

# Apply previous state
terraform apply
```

---

## Next Steps

After successful deployment:

1. **Configure monitoring alerts** - Set up Prometheus alerting rules
2. **Deploy applications** - Deploy backend and frontend applications
3. **Configure CI/CD** - Set up GitHub Actions workflows
4. **Test integrations** - Verify ServiceNow integration
5. **Security review** - Run security scans with Checkov and tfsec

See [DEPLOYMENT_SUMMARY.md](DEPLOYMENT_SUMMARY.md) for a complete list of deployed resources.

---

## Support

- **Issues**: https://github.com/erayguner/servicenow-ai/issues
- **Documentation**: See [README.md](../../../README.md)
- **Troubleshooting**: See [terraform/docs/TROUBLESHOOTING.md](../../docs/TROUBLESHOOTING.md)
