# ServiceNow AI Infrastructure

Production-ready Google Cloud Platform infrastructure for a ServiceNow AI Agent system using Terraform and Kubernetes.

---

## Overview

This repository contains the complete infrastructure-as-code setup for deploying a secure, scalable AI agent system on GCP. The infrastructure is designed with zero-trust security, automated releases, and comprehensive CI/CD pipelines.

### Key Features

- **Multi-environment setup** - Dev, Staging, and Production configurations
- **Zero-trust security** - Default-deny firewall rules and NetworkPolicy enforcement
- **Workload Identity** - Keyless authentication for pods and CI/CD
- **Automated releases** - Release Please for version management
- **Comprehensive testing** - Terraform tests for all modules
- **Production-ready** - Security hardening and compliance built-in

---

## Architecture

### Infrastructure Components

**Compute & Orchestration**
- GKE (Google Kubernetes Engine) - Private cluster with Workload Identity
- 4 specialized node pools (general, AI workloads, vector search, batch processing)
- Autopilot mode support with cost optimization

**Networking**
- VPC with private subnets and Cloud NAT
- Zero-trust firewall rules (default-deny with explicit allows)
- Kubernetes NetworkPolicy for pod-to-pod isolation
- Cloud Armor for DDoS protection and WAF

**Data Storage**
- Cloud SQL (PostgreSQL 14) - Private network with CMEK encryption
- Firestore - Native mode for document storage
- Cloud Storage - Encrypted buckets with lifecycle policies
- Redis - In-memory caching and session management

**AI & ML**
- Vertex AI - LLM integration and model serving
- Vertex AI Matching Engine - Vector similarity search
- Custom embeddings pipeline

**Security & Identity**
- KMS - Customer-managed encryption keys with 90-day rotation
- Secret Manager - Centralized secrets storage
- Workload Identity - Pod-to-GCP authentication without keys
- Workload Identity Federation - GitHub Actions keyless CI/CD
- Binary Authorization - Container image verification

**Messaging & Events**
- Pub/Sub - Asynchronous message queue
- Topic-based event routing
- Dead letter queues

### Microservices

1. **conversation-manager** - Orchestrates conversation flow
2. **llm-gateway** - LLM API integration and rate limiting
3. **knowledge-base** - Vector search and document retrieval
4. **ticket-monitor** - ServiceNow ticket monitoring
5. **action-executor** - Execute actions in ServiceNow
6. **notification-service** - Multi-channel notifications
7. **internal-web-ui** - Administrative dashboard
8. **api-gateway** - External API endpoint
9. **analytics-service** - Usage analytics and reporting
10. **document-ingestion** - Document processing pipeline

---

## Project Structure

```
.
├── terraform/
│   ├── environments/
│   │   ├── dev/          # Development environment
│   │   ├── staging/      # Staging environment
│   │   └── prod/         # Production environment
│   └── modules/
│       ├── gke/          # GKE cluster module
│       ├── vpc/          # VPC networking module
│       ├── cloudsql/     # Cloud SQL database module
│       ├── kms/          # KMS encryption module
│       ├── storage/      # Cloud Storage module
│       ├── pubsub/       # Pub/Sub messaging module
│       ├── firestore/    # Firestore database module
│       ├── vertex_ai/    # Vertex AI module
│       ├── secret_manager/  # Secret Manager module
│       ├── redis/        # Redis cache module
│       ├── workload_identity/  # Workload Identity module
│       └── workload_identity_federation/  # GitHub Actions WIF
├── k8s/
│   ├── deployments/      # Kubernetes deployments
│   ├── service-accounts/ # ServiceAccounts with Workload Identity
│   ├── network-policies/ # NetworkPolicy resources
│   └── pod-security/     # Pod Security Standards
├── .github/
│   └── workflows/        # GitHub Actions CI/CD
├── docs/                 # Additional documentation
└── scripts/              # Utility scripts
```

---

## Prerequisites

### Required Tools

- **Terraform** >= 1.0
- **Google Cloud SDK** (gcloud)
- **kubectl** - Kubernetes CLI
- **Docker** - Container runtime
- **GitHub CLI** (gh) - Optional but recommended

### GCP Requirements

- GCP project with billing enabled
- Required APIs enabled:
  - compute.googleapis.com
  - container.googleapis.com
  - sqladmin.googleapis.com
  - cloudkms.googleapis.com
  - secretmanager.googleapis.com
  - artifactregistry.googleapis.com
  - pubsub.googleapis.com
  - firestore.googleapis.com
  - aiplatform.googleapis.com

### Permissions

- Project Owner or the following roles:
  - Compute Admin
  - Kubernetes Engine Admin
  - Service Account Admin
  - Security Admin

---

## Quick Start

### 1. Clone Repository

```bash
git clone https://github.com/YOUR_ORG/servicenow-ai.git
cd servicenow-ai
```

### 2. Configure GCP Credentials

```bash
# Authenticate
gcloud auth application-default login

# Set project
gcloud config set project YOUR_PROJECT_ID
```

### 3. Initialize Terraform

```bash
cd terraform/environments/dev

# Create terraform.tfvars
cat > terraform.tfvars <<EOF
project_id      = "your-project-id"
region          = "europe-west2"
billing_account = "XXXXXX-XXXXXX-XXXXXX"
github_org      = "your-github-org"
github_repo     = "servicenow-ai"
EOF

# Initialize
terraform init

# Plan
terraform plan -var-file=terraform.tfvars

# Apply
terraform apply -var-file=terraform.tfvars
```

### 4. Configure Kubernetes

```bash
# Get GKE credentials
gcloud container clusters get-credentials dev-ai-agent-gke \
  --region europe-west2 \
  --project YOUR_PROJECT_ID

# Update ServiceAccount annotations
sed -i 's/PROJECT_ID/your-project-id/g' ../../k8s/service-accounts/all-service-accounts.yaml

# Apply Kubernetes resources
kubectl apply -f ../../k8s/service-accounts/
kubectl apply -f ../../k8s/network-policies/
kubectl apply -f ../../k8s/pod-security/
```

### 5. Verify Deployment

```bash
# Check Terraform outputs
terraform output

# Verify Kubernetes resources
kubectl get serviceaccounts -n production
kubectl get networkpolicies -n production

# Test Workload Identity
kubectl run -it --rm test-wi \
  --image=google/cloud-sdk:slim \
  --serviceaccount=conversation-manager-sa \
  --namespace=production \
  -- gcloud auth list
```

---

## Configuration

### Environment Variables

Each environment (`dev`, `staging`, `prod`) uses a `terraform.tfvars` file:

```hcl
project_id      = "your-gcp-project-id"
region          = "europe-west2"
billing_account = "XXXXXX-XXXXXX-XXXXXX"

# GKE Configuration
gke_master_cidr = "172.16.0.0/28"

# GitHub Integration (for Workload Identity Federation)
github_org  = "your-github-org"
github_repo = "servicenow-ai"
```

### Module Configuration

Modules are configured in the environment's `main.tf`:

```hcl
module "gke" {
  source = "../../modules/gke"

  project_id              = var.project_id
  region                  = var.region
  network                 = module.vpc.network_self_link
  subnetwork              = values(module.vpc.subnet_self_links)[0]
  cluster_name            = "dev-ai-agent-gke"
  master_ipv4_cidr_block  = var.gke_master_cidr
  authorized_master_cidrs = []

  # Node pool configurations
  general_pool_size = { min = 2, max = 10 }
  ai_pool_size      = { min = 1, max = 5 }
  vector_pool_size  = { min = 1, max = 5 }
}
```

---

## Security

### Zero-Trust Architecture

**Network Security**
- Default-deny firewall rules on all VPCs
- Explicit allow rules for required traffic
- Private GKE cluster (no public endpoint)
- Authorized networks for kubectl access
- Cloud Armor WAF with rate limiting

**Pod Security**
- Pod Security Standards (restricted profile)
- NetworkPolicy enforcement (default-deny)
- Non-root containers required
- Read-only root filesystem
- No privilege escalation
- Capabilities dropped

**Data Encryption**
- Customer-managed encryption keys (CMEK)
- KMS keys with 90-day rotation
- Encryption at rest for all data stores
- TLS/SSL for data in transit
- mTLS via Istio service mesh

**Identity & Access**
- Workload Identity for pod authentication
- No service account keys
- Least-privilege IAM roles per service
- Workload Identity Federation for CI/CD
- Audit logging enabled

### Security Scanning

```bash
# Terraform security scan
terraform validate

# Container scanning (in CI/CD)
gcloud container images scan IMAGE_URL

# Binary Authorization
gcloud beta container binauthz attestations sign-and-create
```

### Compliance

- SOC 2 Type II compliance ready
- GDPR compliant (EU data residency)
- Audit logs for all operations
- Secrets rotation automated
- Security monitoring enabled

---

## Testing

### Terraform Tests

All modules include comprehensive tests:

```bash
# Run all module tests
cd terraform/modules/gke
terraform test

# Run specific module
cd terraform/modules/vpc
terraform test

# Validate all modules
terraform validate
```

### Integration Tests

```bash
# Deploy to dev environment
cd terraform/environments/dev
terraform apply -var-file=terraform.tfvars

# Run smoke tests
kubectl apply -f ../../k8s/test/smoke-tests.yaml

# Check pod health
kubectl get pods -n production
kubectl logs -n production <pod-name>
```

### Test Results

All tests passing (11/11 modules):
- GKE Module - PASS
- VPC Module - PASS
- CloudSQL Module - PASS
- KMS Module - PASS
- Storage Module - PASS
- Pub/Sub Module - PASS
- Firestore Module - PASS
- Workload Identity - PASS (validation)
- All other modules - PASS

See [TERRAFORM_TEST_RESULTS.md](TERRAFORM_TEST_RESULTS.md) for details.

---

## Deployment

### CI/CD Pipeline

GitHub Actions workflow for automated deployments:

```yaml
# .github/workflows/deploy.yml
- Authenticate with Workload Identity Federation
- Build container images
- Sign with Binary Authorization
- Deploy to GKE
- Run smoke tests
- Notify on completion
```

### Deployment Checklist

**Pre-deployment**
- [ ] Terraform plan reviewed and approved
- [ ] Tests passing in CI/CD
- [ ] Security scan completed
- [ ] Change request approved

**Deployment**
- [ ] Deploy to dev environment
- [ ] Run integration tests
- [ ] Deploy to staging
- [ ] Run smoke tests
- [ ] Deploy to production
- [ ] Monitor for 24 hours

**Post-deployment**
- [ ] Verify all services healthy
- [ ] Check monitoring dashboards
- [ ] Review audit logs
- [ ] Update documentation

### Rollback Procedure

```bash
# Rollback deployment
kubectl rollout undo deployment/<deployment-name> -n production

# Rollback Terraform changes
cd terraform/environments/prod
terraform apply -var-file=terraform.tfvars.backup

# Verify rollback
kubectl get pods -n production
kubectl rollout status deployment/<deployment-name> -n production
```

---

## Monitoring

### Logging

All logs sent to Cloud Logging:

```sql
-- View application logs
resource.type="k8s_pod"
resource.labels.namespace_name="production"
severity>=WARNING

-- View Workload Identity usage
protoPayload.authenticationInfo.principalEmail=~".*@PROJECT.iam.gserviceaccount.com"

-- View permission denied errors
protoPayload.status.code=7
```

### Metrics

Key metrics tracked:
- Pod CPU/Memory utilization
- Request latency (p50, p95, p99)
- Error rates by service
- API quota usage
- KMS key usage

### Alerts

Configured alerts:
- Pod crashes or restarts
- High error rates
- Resource exhaustion
- Security events
- Budget thresholds

### Dashboards

- Infrastructure Overview
- Service Health
- Security & Compliance
- Cost Analysis

---

## Release Management

This project uses [Release Please](https://github.com/googleapis/release-please) for automated releases.

### Creating a Release

1. **Make changes with conventional commits**:
   ```bash
   git commit -m "feat(gke): add autopilot support"
   ```

2. **Push to main**:
   ```bash
   git push origin main
   ```

3. **Release Please creates PR automatically**

4. **Merge PR to create release**:
   ```bash
   gh pr merge <PR_NUMBER> --squash
   ```

### Commit Format

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Types**:
- `feat:` - New feature (minor version bump)
- `fix:` - Bug fix (patch version bump)
- `feat!:` - Breaking change (major version bump)
- `docs:` - Documentation changes
- `refactor:` - Code refactoring
- `test:` - Test updates

### Version Management

Packages are versioned independently:
- Infrastructure: v0.1.0
- GKE Module: v1.0.0
- VPC Module: v1.0.0
- CloudSQL Module: v1.0.0
- KMS Module: v1.0.0
- Workload Identity Module: v1.0.0

See [RELEASE_MANAGEMENT.md](RELEASE_MANAGEMENT.md) for details.

---

## Contributing

We welcome contributions! Please read our [Contributing Guide](CONTRIBUTING.md) for details on:

- Conventional commit format
- Development workflow
- Pull request process
- Testing requirements
- Code style guidelines

### Development Setup

```bash
# Clone repository
git clone https://github.com/YOUR_ORG/servicenow-ai.git
cd servicenow-ai

# Install pre-commit hooks
pre-commit install

# Run tests
terraform fmt -check -recursive
terraform validate
```

### Submitting Changes

1. Create a feature branch
2. Make changes following conventional commits
3. Run tests locally
4. Submit pull request
5. Wait for CI/CD checks
6. Request review

---

## Troubleshooting

### Common Issues

**Terraform State Lock**
```bash
# Force unlock (use with caution)
terraform force-unlock LOCK_ID
```

**GKE Access Issues**
```bash
# Refresh credentials
gcloud container clusters get-credentials CLUSTER_NAME \
  --region REGION --project PROJECT_ID
```

**Workload Identity Not Working**
```bash
# Verify annotation
kubectl get sa SERVICE_ACCOUNT -n NAMESPACE -o yaml

# Check IAM binding
gcloud iam service-accounts get-iam-policy \
  SERVICE_ACCOUNT@PROJECT.iam.gserviceaccount.com
```

**Pod Security Violations**
```bash
# Check pod events
kubectl describe pod POD_NAME -n NAMESPACE

# View security context
kubectl get pod POD_NAME -n NAMESPACE -o yaml | grep -A 10 securityContext
```

### Debug Commands

```bash
# View Terraform state
terraform show

# Check resource
terraform state show MODULE.RESOURCE

# View logs
kubectl logs -f POD_NAME -n NAMESPACE

# Execute in pod
kubectl exec -it POD_NAME -n NAMESPACE -- /bin/bash

# Port forward
kubectl port-forward POD_NAME LOCAL_PORT:POD_PORT -n NAMESPACE
```

### Getting Help

- Read the [documentation](docs/)
- Check [troubleshooting guide](docs/TROUBLESHOOTING.md)
- Open an [issue](https://github.com/YOUR_ORG/servicenow-ai/issues)
- Contact the team

---

## Documentation

### Core Documentation

- [CHANGELOG.md](CHANGELOG.md) - Version history
- [CONTRIBUTING.md](CONTRIBUTING.md) - Contribution guidelines
- [RELEASE_MANAGEMENT.md](RELEASE_MANAGEMENT.md) - Release process
- [SECURITY_IMPLEMENTATION_SUMMARY.md](SECURITY_IMPLEMENTATION_SUMMARY.md) - Security details
- [WORKLOAD_IDENTITY_IMPLEMENTATION.md](WORKLOAD_IDENTITY_IMPLEMENTATION.md) - Workload Identity guide

### Testing Documentation

- [TERRAFORM_TEST_RESULTS.md](TERRAFORM_TEST_RESULTS.md) - Test results
- [HOW_TO_TEST_RELEASE_PLEASE.md](HOW_TO_TEST_RELEASE_PLEASE.md) - Release testing
- [TESTING_SUMMARY.md](TESTING_SUMMARY.md) - Quick test guide

### Implementation Guides

- [terraform/FIXES_APPLIED.md](terraform/FIXES_APPLIED.md) - Infrastructure fixes
- [terraform/SECURITY_IMPROVEMENTS.md](terraform/SECURITY_IMPROVEMENTS.md) - Security enhancements

---

## Roadmap

### Planned Features

**Infrastructure**
- [ ] Multi-region deployment
- [ ] Disaster recovery automation
- [ ] Advanced auto-scaling
- [ ] Cost optimization policies

**Security**
- [ ] Binary Authorization enforcement
- [ ] Secrets rotation automation
- [ ] VPC Flow Logs analysis
- [ ] Private Service Connect

**Observability**
- [ ] Distributed tracing
- [ ] Custom dashboards
- [ ] SLO/SLI tracking
- [ ] Automated incident response

**AI/ML**
- [ ] Model versioning
- [ ] A/B testing framework
- [ ] Feature store
- [ ] ML pipeline automation

---

## License

This project is proprietary and confidential.

---

## Acknowledgments

- Google Cloud Platform
- Terraform by HashiCorp
- Kubernetes community
- Release Please by Google

---

## Contact

- Project Lead: [name@example.com](mailto:name@example.com)
- Team: [team@example.com](mailto:team@example.com)
- Issues: [GitHub Issues](https://github.com/YOUR_ORG/servicenow-ai/issues)

---

## Status

**Infrastructure**: Fully configured and tested
**Security**: Hardened and compliant
**CI/CD**: Automated with GitHub Actions
**Documentation**: Comprehensive and up-to-date
