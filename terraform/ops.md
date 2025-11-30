⏺ 🚀 Local Deployment Guide with Terraform

Here's how to deploy the infrastructure to GCP from your local machine:

Prerequisites

1. Install Required Tools

# Terraform

brew install terraform # macOS

# or download from https://www.terraform.io/downloads

# Google Cloud SDK

brew install google-cloud-sdk # macOS

# or follow: https://cloud.google.com/sdk/docs/install

# kubectl

brew install kubectl # macOS

# Verify installations

terraform --version # Should be >= 1.0 gcloud --version kubectl version --client

2. Configure GCP Authentication

# Login to GCP

gcloud auth login

# Set application default credentials (for Terraform)

gcloud auth application-default login

# Set your project

gcloud config set project servicenow-ai-477221

# Verify authentication

gcloud auth list

3. Enable Required APIs

# Enable all necessary GCP APIs

gcloud services enable \
 compute.googleapis.com \
 container.googleapis.com \
 sqladmin.googleapis.com \
 cloudkms.googleapis.com \
 secretmanager.googleapis.com \
 artifactregistry.googleapis.com \
 pubsub.googleapis.com \
 firestore.googleapis.com \
 aiplatform.googleapis.com \
 redis.googleapis.com \
 servicenetworking.googleapis.com \
 cloudresourcemanager.googleapis.com \
 iam.googleapis.com \
 cloudbilling.googleapis.com

# Wait for APIs to be enabled (takes ~2 minutes)

sleep 120

Deployment Steps

1. Navigate to Environment

cd /Users/eray/servicenow-ai/terraform/environments/dev

2. Review Configuration

The terraform.tfvars file already exists with your settings: project_id =
"servicenow-ai-477221" region = "europe-west2" billing_account =
"012307-BBE074-F2333C" github_org = "erayguner" github_repo = "servicenow-ai"

3. Initialize Terraform

# Initialize Terraform (downloads providers and modules)

terraform init

# Expected output:

# Terraform has been successfully initialized!

4. Validate Configuration

# Validate all Terraform files

terraform validate

# Expected output:

# Success! The configuration is valid.

5. Review What Will Be Created

# Generate and review execution plan

terraform plan -var-file=terraform.tfvars

# This shows all resources that will be created

# Review carefully before proceeding

6. Deploy Infrastructure

# Apply the configuration (creates all resources)

terraform apply -var-file=terraform.tfvars

# You'll be prompted to confirm

# Type 'yes' to proceed

# Deployment takes approximately 15-20 minutes

Post-Deployment Steps

1. Get GKE Cluster Credentials

# Configure kubectl to use your new cluster

gcloud container clusters get-credentials servicenow-ai-dev \
 --region europe-west2 \
 --project servicenow-ai-477221

# Verify cluster access

kubectl get nodes

2. Deploy Kubernetes Resources

# Navigate back to project root

cd /Users/eray/servicenow-ai

# Deploy service accounts (Workload Identity)

kubectl apply -f k8s/service-accounts/all-service-accounts.yaml

# Deploy network policies (security)

kubectl apply -f k8s/network-policies/default-deny.yaml kubectl apply -f
k8s/network-policies/microservices-policies.yaml

# Verify deployments

kubectl get serviceaccounts -n production kubectl get networkpolicies -n
production

3. Deploy LLM Infrastructure (Optional)

# Deploy self-hosted LLM serving

kubectl apply -f k8s/llm-serving/kserve-runtime.yaml kubectl apply -f
k8s/llm-serving/gpu-operator.yaml

# Deploy foundational models integration

kubectl apply -f k8s/llm-serving/foundational-models.yaml

# Deploy hybrid router (recommended)

kubectl apply -f k8s/llm-serving/hybrid-routing.yaml

# Verify LLM deployments

kubectl get pods -n production -l app=llm-router

4. Verify Deployment

# Check all Terraform-created resources

terraform show

# Check GKE cluster

kubectl cluster-info

# Check Workload Identity configuration

kubectl get serviceaccounts -n production -o yaml | grep "iam.gke.io"

# Run security audit

./scripts/audit-workload-identity.sh

Environment-Specific Deployments

Development (already configured)

cd terraform/environments/dev terraform apply -var-file=terraform.tfvars

Staging

cd terraform/environments/staging

# Create terraform.tfvars

cat > terraform.tfvars <<EOF project_id = "servicenow-ai-staging-477221" region
= "europe-west2" billing_account = "012307-BBE074-F2333C" github_org =
"erayguner" github_repo = "servicenow-ai" EOF

terraform init terraform apply -var-file=terraform.tfvars

Production

cd terraform/environments/prod

# Create terraform.tfvars

cat > terraform.tfvars <<EOF project_id = "servicenow-ai-prod-477221" region =
"europe-west2" billing_account = "012307-BBE074-F2333C" github_org = "erayguner"
github_repo = "servicenow-ai" EOF

terraform init terraform apply -var-file=terraform.tfvars

Common Issues & Solutions

Issue 1: API Not Enabled

# Error: "API [service] has not been used in project"

# Solution: Enable the specific API

gcloud services enable SERVICE_NAME.googleapis.com

Issue 2: Insufficient Permissions

# Error: "Permission denied"

# Solution: Ensure you have required roles

gcloud projects add-iam-policy-binding servicenow-ai-477221 \
 --member="user:YOUR_EMAIL" \
 --role="roles/owner"

Issue 3: Quota Exceeded

# Error: "Quota exceeded"

# Solution: Request quota increase in GCP Console

# Navigation: IAM & Admin > Quotas

Issue 4: State Lock

# Error: "State is locked"

# Solution: Force unlock (use with caution)

terraform force-unlock LOCK_ID

Terraform State Management

View State

# List all resources in state

terraform state list

# Show specific resource

terraform state show google_container_cluster.primary

Backend Configuration (Optional - Remote State)

For team collaboration, use remote state:

# Create GCS bucket for state

gsutil mb -p servicenow-ai-477221 -l europe-west2
gs://servicenow-ai-terraform-state

# Enable versioning

gsutil versioning set on gs://servicenow-ai-terraform-state

# Update backend.tf

cat > backend.tf <<EOF terraform { backend "gcs" { bucket =
"servicenow-ai-terraform-state" prefix = "terraform/state" } } EOF

# Migrate state

terraform init -migrate-state

Cleanup / Destroy

Destroy Specific Environment

cd terraform/environments/dev

# Destroy all resources (CAREFUL!)

terraform destroy -var-file=terraform.tfvars

# You'll be prompted to confirm

# Type 'yes' to proceed

Delete Kubernetes Resources First

# Delete LLM infrastructure

kubectl delete -f k8s/llm-serving/hybrid-routing.yaml kubectl delete -f
k8s/llm-serving/foundational-models.yaml kubectl delete -f
k8s/llm-serving/kserve-runtime.yaml

# Delete network policies

kubectl delete -f k8s/network-policies/

# Delete service accounts

kubectl delete -f k8s/service-accounts/

Cost Estimation

Development Environment

- GKE Cluster: ~$100-150/month
- Cloud SQL: ~$50-80/month
- GPUs (if deployed): ~$300-500/month per GPU
- Storage: ~$20-30/month
- Other services: ~$30-50/month
- Total: ~$200-$800/month (depending on GPU usage)

Monitor Costs

# View current costs in GCP Console

# Navigation: Billing > Cost Table

# Or use gcloud

gcloud billing projects describe servicenow-ai-477221

Useful Commands Reference

# Terraform

terraform init # Initialize terraform validate # Validate syntax terraform
plan # Preview changes terraform apply # Apply changes terraform destroy #
Destroy resources terraform state list # List resources terraform output # Show
outputs

# GKE

gcloud container clusters list gcloud container clusters describe
servicenow-ai-dev --region europe-west2 kubectl get nodes kubectl get pods -A
kubectl describe pod POD_NAME

# Debugging

terraform apply -var-file=terraform.tfvars -auto-approve # Skip confirmation
terraform apply -var-file=terraform.tfvars -target=MODULE # Deploy specific
module terraform refresh # Sync state with reality TF_LOG=DEBUG terraform
apply # Verbose logging

Next Steps After Deployment

1. ✅ Configure DNS (if using custom domains)
2. ✅ Set up monitoring (Grafana dashboards)
3. ✅ Configure alerts (PagerDuty, Slack)
4. ✅ Deploy applications (your microservices)
5. ✅ Run tests (./scripts/test-llm-deployment.sh)
6. ✅ Set up CI/CD (GitHub Actions with Workload Identity Federation)

Support & Documentation

- Terraform Docs: terraform/environments/\*/README.md
- LLM Deployment: HYBRID_ROUTING_GUIDE.md
- Security: ZERO_SERVICE_ACCOUNT_KEYS.md
- Quick Start: FOUNDATIONAL_MODELS_QUICKSTART.md

---

Your infrastructure is now ready for deployment! Start with the development
environment and verify everything works before deploying to staging/production.
