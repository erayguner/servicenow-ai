# ServiceNow AI Infrastructure - Troubleshooting Guide

**Version:** 1.0
**Last Updated:** 2025-11-04

---

## Table of Contents

1. [Quick Diagnosis](#quick-diagnosis)
2. [Terraform Issues](#terraform-issues)
3. [GKE Cluster Issues](#gke-cluster-issues)
4. [Networking Issues](#networking-issues)
5. [Database Issues](#database-issues)
6. [Security & Authentication](#security--authentication)
7. [Performance Issues](#performance-issues)
8. [Common Error Messages](#common-error-messages)
9. [Debug Tools & Commands](#debug-tools--commands)

---

## Quick Diagnosis

### Is It a Terraform Issue?

**Symptoms:**
- `terraform plan` or `terraform apply` fails
- Resource conflicts or state errors
- Provider authentication errors

**Quick Fix:**
```bash
# Refresh state
terraform refresh

# Verify authentication
gcloud auth application-default login

# Check API enablement
gcloud services list --enabled
```

### Is It a Kubernetes Issue?

**Symptoms:**
- Pods not starting
- CrashLoopBackOff
- ImagePullBackOff
- Permission denied errors

**Quick Fix:**
```bash
# Check pod status
kubectl get pods -n production

# View pod events
kubectl describe pod POD_NAME -n production

# Check logs
kubectl logs POD_NAME -n production
```

### Is It a Networking Issue?

**Symptoms:**
- Cannot connect to services
- DNS resolution failures
- Timeout errors

**Quick Fix:**
```bash
# Test DNS
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default

# Check network policies
kubectl get networkpolicies -n production

# Verify service endpoints
kubectl get endpoints -n production
```

---

## Terraform Issues

### Issue 1: SSD Quota Exceeded

**Error Message:**
```
Error 403: Insufficient regional quota to satisfy request:
resource "SSD_TOTAL_GB": request requires '300.0' and is short '50.0'.
project has a quota of '250.0'
```

**Root Cause:**
- Regional GKE clusters create nodes in multiple zones (3x multiplication)
- Default SSD quota is 250GB per region
- Initial configuration requested 300GB+ total

**Solution (Already Implemented):**
1. Dev environment uses **zonal cluster** (europe-west2-a)
2. Disk sizes reduced to 50GB per pool
3. General pool uses pd-standard (doesn't count toward SSD quota)

**Verify Fix:**
```bash
# Check cluster configuration
grep "region.*=" terraform/environments/dev/main.tf
# Should show: region = "europe-west2-a"

# Check disk types
grep -A 5 "disk_" terraform/modules/gke/main.tf
```

**If Still Encountering:**
```bash
# Request quota increase
gcloud compute regions describe europe-west2 --format="table(quotas)"

# Or switch to pd-standard for more pools
# Edit terraform/modules/gke/main.tf
disk_type = "pd-standard"  # Instead of pd-ssd
```

### Issue 2: Billing Budget Creation Fails

**Error Message:**
```
Error 403: Your application is authenticating by using local
Application Default Credentials. The billingbudgets.googleapis.com
API requires a quota project
```

**Root Cause:**
- Billing Budgets API requires explicit quota project
- ADC (Application Default Credentials) may not have quota project set

**Solution (Already Implemented):**
Billing budget module commented out in `terraform/environments/dev/main.tf`

**Workaround:**
1. Create budget manually in GCP Console
2. Or set quota project and uncomment:
```bash
# Set quota project
gcloud auth application-default set-quota-project PROJECT_ID

# Re-authenticate
gcloud auth application-default login --project=PROJECT_ID

# Uncomment budget module in main.tf
# terraform apply
```

**Manual Creation:**
```bash
# Via gcloud (alternative)
gcloud billing budgets create \
  --billing-account=XXXXXX-XXXXXX-XXXXXX \
  --display-name="dev-monthly-budget" \
  --budget-amount=20USD \
  --threshold-rule=percent=0.5 \
  --threshold-rule=percent=0.8 \
  --threshold-rule=percent=1.0
```

### Issue 3: Cloud SQL Service Account Not Found

**Error Message:**
```
Error: Per-Product Per-Project Service Account is not found for project
```

**Root Cause:**
Cloud SQL service account doesn't exist yet (needs to be created)

**Solution:**
```bash
# Create Cloud SQL service account
gcloud beta services identity create \
  --service=sqladmin.googleapis.com \
  --project=PROJECT_ID

# Wait 30 seconds
sleep 30

# Re-run terraform apply
terraform apply
```

### Issue 4: State Lock Error

**Error Message:**
```
Error: Error acquiring the state lock
Lock Info:
  ID: 1762296516009045
  Path: gs://bucket/terraform.tfstate
  Operation: OperationTypeApply
```

**Root Cause:**
- Previous terraform command interrupted
- Lock file not cleaned up

**Solution:**
```bash
# Wait 5 minutes (locks auto-expire)
sleep 300

# Or force unlock (CAUTION: only if you're sure no other process is running)
terraform force-unlock LOCK_ID

# Example:
terraform force-unlock 1762296516009045
```

**Prevention:**
```bash
# Always use Ctrl+C gracefully to interrupt
# Avoid killing terminal during terraform operations
```

### Issue 5: Resource Already Exists

**Error Message:**
```
Error: resource already exists
  with module.gke.google_container_node_pool.general
```

**Root Cause:**
- Resource created outside Terraform
- Or previous apply partially succeeded
- State file doesn't reflect actual infrastructure

**Solution:**
```bash
# Option 1: Import existing resource
terraform import module.gke.google_container_node_pool.general \
  projects/PROJECT/locations/LOCATION/clusters/CLUSTER/nodePools/POOL

# Option 2: Delete and recreate (if safe)
gcloud container node-pools delete POOL_NAME \
  --cluster=CLUSTER_NAME \
  --location=LOCATION

terraform apply

# Option 3: Refresh state
terraform refresh
terraform apply
```

---

## GKE Cluster Issues

### Issue 1: Cannot Connect to Cluster

**Error Message:**
```
Unable to connect to the server: dial tcp: lookup on ...: no such host
```

**Solution:**
```bash
# Re-fetch credentials
gcloud container clusters get-credentials CLUSTER_NAME \
  --location=LOCATION \
  --project=PROJECT_ID

# For dev (zonal):
gcloud container clusters get-credentials dev-ai-agent-gke \
  --location=europe-west2-a \
  --project=servicenow-ai-477221

# Verify cluster is running
gcloud container clusters describe dev-ai-agent-gke \
  --location=europe-west2-a \
  --format="value(status)"
```

### Issue 2: Nodes Not Ready

**Symptoms:**
```bash
kubectl get nodes
NAME                                   STATUS      ROLES    AGE
gke-dev-ai-agent-gke-general-...      NotReady    <none>   5m
```

**Diagnosis:**
```bash
# Describe node
kubectl describe node NODE_NAME

# Check node logs
gcloud compute ssh NODE_NAME --zone=ZONE -- sudo journalctl -u kubelet -n 100
```

**Common Causes & Solutions:**

| Cause | Solution |
|-------|----------|
| **CNI plugin issue** | Wait 2-3 minutes, auto-resolves |
| **Disk full** | Increase disk size in terraform |
| **Memory pressure** | Scale up node machine type |
| **Network issue** | Check VPC and firewall rules |

### Issue 3: Pod Stuck in Pending

**Symptoms:**
```bash
kubectl get pods -n production
NAME                     READY   STATUS    RESTARTS   AGE
llm-gateway-xxx          0/1     Pending   0          5m
```

**Diagnosis:**
```bash
# Check events
kubectl describe pod llm-gateway-xxx -n production

# Common reasons:
# 1. Insufficient resources
# 2. Node selector mismatch
# 3. PVC not bound
# 4. Image pull issues
```

**Solutions:**

**Insufficient Resources:**
```bash
# Check node capacity
kubectl describe nodes | grep -A 5 "Allocated resources"

# Scale node pool
gcloud container clusters resize dev-ai-agent-gke \
  --node-pool=general-pool \
  --num-nodes=2 \
  --location=europe-west2-a
```

**Node Selector Mismatch:**
```bash
# Check pod node selector
kubectl get pod POD_NAME -n production -o yaml | grep -A 3 nodeSelector

# Check node labels
kubectl get nodes --show-labels

# Fix: Update deployment to match available labels
```

### Issue 4: CrashLoopBackOff

**Symptoms:**
```bash
NAME                     READY   STATUS             RESTARTS   AGE
llm-gateway-xxx          0/1     CrashLoopBackOff   5          10m
```

**Diagnosis:**
```bash
# Check logs
kubectl logs POD_NAME -n production --previous

# Check events
kubectl describe pod POD_NAME -n production

# Common causes:
# - Application error
# - Missing environment variable
# - Wrong command/args
# - Liveness probe failure
```

**Solutions:**

**Application Error:**
```bash
# View detailed logs
kubectl logs POD_NAME -n production --previous --tail=100

# Execute in container (if still running)
kubectl exec -it POD_NAME -n production -- /bin/sh
```

**Missing Environment Variable:**
```bash
# Check environment
kubectl get deployment DEPLOYMENT_NAME -n production -o yaml | grep -A 20 env

# Add missing env var
kubectl set env deployment/DEPLOYMENT_NAME ENV_VAR=value -n production
```

---

## Networking Issues

### Issue 1: Service Not Reachable

**Symptoms:**
- `curl` to service fails
- Connection timeout
- DNS resolution fails

**Diagnosis:**
```bash
# Test DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup SERVICE_NAME.production.svc.cluster.local

# Test connectivity
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- curl http://SERVICE_NAME.production:PORT

# Check service endpoints
kubectl get endpoints SERVICE_NAME -n production
```

**Solutions:**

**No Endpoints:**
```bash
# Service selector doesn't match pods
kubectl get service SERVICE_NAME -n production -o yaml | grep -A 5 selector
kubectl get pods -n production --show-labels

# Fix: Update service selector to match pod labels
kubectl patch service SERVICE_NAME -n production -p '{"spec":{"selector":{"app":"correct-label"}}}'
```

**Network Policy Blocking:**
```bash
# Check network policies
kubectl get networkpolicies -n production

# Temporarily remove (for testing)
kubectl delete networkpolicy POLICY_NAME -n production

# Re-apply with correct rules
kubectl apply -f networkpolicy.yaml
```

### Issue 2: External Traffic Not Reaching Service

**Symptoms:**
- LoadBalancer external IP pending
- Ingress not working
- Cloud Load Balancer health check failing

**Diagnosis:**
```bash
# Check service
kubectl get service SERVICE_NAME -n production

# Check ingress
kubectl get ingress -n production
kubectl describe ingress INGRESS_NAME -n production

# Check firewall rules
gcloud compute firewall-rules list --filter="name~gke"
```

**Solutions:**

**LoadBalancer IP Pending:**
```bash
# Wait up to 5 minutes
# If still pending, check quota
gcloud compute addresses list

# Request quota increase if needed
```

**Health Check Failing:**
```bash
# Check pod readiness probe
kubectl get pod POD_NAME -n production -o yaml | grep -A 10 readinessProbe

# View GCP health check
gcloud compute health-checks list

# Adjust probe settings if needed
```

### Issue 3: Cloud SQL Connection Failed

**Symptoms:**
```
Error: dial tcp: lookup dev-postgres: no such host
```

**Diagnosis:**
```bash
# Check Cloud SQL instance
gcloud sql instances describe dev-postgres --format="value(state,ipAddresses)"

# Check private service connection
gcloud services vpc-peerings list --network=dev-core

# Verify VPC
gcloud compute networks describe dev-core
```

**Solutions:**

**Private IP Not Configured:**
```bash
# Already fixed in terraform/modules/vpc/main.tf
# Verify private service connection exists:
gcloud compute addresses list --global --filter="purpose:VPC_PEERING"

# Should show: dev-core-private-ip
```

**DNS Resolution:**
```bash
# Test from pod
kubectl run -it --rm test-sql --image=postgres:14 --restart=Never -- \
  psql "host=10.105.0.2 dbname=users user=postgres"

# Note: Use private IP (10.x.x.x) not hostname
```

---

## Database Issues

### Issue 1: Cloud SQL Connection Refused

**Error Message:**
```
FATAL: remaining connection slots are reserved for non-replication superuser connections
```

**Cause:** Max connections exceeded

**Solution:**
```bash
# Check current connections
gcloud sql operations list --instance=dev-postgres --limit=10

# Increase max connections (requires restart)
gcloud sql instances patch dev-postgres \
  --database-flags=max_connections=200

# Or scale instance
gcloud sql instances patch dev-postgres \
  --tier=db-custom-8-32768
```

### Issue 2: Firestore Permission Denied

**Error Message:**
```
Error 403: Missing or insufficient permissions
```

**Solution:**
```bash
# Grant Firestore access to service account
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:SA@PROJECT.iam.gserviceaccount.com" \
  --role="roles/datastore.user"

# Verify permissions
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:SA@PROJECT.iam.gserviceaccount.com"
```

---

## Security & Authentication

### Issue 1: Workload Identity Not Working

**Error Message:**
```
Error: google: could not find default credentials
```

**Diagnosis:**
```bash
# Check service account annotation
kubectl get sa SERVICE_ACCOUNT -n production -o yaml | grep iam.gke.io

# Check IAM binding
gcloud iam service-accounts get-iam-policy \
  SA@PROJECT.iam.gserviceaccount.com
```

**Solution:**
```bash
# 1. Verify annotation on K8s SA
kubectl annotate serviceaccount SERVICE_ACCOUNT \
  -n production \
  iam.gke.io/gcp-service-account=SA@PROJECT.iam.gserviceaccount.com \
  --overwrite

# 2. Create IAM binding
gcloud iam service-accounts add-iam-policy-binding \
  SA@PROJECT.iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:PROJECT.svc.id.goog[production/SERVICE_ACCOUNT]"

# 3. Restart pod
kubectl rollout restart deployment/DEPLOYMENT_NAME -n production
```

### Issue 2: Secret Access Denied

**Error Message:**
```
Error 403: Permission 'secretmanager.versions.access' denied
```

**Solution:**
```bash
# Grant access to service account
gcloud secrets add-iam-policy-binding SECRET_NAME \
  --member="serviceAccount:SA@PROJECT.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"

# Verify
gcloud secrets get-iam-policy SECRET_NAME
```

### Issue 3: KMS Encryption Errors

**Error Message:**
```
Error: Cloud KMS key not authorized
```

**Solution (Already Implemented in terraform/modules/kms/main.tf):**
```bash
# Grant KMS permissions to Google-managed service accounts

# For Pub/Sub
gcloud kms keys add-iam-policy-binding KEY_NAME \
  --location=LOCATION \
  --keyring=KEYRING \
  --member="serviceAccount:service-PROJECT_NUMBER@gcp-sa-pubsub.iam.gserviceaccount.com" \
  --role="roles/cloudkms.cryptoKeyEncrypterDecrypter"

# For Storage
gcloud kms keys add-iam-policy-binding KEY_NAME \
  --location=LOCATION \
  --keyring=KEYRING \
  --member="serviceAccount:service-PROJECT_NUMBER@gs-project-accounts.iam.gserviceaccount.com" \
  --role="roles/cloudkms.cryptoKeyEncrypterDecrypter"

# For Cloud SQL
gcloud kms keys add-iam-policy-binding KEY_NAME \
  --location=LOCATION \
  --keyring=KEYRING \
  --member="serviceAccount:service-PROJECT_NUMBER@gcp-sa-cloud-sql.iam.gserviceaccount.com" \
  --role="roles/cloudkms.cryptoKeyEncrypterDecrypter"
```

---

## Performance Issues

### Issue 1: High Pod Memory Usage

**Symptoms:**
```bash
kubectl top pods -n production
NAME                     CPU    MEMORY
llm-gateway-xxx          250m   1500Mi  # OOMKilled risk
```

**Solution:**
```bash
# Increase memory limit
kubectl set resources deployment/llm-gateway \
  -n production \
  --limits=memory=2Gi \
  --requests=memory=1Gi

# Or edit deployment
kubectl edit deployment llm-gateway -n production
```

### Issue 2: Slow Application Response

**Diagnosis:**
```bash
# Check pod resources
kubectl top pods -n production

# Check node resources
kubectl top nodes

# Check Cloud SQL performance
gcloud sql operations list --instance=dev-postgres

# Check Redis latency
gcloud redis instances describe dev-redis \
  --region=europe-west2 \
  --format="value(currentLocationId)"
```

**Solutions:**
- Scale up node pools
- Increase Cloud SQL instance size
- Add Redis read replicas
- Optimize database queries
- Enable CDN for static assets

---

## Common Error Messages

### Error: "Operation is not valid for cluster in state RECONCILING"

**Meaning:** Cluster is being updated

**Solution:** Wait 5-10 minutes, then retry

### Error: "INVALID_ARGUMENT: network doesn't have at least 1 private services connection"

**Meaning:** Private service connection missing for Cloud SQL

**Solution:** Already fixed in terraform/modules/vpc/main.tf
```bash
# Verify it exists
gcloud services vpc-peerings list --network=dev-core
```

### Error: "maintena policy would go longer than 32d without 48h maintenance availability"

**Meaning:** Invalid maintenance window configuration

**Solution:** Already fixed - using daily_maintenance_window

### Error: "bucket name is not available"

**Meaning:** Bucket name must be globally unique

**Solution:** Already fixed - using project ID prefix

---

## Debug Tools & Commands

### Comprehensive Health Check Script

```bash
#!/bin/bash
# health-check.sh

echo "=== Infrastructure Health Check ==="

echo "\n1. GKE Cluster"
gcloud container clusters list --format="table(name,status,currentNodeCount)"

echo "\n2. Cloud SQL"
gcloud sql instances list --format="table(name,state,ipAddresses[0].ipAddress)"

echo "\n3. Kubernetes Pods"
kubectl get pods -n production

echo "\n4. Services"
kubectl get services -n production

echo "\n5. Node Status"
kubectl get nodes -o wide

echo "\n6. Recent Events"
kubectl get events -n production --sort-by='.lastTimestamp' | tail -20

echo "\n=== End Health Check ==="
```

### Debug Pod Template

```yaml
# debug-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: debug-pod
  namespace: production
spec:
  serviceAccountName: conversation-manager-sa
  containers:
  - name: debug
    image: nicolaka/netshoot
    command: ["/bin/bash"]
    args: ["-c", "sleep 3600"]
```

```bash
# Deploy and use
kubectl apply -f debug-pod.yaml
kubectl exec -it debug-pod -n production -- /bin/bash

# Inside pod:
# - Test DNS: nslookup SERVICE_NAME
# - Test connectivity: curl http://SERVICE_NAME:PORT
# - Check auth: gcloud auth list
# - Access secrets: gcloud secrets versions access latest --secret=SECRET_NAME
```

---

## Getting Help

If issues persist after troubleshooting:

1. **Collect Information:**
```bash
# Generate support bundle
kubectl cluster-info dump > cluster-dump.txt
terraform show > terraform-state.txt
gcloud compute instances list > instances.txt
kubectl get events -n production --sort-by='.lastTimestamp' > events.txt
```

2. **Check Documentation:**
   - [DEPLOYMENT_RUNBOOK.md](../environments/dev/DEPLOYMENT_RUNBOOK.md)
   - [DEPLOYMENT_SUMMARY.md](../environments/dev/DEPLOYMENT_SUMMARY.md)
   - [README.md](../../README.md)

3. **Open Issue:**
   - Include Terraform version
   - Include error messages
   - Attach support bundle
   - Describe steps to reproduce

4. **Emergency Contact:**
   - Infrastructure team: infra@example.com
   - On-call: oncall@example.com

---

**End of Troubleshooting Guide**
