# ServiceNow AI Infrastructure - Security Configuration

**Version:** 1.0 **Last Updated:** 2025-11-04 **Security Level:** Zero-Trust
Architecture

---

## Table of Contents

1. [Overview](#overview)
2. [Zero-Key Security Model](#zero-key-security-model)
3. [Encryption at Rest](#encryption-at-rest)
4. [Encryption in Transit](#encryption-in-transit)
5. [Network Security](#network-security)
6. [Authentication & Authorization](#authentication--authorization)
7. [Security Compliance](#security-compliance)
8. [Security Audit](#security-audit)

---

## Overview

This infrastructure implements a **zero-trust security model** with
defense-in-depth principles:

- ✅ **No Service Account Keys** - Workload Identity Federation
- ✅ **Customer-Managed Encryption** - All data encrypted with KMS
- ✅ **Private Networking** - No public endpoints
- ✅ **Network Policies** - Default-deny pod communication
- ✅ **Binary Authorization** - Signed container images only
- ✅ **Audit Logging** - All operations logged
- ✅ **Regular Key Rotation** - 90-day automated rotation

---

## Zero-Key Security Model

### Principle: No Service Account Keys Ever Created

Traditional GCP authentication uses downloaded JSON key files. We **completely
eliminate** this attack vector.

### Implementation Layers

#### 1. Workload Identity for GKE Pods

**How It Works:**

1. Kubernetes ServiceAccount annotated with GCP Service Account
2. GKE metadata server provides temporary credentials
3. No keys stored in pods, secrets, or repositories

**Configuration:**

```yaml
# Kubernetes Service Account
apiVersion: v1
kind: ServiceAccount
metadata:
  name: conversation-manager-sa
  namespace: production
  annotations:
    iam.gke.io/gcp-service-account: conversation-manager@PROJECT.iam.gserviceaccount.com
```

```bash
# IAM Binding
gcloud iam service-accounts add-iam-policy-binding \
  conversation-manager@PROJECT.iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:PROJECT.svc.id.goog[production/conversation-manager-sa]"
```

**Benefits:**

- Credentials rotate automatically every hour
- No key file to leak or compromise
- Permissions managed through IAM
- Pod-level granular access control

#### 2. Workload Identity Federation for CI/CD

**How It Works:**

1. GitHub Actions authenticates using OIDC tokens
2. GCP Workload Identity Pool validates token
3. Temporary credentials issued (1 hour TTL)
4. No long-lived credentials in GitHub Secrets

**Configuration:**

```bash
# Create Workload Identity Pool
gcloud iam workload-identity-pools create github-pool \
  --location=global \
  --display-name="GitHub Actions Pool"

# Create Provider
gcloud iam workload-identity-pools providers create-oidc github-provider \
  --location=global \
  --workload-identity-pool=github-pool \
  --issuer-uri=https://token.actions.githubusercontent.com \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
  --attribute-condition="assertion.repository=='YOUR_ORG/servicenow-ai'"
```

**GitHub Actions Workflow:**

```yaml
# .github/workflows/deploy.yml
permissions:
  id-token: write # Required for OIDC
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: 'projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/providers/github-provider'
          service_account: 'github-actions@PROJECT.iam.gserviceaccount.com'

      # Now authenticated - no keys needed!
      - run: gcloud container clusters list
```

#### 3. Application Default Credentials for Local Development

**How It Works:**

1. Developers authenticate with `gcloud auth application-default login`
2. ADC uses OAuth2 user credentials
3. Temporary tokens cached locally
4. No service account keys needed

**Setup:**

```bash
# Authenticate
gcloud auth application-default login --project=PROJECT_ID

# Set quota project
gcloud auth application-default set-quota-project PROJECT_ID

# Verify
gcloud auth application-default print-access-token
```

### Verification: Zero Keys Audit

```bash
# Check for service account keys (should be EMPTY)
for sa in $(gcloud iam service-accounts list --format="value(email)"); do
  echo "Checking $sa"
  gcloud iam service-accounts keys list --iam-account=$sa --managed-by=user
done

# Expected output: No keys found for any service account
```

---

## Encryption at Rest

### Customer-Managed Encryption Keys (CMEK)

All data encrypted with KMS keys under our control.

#### Key Configuration

**Key Ring:** `dev-keyring` (Location: europe-west2)

**Keys:**

| Key Name   | Purpose        | Rotation Period | Protected Resources |
| ---------- | -------------- | --------------- | ------------------- |
| `storage`  | Cloud Storage  | 90 days         | 5 buckets           |
| `pubsub`   | Pub/Sub topics | 90 days         | 5 topics            |
| `cloudsql` | Cloud SQL      | 90 days         | PostgreSQL instance |
| `secrets`  | Secret Manager | 90 days         | 7 secrets           |

**Terraform Configuration:**

```hcl
# terraform/modules/kms/main.tf
resource "google_kms_key_ring" "ring" {
  name     = "dev-keyring"
  location = "europe-west2"
}

resource "google_kms_crypto_key" "keys" {
  for_each        = var.keys
  name            = each.key
  key_ring        = google_kms_key_ring.ring.id
  rotation_period = "7776000s"  # 90 days

  lifecycle {
    prevent_destroy = true  # Protect from accidental deletion
  }
}
```

#### Google-Managed Service Account Permissions

**Critical:** Google-managed service accounts need KMS permissions

```hcl
# Pub/Sub service account
resource "google_kms_crypto_key_iam_member" "pubsub_key_encrypter" {
  crypto_key_id = google_kms_crypto_key.keys["pubsub"].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-PROJECT_NUMBER@gcp-sa-pubsub.iam.gserviceaccount.com"
}

# Storage service account
resource "google_kms_crypto_key_iam_member" "storage_key_encrypter" {
  crypto_key_id = google_kms_crypto_key.keys["storage"].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-PROJECT_NUMBER@gs-project-accounts.iam.gserviceaccount.com"
}

# Cloud SQL service account
resource "google_kms_crypto_key_iam_member" "cloudsql_key_encrypter" {
  crypto_key_id = google_kms_crypto_key.keys["cloudsql"].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-PROJECT_NUMBER@gcp-sa-cloud-sql.iam.gserviceaccount.com"
}
```

#### Verification

```bash
# List all KMS keys
gcloud kms keys list --location=europe-west2 --keyring=dev-keyring

# Check rotation schedule
gcloud kms keys describe KEY_NAME \
  --location=europe-west2 \
  --keyring=dev-keyring \
  --format="value(rotationPeriod,nextRotationTime)"

# Verify encryption on resources
gcloud storage buckets describe gs://BUCKET_NAME --format="value(encryption)"
gcloud sql instances describe dev-postgres --format="value(diskEncryptionConfiguration)"
```

---

## Encryption in Transit

### TLS/SSL Everywhere

**1. External Traffic:**

- Load Balancer with Google-managed SSL certificates
- TLS 1.3 minimum
- Strong cipher suites only

**2. Internal Traffic:**

- Service mesh (Istio) with mTLS
- Automatic certificate rotation
- Zero-trust pod-to-pod communication

**3. Database Connections:**

- Cloud SQL enforces TLS
- Private IP only (no public endpoint)
- Certificate validation required

**Configuration:**

```yaml
# Istio peer authentication
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  mtls:
    mode: STRICT # Require mTLS for all traffic
```

---

## Network Security

### Multi-Layer Defense

#### 1. VPC-Level Security

**Private Subnets:**

- All resources on private IPs (10.70.0.0/20)
- No direct internet access
- Cloud NAT for controlled egress

**Cloud NAT:**

```hcl
resource "google_compute_router_nat" "nat" {
  name                               = "core-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option            = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
```

**Benefits:**

- Predictable outbound IPs
- No inbound internet access
- Centralized egress control

#### 2. GKE Security

**Private Cluster:**

```hcl
private_cluster_config {
  enable_private_nodes    = true   # Nodes have no public IPs
  enable_private_endpoint = false  # Control plane accessible (with auth)
  master_ipv4_cidr_block  = "172.16.0.0/28"
}
```

**Master Authorized Networks:**

```hcl
master_authorized_networks_config {
  dynamic "cidr_blocks" {
    for_each = var.authorized_master_cidrs
    content {
      cidr_block   = cidr_blocks.value.cidr_block
      display_name = cidr_blocks.value.display_name
    }
  }
}
```

**Network Policies:**

```yaml
# Default deny all traffic
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

**Shielded Nodes:**

```hcl
enable_shielded_nodes = true

# Features:
# - Secure Boot: Only signed boot software
# - vTPM: Integrity monitoring
# - Integrity Monitoring: Detect boot-time attacks
```

#### 3. Cloud SQL Security

**Private IP Only:**

```hcl
ip_configuration {
  ipv4_enabled    = false  # No public IP
  private_network = var.private_network
  require_ssl     = true
}
```

**Authorized Networks:**

- Only VPC can access
- No external connections allowed

#### 4. Firewall Rules

**Default-Deny with Explicit Allows:**

```bash
# View current rules
gcloud compute firewall-rules list --filter="network:dev-core"

# Example explicit allow rule (created by GKE automatically)
gcloud compute firewall-rules describe gke-dev-ai-agent-gke-internal
```

---

## Authentication & Authorization

### IAM Best Practices

#### 1. Least Privilege

Each service account has **only** required permissions:

```hcl
# Conversation Manager - needs Cloud SQL, Secret Manager
resource "google_project_iam_member" "conversation_manager_sql" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:conversation-manager@PROJECT.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "conversation_manager_secrets" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:conversation-manager@PROJECT.iam.gserviceaccount.com"
}

# LLM Gateway - needs Vertex AI only
resource "google_project_iam_member" "llm_gateway_vertex" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:llm-gateway@PROJECT.iam.gserviceaccount.com"
}
```

#### 2. Service Account Separation

| Service              | Service Account              | Permissions        |
| -------------------- | ---------------------------- | ------------------ |
| conversation-manager | conversation-manager@PROJECT | Cloud SQL, Secrets |
| llm-gateway          | llm-gateway@PROJECT          | Vertex AI, Secrets |
| knowledge-base       | knowledge-base@PROJECT       | Storage, Firestore |
| ticket-monitor       | ticket-monitor@PROJECT       | Pub/Sub            |
| action-executor      | action-executor@PROJECT      | Pub/Sub, Secrets   |
| notification-service | notification-service@PROJECT | Pub/Sub            |
| document-ingestion   | document-ingestion@PROJECT   | Storage, Pub/Sub   |
| analytics-service    | analytics-service@PROJECT    | BigQuery, Pub/Sub  |
| api-gateway          | api-gateway@PROJECT          | None (frontend)    |
| internal-web-ui      | internal-web-ui@PROJECT      | None (frontend)    |

#### 3. IAM Conditions (Optional Enhancement)

```hcl
# Time-based access
resource "google_project_iam_binding" "time_restricted" {
  project = var.project_id
  role    = "roles/compute.viewer"
  members = ["serviceAccount:SA@PROJECT.iam.gserviceaccount.com"]

  condition {
    title       = "Business hours only"
    description = "Access restricted to 9-5 UTC"
    expression  = "request.time.getHours('UTC') >= 9 && request.time.getHours('UTC') < 17"
  }
}
```

---

## Security Compliance

### Pod Security Standards (Restricted)

```bash
# Applied to production namespace
kubectl label namespace production \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted
```

**Requirements:**

- ❌ No privileged containers
- ❌ No host namespaces
- ❌ No host ports
- ✅ Non-root user required
- ✅ Read-only root filesystem
- ✅ Drop all capabilities
- ✅ No privilege escalation

**Example Pod Security Context:**

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000
  seccompProfile:
    type: RuntimeDefault
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
```

### Binary Authorization

**Policy:** Only signed images from approved registries

```hcl
binary_authorization {
  evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
}
```

**Implementation:**

1. Build image
2. Sign with Attestor
3. Upload to Artifact Registry
4. Deploy to GKE (verification automatic)

### Audit Logging

**All operations logged:**

```bash
# View admin activity
gcloud logging read "logName:cloudaudit.googleapis.com%2Factivity" \
  --limit=50 \
  --format=json

# View data access
gcloud logging read "logName:cloudaudit.googleapis.com%2Fdata_access" \
  --limit=50 \
  --format=json

# View Workload Identity usage
gcloud logging read 'protoPayload.authenticationInfo.principalEmail=~".*@PROJECT.iam.gserviceaccount.com"' \
  --limit=50
```

**Retention:** 400 days (Audit logs) **Export:** To Cloud Storage bucket
(encrypted)

---

## Security Audit

### Monthly Security Checklist

```bash
#!/bin/bash
# security-audit.sh

echo "=== ServiceNow AI Security Audit ==="
echo "Date: $(date)"
echo ""

# 1. Check for service account keys (should be ZERO)
echo "1. Service Account Keys Check:"
for sa in $(gcloud iam service-accounts list --format="value(email)"); do
  keys=$(gcloud iam service-accounts keys list --iam-account=$sa --managed-by=user --format="value(name)" | wc -l)
  if [ $keys -gt 0 ]; then
    echo "  ❌ ALERT: $sa has $keys keys!"
  fi
done
echo "  ✅ No service account keys found"
echo ""

# 2. Verify KMS key rotation
echo "2. KMS Key Rotation Status:"
for key in storage pubsub cloudsql secrets; do
  next_rotation=$(gcloud kms keys describe $key --location=europe-west2 --keyring=dev-keyring --format="value(nextRotationTime)")
  echo "  $key: Next rotation $next_rotation"
done
echo ""

# 3. Check for public IPs
echo "3. Public IP Check:"
public_ips=$(gcloud compute instances list --format="value(EXTERNAL_IP)" | grep -v "^$" | wc -l)
if [ $public_ips -gt 0 ]; then
  echo "  ⚠️  WARNING: $public_ips instances have public IPs"
else
  echo "  ✅ No public IPs found"
fi
echo ""

# 4. Network policy enforcement
echo "4. Network Policy Check:"
netpols=$(kubectl get networkpolicies -n production --no-headers | wc -l)
echo "  Network policies active: $netpols"
echo ""

# 5. Pod security violations
echo "5. Pod Security Violations:"
violations=$(kubectl get events -n production --field-selector reason=FailedCreate | grep "pod security" | wc -l)
if [ $violations -gt 0 ]; then
  echo "  ⚠️  WARNING: $violations pod security violations"
else
  echo "  ✅ No violations"
fi
echo ""

# 6. Secrets without encryption
echo "6. Unencrypted Secrets Check:"
unencrypted=$(gcloud secrets list --format="value(name)" --filter="replication.automatic.customerManagedEncryption.kmsKeyName:''" | wc -l)
if [ $unencrypted -gt 0 ]; then
  echo "  ⚠️  WARNING: $unencrypted secrets without CMEK"
else
  echo "  ✅ All secrets encrypted with CMEK"
fi
echo ""

echo "=== Audit Complete ==="
```

### Quarterly Security Tasks

- [ ] Review IAM permissions (remove unused)
- [ ] Update container images to latest patches
- [ ] Rotate any remaining static credentials
- [ ] Review firewall rules
- [ ] Update security policies
- [ ] Penetration testing (if applicable)
- [ ] Compliance audit (SOC 2, GDPR)

---

## Security Incident Response

### Detection

**1. Unauthorized Access Attempt:**

```bash
# Alert on failed authentication
gcloud logging read 'protoPayload.status.code=7' --limit=100
```

**2. Privilege Escalation:**

```bash
# Alert on role binding changes
gcloud logging read 'protoPayload.methodName:"setIamPolicy"' --limit=100
```

**3. Data Exfiltration:**

```bash
# Alert on large egress
# (Configured in Cloud Monitoring)
```

### Response Procedures

**1. Isolate:**

```bash
# Revoke compromised service account
gcloud iam service-accounts disable SA@PROJECT.iam.gserviceaccount.com

# Isolate pod
kubectl label pod POD_NAME quarantine=true
kubectl apply -f network-policy-quarantine.yaml
```

**2. Investigate:**

```bash
# Collect logs
kubectl logs POD_NAME -n production > incident-logs.txt
gcloud logging read "resource.labels.pod_name=POD_NAME" > gcp-logs.txt

# Analyze traffic
kubectl get networkpolicies -n production
```

**3. Remediate:**

```bash
# Rotate all credentials
gcloud iam service-accounts keys create new-key.json --iam-account=SA@PROJECT.iam.gserviceaccount.com
# (But we don't use keys! So just restart pods)

# Redeploy compromised workloads
kubectl rollout restart deployment/DEPLOYMENT_NAME -n production

# Update security policies
```

**4. Post-Incident:**

- Document incident
- Update security policies
- Improve detection
- Train team

---

## Security Contacts

- **Security Team:** security@example.com
- **Incident Response:** incident@example.com
- **On-Call:** +1-555-0100

---

**End of Security Configuration Guide**

✅ **Status:** Production-ready zero-trust security implemented
