# ServiceNow AI Infrastructure - Complete Deployment Runbook

**Version:** 1.0
**Last Updated:** 2025-11-04
**Environment:** Development
**Estimated Time:** 45-60 minutes

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Pre-Deployment Checklist](#pre-deployment-checklist)
4. [Phase 1: Environment Setup](#phase-1-environment-setup)
5. [Phase 2: Infrastructure Deployment](#phase-2-infrastructure-deployment)
6. [Phase 3: Kubernetes Configuration](#phase-3-kubernetes-configuration)
7. [Phase 4: Application Deployment](#phase-4-application-deployment)
8. [Phase 5: Verification & Testing](#phase-5-verification--testing)
9. [Post-Deployment Tasks](#post-deployment-tasks)
10. [Troubleshooting](#troubleshooting)
11. [Rollback Procedures](#rollback-procedures)

---

## Overview

This runbook provides step-by-step instructions for deploying the complete ServiceNow AI infrastructure on Google Cloud Platform using Terraform and Kubernetes.

### What Gets Deployed

| Component | Description | Configuration |
|-----------|-------------|---------------|
| **GKE Cluster** | Kubernetes cluster | Zonal (europe-west2-a), 3 node pools |
| **Cloud SQL** | PostgreSQL database | 4 vCPU, 16GB RAM, 50GB SSD |
| **VPC Network** | Private networking | 10.70.0.0/20 with private subnets |
| **Cloud Storage** | Object storage | 5 encrypted buckets |
| **Pub/Sub** | Message queue | 5 topics with encryption |
| **Redis** | Cache | 1GB memory |
| **Firestore** | NoSQL database | Native mode |
| **KMS** | Encryption keys | 4 keys with 90-day rotation |
| **Secrets** | Secret storage | 7 secret placeholders |

### Architecture Decisions

**Why Zonal Cluster for Dev?**
- **Cost Optimization:** Single zone = 1 node instead of 3
- **Quota Management:** Regional SSD quota is 250GB, zonal uses less
- **Development Focus:** HA not critical for dev environment

**Why Regional for Staging/Prod?**
- **High Availability:** Multi-zone redundancy
- **SLA Requirements:** 99.95% uptime
- **Production Ready:** Zero-downtime upgrades

---

## Prerequisites

### Required Tools

Install these tools before starting:

```bash
# 1. Google Cloud SDK
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
gcloud --version

# 2. Terraform
brew install terraform  # macOS
# OR
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# 3. kubectl
gcloud components install kubectl

# 4. Git
git --version  # Should be pre-installed

# Verify installations
terraform --version  # Should be >= 1.0
gcloud --version     # Should be latest
kubectl version --client  # Should be 1.28+
```

### GCP Project Setup

1. **Create or select GCP project:**
   ```bash
   # List existing projects
   gcloud projects list

   # Create new project (if needed)
   gcloud projects create servicenow-ai-477221 \
     --name="ServiceNow AI Infrastructure"

   # Set active project
   gcloud config set project servicenow-ai-477221
   ```

2. **Link billing account:**
   ```bash
   # List billing accounts
   gcloud billing accounts list

   # Link to project
   gcloud billing projects link servicenow-ai-477221 \
     --billing-account=XXXXXX-XXXXXX-XXXXXX
   ```

3. **Enable required APIs:**
   ```bash
   gcloud services enable compute.googleapis.com \
     container.googleapis.com \
     sqladmin.googleapis.com \
     cloudkms.googleapis.com \
     secretmanager.googleapis.com \
     servicenetworking.googleapis.com \
     redis.googleapis.com \
     storage.googleapis.com \
     pubsub.googleapis.com \
     firestore.googleapis.com \
     cloudresourcemanager.googleapis.com \
     iam.googleapis.com \
     iamcredentials.googleapis.com

   # Wait 2-3 minutes for APIs to activate
   sleep 180
   ```

### Required Permissions

You need one of these:

**Option 1: Project Owner** (Recommended for dev)
```bash
gcloud projects add-iam-policy-binding servicenow-ai-477221 \
  --member="user:your-email@example.com" \
  --role="roles/owner"
```

**Option 2: Specific Roles** (Principle of least privilege)
```bash
PROJECT_ID="servicenow-ai-477221"
USER_EMAIL="your-email@example.com"

for role in \
  "roles/compute.admin" \
  "roles/container.admin" \
  "roles/iam.serviceAccountAdmin" \
  "roles/iam.securityAdmin" \
  "roles/cloudsql.admin" \
  "roles/cloudkms.admin" \
  "roles/secretmanager.admin" \
  "roles/storage.admin" \
  "roles/pubsub.admin" \
  "roles/redis.admin"
do
  gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="user:$USER_EMAIL" \
    --role="$role"
done
```

### Authentication

```bash
# Authenticate with Application Default Credentials
gcloud auth application-default login --project=servicenow-ai-477221

# Authenticate with gcloud (for CLI commands)
gcloud auth login

# Verify authentication
gcloud auth list

# Set quota project (important for billing API)
gcloud auth application-default set-quota-project servicenow-ai-477221
```

---

## Pre-Deployment Checklist

Before starting deployment, verify:

- [ ] GCP project created and billing enabled
- [ ] All required APIs enabled (wait 3+ minutes after enabling)
- [ ] Correct IAM permissions assigned
- [ ] Tools installed (gcloud, terraform, kubectl)
- [ ] Authenticated with `gcloud auth application-default login`
- [ ] Quota project set for ADC
- [ ] Git repository cloned locally
- [ ] Network connectivity verified
- [ ] SSD quota checked (should have 250GB available in europe-west2)

**Check SSD Quota:**
```bash
gcloud compute regions describe europe-west2 \
  --format="table(quotas.filter(metric:SSD_TOTAL_GB))"
```

**Expected output:** `SSD_TOTAL_GB: 250.0` (default free tier quota)

---

## Phase 1: Environment Setup

**Duration:** 5-10 minutes

### Step 1.1: Clone Repository

```bash
# Clone repository
git clone https://github.com/YOUR_ORG/servicenow-ai.git
cd servicenow-ai

# Verify structure
ls -la terraform/environments/dev/
```

### Step 1.2: Create Terraform Variables

```bash
cd terraform/environments/dev

# Create terraform.tfvars
cat > terraform.tfvars <<EOF
project_id      = "servicenow-ai-477221"
region          = "europe-west2"
billing_account = "XXXXXX-XXXXXX-XXXXXX"  # Replace with your billing account
gke_master_cidr = "172.16.0.0/28"
EOF

# Verify file
cat terraform.tfvars
```

**Important:** Replace `XXXXXX-XXXXXX-XXXXXX` with your actual billing account ID from:
```bash
gcloud billing accounts list
```

### Step 1.3: Create Terraform Backend (Optional but Recommended)

```bash
# Create GCS bucket for state
PROJECT_ID="servicenow-ai-477221"
BUCKET_NAME="${PROJECT_ID}-terraform-state-dev"

gsutil mb -p $PROJECT_ID -l europe-west2 gs://$BUCKET_NAME/
gsutil versioning set on gs://$BUCKET_NAME/

# Enable encryption
gcloud kms keyrings create terraform-state \
  --location=europe-west2 \
  --project=$PROJECT_ID

gcloud kms keys create terraform-state-key \
  --location=europe-west2 \
  --keyring=terraform-state \
  --purpose=encryption \
  --project=$PROJECT_ID

# Create backend.tf
cat > backend.tf <<EOF
terraform {
  backend "gcs" {
    bucket = "${BUCKET_NAME}"
    prefix = "terraform/state/dev"
  }
}
EOF
```

### Step 1.4: Review Configuration

```bash
# Review main configuration
cat main.tf

# Review variables
cat variables.tf

# Check for any sensitive data (should be none)
grep -r "password\|secret\|key" *.tf
```

---

## Phase 2: Infrastructure Deployment

**Duration:** 20-25 minutes

### Step 2.1: Initialize Terraform

```bash
cd terraform/environments/dev

# Initialize Terraform
terraform init

# Expected output:
# - Downloading providers (google ~5.0)
# - Initializing backend
# - Success message
```

**Troubleshooting Init:**
- If backend error: Check bucket permissions
- If provider error: Check internet connection
- If module error: Verify module paths in main.tf

### Step 2.2: Validate Configuration

```bash
# Validate Terraform syntax
terraform validate

# Expected output: "Success! The configuration is valid."
```

### Step 2.3: Plan Deployment

```bash
# Generate execution plan
terraform plan -out=tfplan

# Review output carefully:
# - Resources to create: ~40-50 resources
# - No resources to destroy
# - No errors or warnings
```

**Key Resources to Verify:**
- ✅ GKE cluster in europe-west2-a (ZONAL)
- ✅ 3 node pools (general, ai_inference, vector)
- ✅ Cloud SQL with private IP
- ✅ VPC with private service connection
- ✅ KMS keys with IAM bindings
- ✅ Storage buckets with encryption
- ✅ Pub/Sub topics with encryption

### Step 2.4: Apply Infrastructure

```bash
# Apply with saved plan
terraform apply tfplan

# Expected duration: 15-20 minutes
# - VPC and networking: 2-3 minutes
# - KMS keys: 1-2 minutes
# - GKE cluster: 10-12 minutes (longest)
# - Cloud SQL: 5-7 minutes
# - Storage, Pub/Sub, Redis: 1-2 minutes each
```

**Monitor Progress:**
```bash
# In another terminal, watch GKE cluster creation
watch -n 30 'gcloud container clusters list'

# Watch Cloud SQL
watch -n 30 'gcloud sql instances list'
```

**Common Issues During Apply:**

| Error | Solution |
|-------|----------|
| **SSD quota exceeded** | Already fixed - using zonal cluster |
| **Service not enabled** | Wait 3+ minutes after enabling APIs |
| **Permission denied** | Check IAM roles, re-authenticate |
| **Resource already exists** | Import: `terraform import MODULE.RESOURCE ID` |
| **Timeout** | Re-run `terraform apply` - it's idempotent |

### Step 2.5: Verify Infrastructure

```bash
# Check Terraform state
terraform show | grep "resource \"google"

# Verify GKE cluster
gcloud container clusters describe dev-ai-agent-gke \
  --location=europe-west2-a \
  --format="table(name,status,currentNodeCount,endpoint)"

# Expected: STATUS=RUNNING, currentNodeCount=1

# Verify Cloud SQL
gcloud sql instances describe dev-postgres \
  --format="table(name,state,databaseVersion,ipAddresses)"

# Expected: state=RUNNABLE

# List all resources
gcloud compute instances list
gcloud storage buckets list
gcloud pubsub topics list
gcloud kms keys list --location=europe-west2 --keyring=dev-keyring
```

---

## Phase 3: Kubernetes Configuration

**Duration:** 10-15 minutes

### Step 3.1: Get Cluster Credentials

```bash
# Configure kubectl
gcloud container clusters get-credentials dev-ai-agent-gke \
  --location=europe-west2-a \
  --project=servicenow-ai-477221

# Verify connection
kubectl cluster-info
kubectl get nodes

# Expected output:
# - 1 node (general-pool)
# - STATUS: Ready
# - VERSION: 1.33.x
```

### Step 3.2: Create Namespaces

```bash
# Create production namespace
kubectl create namespace production

# Create monitoring namespace
kubectl create namespace monitoring

# Verify
kubectl get namespaces
```

### Step 3.3: Deploy Service Accounts with Workload Identity

```bash
cd ../../../k8s/service-accounts

# Update project ID in all files
export PROJECT_ID="servicenow-ai-477221"
find . -name "*.yaml" -exec sed -i "s/PROJECT_ID/$PROJECT_ID/g" {} \;

# Apply service accounts
kubectl apply -f all-service-accounts.yaml

# Verify
kubectl get serviceaccounts -n production

# Expected: 10 service accounts created
```

### Step 3.4: Create IAM Bindings for Workload Identity

```bash
# For each service account, create IAM binding
PROJECT_ID="servicenow-ai-477221"

# Conversation Manager
gcloud iam service-accounts add-iam-policy-binding \
  conversation-manager@${PROJECT_ID}.iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:${PROJECT_ID}.svc.id.goog[production/conversation-manager-sa]"

# LLM Gateway
gcloud iam service-accounts add-iam-policy-binding \
  llm-gateway@${PROJECT_ID}.iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:${PROJECT_ID}.svc.id.goog[production/llm-gateway-sa]"

# Repeat for all 10 services...
# (See k8s/service-accounts/setup-workload-identity.sh for complete script)
```

### Step 3.5: Deploy Network Policies

```bash
cd ../network-policies

# Apply default-deny policy
kubectl apply -f default-deny.yaml

# Apply service-specific policies
kubectl apply -f conversation-manager-netpol.yaml
kubectl apply -f llm-gateway-netpol.yaml
# ... apply all network policies

# Verify
kubectl get networkpolicies -n production
```

### Step 3.6: Apply Pod Security Standards

```bash
cd ../pod-security

# Label namespace for restricted security
kubectl label namespace production \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted

# Verify
kubectl get namespace production --show-labels
```

---

## Phase 4: Application Deployment

**Duration:** 10-15 minutes

### Step 4.1: Populate Secrets

```bash
# OpenAI API Key
echo -n "sk-..." | gcloud secrets versions add openai-api-key \
  --data-file=- \
  --project=servicenow-ai-477221

# Anthropic API Key
echo -n "sk-ant-..." | gcloud secrets versions add anthropic-api-key \
  --data-file=- \
  --project=servicenow-ai-477221

# ServiceNow OAuth
echo -n "client-id" | gcloud secrets versions add servicenow-oauth-client-id \
  --data-file=- \
  --project=servicenow-ai-477221

echo -n "client-secret" | gcloud secrets versions add servicenow-oauth-client-secret \
  --data-file=- \
  --project=servicenow-ai-477221

# Slack Integration
echo -n "xoxb-..." | gcloud secrets versions add slack-bot-token \
  --data-file=- \
  --project=servicenow-ai-477221

echo -n "signing-secret" | gcloud secrets versions add slack-signing-secret \
  --data-file=- \
  --project=servicenow-ai-477221

# Vertex AI (if using)
echo -n "api-key" | gcloud secrets versions add vertexai-api-key \
  --data-file=- \
  --project=servicenow-ai-477221

# Verify secrets
gcloud secrets list --project=servicenow-ai-477221
```

### Step 4.2: Deploy LLM Infrastructure

See **[FOUNDATIONAL_MODELS_QUICKSTART.md](../../../FOUNDATIONAL_MODELS_QUICKSTART.md)** for detailed LLM deployment.

**Quick Deploy:**
```bash
cd ../../k8s/llm-serving

# Deploy KServe runtime
kubectl apply -f kserve-runtime.yaml

# Deploy self-hosted models
kubectl apply -f self-hosted-models.yaml

# Deploy cloud model integrations
kubectl apply -f foundational-models.yaml

# Deploy hybrid router
kubectl apply -f hybrid-routing.yaml

# Wait for readiness
kubectl wait --for=condition=ready pod \
  -l app=llm-router \
  -n production \
  --timeout=300s
```

### Step 4.3: Deploy Microservices

```bash
cd ../deployments

# Deploy in order (respecting dependencies)

# 1. Core services
kubectl apply -f conversation-manager-deployment.yaml
kubectl apply -f llm-gateway-deployment.yaml

# 2. Data services
kubectl apply -f knowledge-base-deployment.yaml

# 3. Integration services
kubectl apply -f ticket-monitor-deployment.yaml
kubectl apply -f action-executor-deployment.yaml
kubectl apply -f notification-service-deployment.yaml

# 4. Supporting services
kubectl apply -f document-ingestion-deployment.yaml
kubectl apply -f analytics-service-deployment.yaml

# 5. API Gateway
kubectl apply -f api-gateway-deployment.yaml

# 6. Web UI
kubectl apply -f internal-web-ui-deployment.yaml

# Verify all pods running
kubectl get pods -n production

# Expected: All pods STATUS=Running
```

### Step 4.4: Deploy Services & Ingress

```bash
# Deploy Kubernetes services
kubectl apply -f ../services/

# Verify services
kubectl get services -n production

# Deploy ingress (if using)
kubectl apply -f ../ingress/
```

---

## Phase 5: Verification & Testing

**Duration:** 10-15 minutes

### Step 5.1: Infrastructure Health Checks

```bash
# GKE Cluster
gcloud container clusters describe dev-ai-agent-gke \
  --location=europe-west2-a \
  --format="value(status)"
# Expected: RUNNING

# Node health
kubectl get nodes -o wide
kubectl top nodes

# Cloud SQL
gcloud sql instances describe dev-postgres \
  --format="value(state)"
# Expected: RUNNABLE

# Redis
gcloud redis instances describe dev-redis \
  --region=europe-west2 \
  --format="value(state)"
# Expected: READY
```

### Step 5.2: Kubernetes Resource Checks

```bash
# All pods running
kubectl get pods -n production
kubectl get pods -n monitoring

# No failed pods
kubectl get pods -n production --field-selector=status.phase!=Running

# Service accounts
kubectl get sa -n production

# Network policies
kubectl get networkpolicies -n production

# Secrets accessible (via pod)
kubectl run test-secret --rm -it \
  --image=google/cloud-sdk:slim \
  --serviceaccount=conversation-manager-sa \
  --namespace=production \
  -- gcloud secrets versions access latest --secret=openai-api-key
```

### Step 5.3: Workload Identity Verification

```bash
# Test workload identity
kubectl run -it --rm test-wi \
  --image=google/cloud-sdk:slim \
  --serviceaccount=conversation-manager-sa \
  --namespace=production \
  -- gcloud auth list

# Expected output: conversation-manager@PROJECT.iam.gserviceaccount.com

# Test GCS access
kubectl run -it --rm test-gcs \
  --image=google/cloud-sdk:slim \
  --serviceaccount=conversation-manager-sa \
  --namespace=production \
  -- gsutil ls gs://servicenow-ai-477221-knowledge-documents-dev/
```

### Step 5.4: Application Testing

```bash
# Test LLM endpoint
kubectl port-forward -n production svc/hybrid-llm-router 9090:9090 &

# Send test request
curl -X POST http://localhost:9090/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "auto",
    "messages": [{"role": "user", "content": "Hello, test message"}]
  }'

# Expected: JSON response with completion

# Test API gateway
kubectl port-forward -n production svc/api-gateway 8080:8080 &

curl http://localhost:8080/health
# Expected: {"status": "healthy"}

# Stop port forwards
pkill -f "kubectl port-forward"
```

### Step 5.5: Run Smoke Tests

```bash
# Deploy smoke test pod
cd ../../scripts
./run-smoke-tests.sh

# Expected: All tests PASS
```

---

## Post-Deployment Tasks

### Task 1: Create Billing Budget Manually

Since billing budget module was commented out due to quota project issues:

1. Go to [GCP Console → Billing → Budgets](https://console.cloud.google.com/billing/budgets)
2. Click **Create Budget**
3. Configure:
   - **Name:** dev-monthly-budget
   - **Projects:** servicenow-ai-477221
   - **Time range:** Monthly
   - **Budget amount:** $20 USD
   - **Threshold alerts:** 50%, 80%, 100%
   - **Email recipients:** your-email@example.com
4. Click **Finish**

### Task 2: Set Up Monitoring Dashboards

```bash
cd terraform/monitoring
terraform init
terraform apply

# Creates dashboards for:
# - Infrastructure overview
# - Application health
# - Security events
# - Cost analysis
```

### Task 3: Configure Alerting

```bash
# Create alert policies
cd ../../scripts
./setup-alerting.sh

# Alerts for:
# - Pod crashes
# - High error rates
# - Resource exhaustion
# - Security events
```

### Task 4: Document Deployment

```bash
# Save deployment details
cat > DEPLOYMENT_INFO.txt <<EOF
Deployment Date: $(date)
Environment: Development
Region: europe-west2-a
Project ID: servicenow-ai-477221
Cluster: dev-ai-agent-gke
Terraform Version: $(terraform version)
Kubernetes Version: $(kubectl version --short)
EOF

# Commit to repository
git add DEPLOYMENT_INFO.txt
git commit -m "docs: add deployment information"
git push
```

### Task 5: Schedule Backups

```bash
# Enable Cloud SQL backups
gcloud sql instances patch dev-postgres \
  --backup-start-time=03:00 \
  --backup-location=europe-west2 \
  --enable-point-in-time-recovery

# Create snapshot schedule for GKE
# (via GCP Console → Kubernetes Engine → Backups)
```

---

## Troubleshooting

### Common Issues & Solutions

#### Issue 1: Terraform Apply Fails with SSD Quota Error

**Error:**
```
Error 403: Insufficient regional quota to satisfy request:
resource "SSD_TOTAL_GB": request requires '300.0'
```

**Solution:**
Already fixed - dev environment uses zonal cluster. If you see this:
1. Verify you're in `terraform/environments/dev`
2. Check `main.tf` line 35: should be `region = "europe-west2-a"`
3. Re-run `terraform apply`

#### Issue 2: GKE Cluster Not Accessible

**Error:**
```
Unable to connect to the server: dial tcp: lookup on ...: no such host
```

**Solution:**
```bash
# Re-fetch credentials
gcloud container clusters get-credentials dev-ai-agent-gke \
  --location=europe-west2-a \
  --project=servicenow-ai-477221

# Check cluster status
gcloud container clusters describe dev-ai-agent-gke \
  --location=europe-west2-a
```

#### Issue 3: Pod Crashes with Permission Denied

**Error:**
```
Error: googleapi: Error 403: Permission denied on resource
```

**Solution:**
```bash
# Verify workload identity annotation
kubectl get sa SERVICE_ACCOUNT -n production -o yaml

# Check IAM binding
gcloud iam service-accounts get-iam-policy \
  SERVICE_ACCOUNT@PROJECT.iam.gserviceaccount.com

# Re-create binding if missing
gcloud iam service-accounts add-iam-policy-binding \
  SERVICE_ACCOUNT@PROJECT.iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:PROJECT.svc.id.goog[production/k8s-sa]"
```

#### Issue 4: Cloud SQL Connection Failed

**Error:**
```
Error: dial tcp: lookup dev-postgres on ...: no such host
```

**Solution:**
```bash
# Verify Cloud SQL instance
gcloud sql instances describe dev-postgres

# Check private IP
gcloud sql instances describe dev-postgres \
  --format="value(ipAddresses[0].ipAddress)"

# Verify private service connection
gcloud services vpc-peerings list \
  --network=dev-core
```

#### Issue 5: Secrets Not Accessible

**Error:**
```
Error: Secret "openai-api-key" not found
```

**Solution:**
```bash
# Verify secret exists
gcloud secrets describe openai-api-key

# Check IAM permissions
gcloud secrets get-iam-policy openai-api-key

# Grant access to service account
gcloud secrets add-iam-policy-binding openai-api-key \
  --member="serviceAccount:SA@PROJECT.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

### Debug Commands

```bash
# View Terraform state
terraform show

# Check specific resource
terraform state show module.gke.google_container_cluster.primary

# Kubernetes logs
kubectl logs -f POD_NAME -n production

# Describe pod (events section)
kubectl describe pod POD_NAME -n production

# Execute in pod
kubectl exec -it POD_NAME -n production -- /bin/sh

# Check node resources
kubectl describe nodes

# View all events
kubectl get events -n production --sort-by='.lastTimestamp'
```

---

## Rollback Procedures

### Rollback Kubernetes Deployment

```bash
# Rollback specific deployment
kubectl rollout undo deployment/DEPLOYMENT_NAME -n production

# Rollback to specific revision
kubectl rollout history deployment/DEPLOYMENT_NAME -n production
kubectl rollout undo deployment/DEPLOYMENT_NAME --to-revision=2 -n production

# Verify rollback
kubectl rollout status deployment/DEPLOYMENT_NAME -n production
```

### Rollback Terraform Changes

```bash
# Option 1: Apply previous state
cd terraform/environments/dev
cp terraform.tfstate.backup terraform.tfstate
terraform apply

# Option 2: Destroy and recreate
terraform destroy -target=module.PROBLEMATIC_MODULE
terraform apply

# Option 3: Full rollback (CAUTION: destroys everything)
terraform destroy
```

### Emergency Procedures

**Complete Infrastructure Teardown:**
```bash
# 1. Delete Kubernetes resources
kubectl delete namespace production --wait=false
kubectl delete namespace monitoring --wait=false

# 2. Destroy Terraform infrastructure
cd terraform/environments/dev
terraform destroy -auto-approve

# 3. Clean up manual resources
gcloud compute disks list --filter="name~'gke-dev-ai-agent-gke'" --format="value(name)" | \
  xargs -I {} gcloud compute disks delete {} --quiet

# 4. Verify cleanup
gcloud container clusters list
gcloud sql instances list
gcloud storage buckets list
```

---

## Success Criteria

Deployment is successful when:

- ✅ All Terraform resources created (0 errors)
- ✅ GKE cluster STATUS=RUNNING
- ✅ Cloud SQL instance STATE=RUNNABLE
- ✅ All 10 pods STATUS=Running
- ✅ Workload Identity tests pass
- ✅ LLM endpoint returns responses
- ✅ API gateway health check returns 200
- ✅ No error logs in past 5 minutes
- ✅ Monitoring dashboards populated
- ✅ Billing budget created

---

## Next Steps

After successful deployment:

1. **Configure CI/CD Pipeline**
   - See `.github/workflows/deploy.yml`
   - Set up Workload Identity Federation for GitHub Actions

2. **Enable Monitoring**
   - Configure Cloud Monitoring dashboards
   - Set up alerting policies
   - Enable uptime checks

3. **Security Hardening**
   - Enable Binary Authorization
   - Configure Cloud Armor WAF
   - Set up VPC Flow Logs

4. **Performance Optimization**
   - Configure horizontal pod autoscaling
   - Optimize node pool sizes
   - Enable cluster autoscaling

5. **Deploy to Staging**
   - Replicate to `terraform/environments/staging`
   - Use regional cluster for HA
   - Increase resource limits

---

## Additional Resources

- [DEPLOYMENT_SUMMARY.md](DEPLOYMENT_SUMMARY.md) - Detailed resource list
- [TROUBLESHOOTING.md](../../docs/TROUBLESHOOTING.md) - Extended troubleshooting guide
- [ZERO_SERVICE_ACCOUNT_KEYS.md](../../docs/ZERO_SERVICE_ACCOUNT_KEYS.md) - Security documentation
- [FOUNDATIONAL_MODELS_QUICKSTART.md](../../../FOUNDATIONAL_MODELS_QUICKSTART.md) - LLM deployment
- [../../README.md](../../../README.md) - Main project documentation

---

## Support

If you encounter issues not covered in this runbook:

1. Check the [Troubleshooting Guide](../../docs/TROUBLESHOOTING.md)
2. Review [GitHub Issues](https://github.com/YOUR_ORG/servicenow-ai/issues)
3. Contact the infrastructure team
4. Open a new issue with:
   - Terraform version
   - GCP project ID
   - Error messages
   - Steps to reproduce

---

**End of Runbook**

✅ You're now ready to deploy ServiceNow AI infrastructure!
