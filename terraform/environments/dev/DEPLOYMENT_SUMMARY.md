# ServiceNow AI Infrastructure - Development Environment Deployment Summary

**Date:** 2025-11-04
**Environment:** Development
**Region:** europe-west2-a (London, UK - Zonal)
**Project ID:** servicenow-ai-477221

## ✅ Deployment Status: COMPLETE

All infrastructure components have been successfully deployed and are operational.

## 🏗️ Deployed Resources

### 1. GKE Cluster
- **Name:** dev-ai-agent-gke
- **Location:** europe-west2-a (Zonal cluster)
- **Version:** 1.33.5-gke.1125000
- **Status:** RUNNING
- **Endpoint:** 34.39.29.69
- **Current Nodes:** 1 (general pool)

#### Node Pools
1. **General Pool**
   - Machine Type: n2-standard-4
   - Disk: 50GB pd-standard
   - Min/Max: 1/3 nodes
   - Purpose: General workloads

2. **AI Inference Pool**
   - Machine Type: n1-highmem-8
   - Disk: 50GB pd-ssd
   - Min/Max: 0/1 nodes
   - Taint: workload=ai-inference:NoSchedule
   - Purpose: LLM inference workloads

3. **Vector Pool**
   - Machine Type: n2-highmem-16
   - Disk: 50GB pd-ssd
   - Min/Max: 0/1 nodes
   - Purpose: Vector database operations

### 2. Cloud SQL (PostgreSQL)
- **Instance:** dev-postgres
- **Version:** PostgreSQL 14
- **Tier:** db-custom-4-16384 (4 vCPU, 16GB RAM)
- **Disk:** 50GB SSD
- **Private IP:** 10.105.0.2
- **Status:** RUNNABLE
- **Encryption:** Customer-managed KMS key

#### Databases
- `users` - User management
- `audit_logs` - Security audit logs
- `knowledge_metadata` - Knowledge base metadata
- `action_logs` - Agent action tracking

### 3. VPC Network
- **Network:** dev-core
- **Subnet:** dev-core-us-central1 (10.70.0.0/20)
- **Region:** europe-west2
- **Private Google Access:** Enabled
- **Cloud NAT:** Configured for outbound traffic
- **Private Service Connection:** Enabled for Cloud SQL

#### Secondary IP Ranges
- **Pods:** 10.80.0.0/16
- **Services:** 10.90.0.0/20

### 4. Cloud Storage Buckets
All buckets encrypted with customer-managed KMS keys:
- `servicenow-ai-477221-knowledge-documents-dev` - Knowledge base documents
- `servicenow-ai-477221-document-chunks-dev` - Processed document chunks
- `servicenow-ai-477221-user-uploads-dev` - User file uploads (14-day lifecycle)
- `servicenow-ai-477221-backup-dev` - System backups
- `servicenow-ai-477221-audit-logs-archive-dev` - Archived audit logs

### 5. Pub/Sub Topics
All topics encrypted with customer-managed KMS keys:
- `ticket-events` - ServiceNow ticket event stream
- `notification-requests` - User notification queue
- `knowledge-updates` - Knowledge base update events
- `action-requests` - Agent action requests
- `dead-letter-queue` - Failed message handling

### 6. Redis Cache
- **Instance:** dev-redis
- **Memory:** 1GB
- **Region:** europe-west2
- **Network:** Private VPC connection
- **Purpose:** Session management and caching

### 7. Firestore Database
- **Database:** (default)
- **Location:** eur3
- **Mode:** Native
- **Purpose:** Real-time agent state and coordination

### 8. KMS Encryption Keys
- **Key Ring:** dev-keyring
- **Location:** europe-west2
- **Rotation Period:** 90 days (7776000s)

#### Keys
- `storage` - Cloud Storage encryption
- `pubsub` - Pub/Sub encryption
- `cloudsql` - Cloud SQL encryption
- `secrets` - Secret Manager encryption

### 9. Secret Manager Secrets
Placeholders created for:
- `servicenow-oauth-client-id`
- `servicenow-oauth-client-secret`
- `slack-bot-token`
- `slack-signing-secret`
- `openai-api-key`
- `anthropic-api-key`
- `vertexai-api-key`

## 🔒 Security Features

### Zero-Key Security
- ✅ Workload Identity Federation configured
- ✅ No service account keys used
- ✅ All services use Google-managed identities
- ✅ Customer-managed encryption keys (CMEK) for all data

### Network Security
- ✅ Private GKE cluster with private nodes
- ✅ Network policies enabled (Calico)
- ✅ Cloud SQL with private IP only
- ✅ VPC firewall rules
- ✅ Cloud NAT for controlled egress

### Compliance
- ✅ Binary Authorization enabled
- ✅ Shielded GKE nodes enabled
- ✅ Audit logging configured
- ✅ Data encrypted at rest with CMEK
- ✅ Data encrypted in transit

## 📊 Resource Quotas Used

### SSD Quota (Regional - europe-west2)
- **Total Quota:** 250GB
- **Used:**
  - Cloud SQL: 50GB SSD
  - AI Pool: 50GB SSD (when scaled)
  - Vector Pool: 50GB SSD (when scaled)
- **Available:** 150GB (when pools at minimum)

**Note:** Zonal cluster configuration chosen to stay within SSD quota limits.

## 🔧 Configuration Adjustments Made

### 1. SSD Quota Management
- Changed to zonal cluster (europe-west2-a) instead of regional
- Reduced disk sizes: 100GB → 50GB across all pools
- Changed general pool to pd-standard (doesn't count toward SSD quota)

### 2. Billing Budget
- Commented out billing budget module due to ADC quota project issues
- **Action Required:** Manually create budget in GCP Console
  - Budget amount: $20/month
  - Thresholds: 50%, 80%, 100%

### 3. Maintenance Windows
- Simplified to daily maintenance window at 05:00 UTC
- Removed complex recurring window configuration

## 📝 Next Steps

### 1. Configure kubectl Access
```bash
gcloud container clusters get-credentials dev-ai-agent-gke \
  --location=europe-west2-a \
  --project=servicenow-ai-477221
```

### 2. Populate Secrets
Add actual secret values to Secret Manager:
```bash
# Example for OpenAI API key
echo -n "your-api-key" | gcloud secrets versions add openai-api-key \
  --data-file=- \
  --project=servicenow-ai-477221
```

### 3. Deploy Kubernetes Resources
```bash
# Create service accounts and workload identity bindings
cd ../../k8s
kubectl apply -f service-accounts/
kubectl apply -f network-policies/
```

### 4. Deploy LLM Infrastructure
See `FOUNDATIONAL_MODELS_QUICKSTART.md` for:
- Hybrid routing configuration (self-hosted + cloud models)
- Model deployment scripts
- Testing procedures

### 5. Set Up Monitoring
```bash
# Configure Cloud Monitoring dashboards
cd ../../monitoring
terraform init
terraform apply
```

### 6. Create Manual Billing Budget
1. Go to GCP Console → Billing → Budgets & Alerts
2. Create new budget:
   - Name: dev-monthly-budget
   - Projects: servicenow-ai-477221
   - Amount: $20 USD
   - Thresholds: 50%, 80%, 100%

## 🚨 Important Notes

### Regional vs Zonal Cluster
- **Dev:** Zonal cluster (europe-west2-a) - cost-effective, within quota
- **Staging/Prod:** Regional cluster recommended for HA

### Node Pool Scaling
- General pool starts with 1 node
- AI and Vector pools start at 0 (scale on demand)
- All pools have autoscaling enabled

### Cost Optimization
- Consider using preemptible nodes for dev
- Scale down node pools when not in use
- Review Cloud SQL instance size (4 vCPU may be oversized for dev)

## 📚 Additional Documentation

- Architecture: `../../docs/ARCHITECTURE.md`
- Security: `../../docs/ZERO_SERVICE_ACCOUNT_KEYS.md`
- LLM Deployment: `../../docs/FOUNDATIONAL_MODELS_QUICKSTART.md`
- Operations: `../../docs/OPERATIONS.md`

## ✅ Deployment Validation

```bash
# Verify all resources
terraform show

# Check cluster status
gcloud container clusters describe dev-ai-agent-gke \
  --location=europe-west2-a --project=servicenow-ai-477221

# Check Cloud SQL
gcloud sql instances describe dev-postgres --project=servicenow-ai-477221

# List all storage buckets
gcloud storage buckets list --project=servicenow-ai-477221

# List Pub/Sub topics
gcloud pubsub topics list --project=servicenow-ai-477221
```

---

**Deployment completed successfully!** 🎉

All infrastructure is ready for application deployment.
