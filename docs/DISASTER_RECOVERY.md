# Disaster Recovery & Business Continuity

## Overview

Comprehensive disaster recovery (DR) and business continuity plan for the ServiceNow AI infrastructure on GCP.

**Last Updated**: 2025-11-03
**Version**: 1.0.0
**Owner**: Platform Engineering Team

---

## Recovery Objectives

### RPO (Recovery Point Objective)
Maximum acceptable data loss:
- **Production Database**: 5 minutes (PITR enabled)
- **Cloud Storage**: 1 hour (versioned, replicated)
- **Firestore**: Real-time replication (0 RPO)
- **Configuration**: 0 RPO (Infrastructure as Code)

### RTO (Recovery Time Objective)
Maximum acceptable downtime:
- **Critical Services**: 15 minutes (conversation-manager, llm-gateway)
- **High Priority**: 30 minutes (knowledge-base, api-gateway)
- **Standard**: 1 hour (analytics, document-ingestion)
- **Full Infrastructure**: 2 hours (complete rebuild)

---

## Architecture Resilience

### Multi-Zone Redundancy ✅

**GKE Cluster**:
- Regional cluster (3 zones): `europe-west2-a`, `europe-west2-b`, `europe-west2-c`
- Node pools distributed across zones
- Automatic zone failover

**Cloud SQL**:
- Regional instance with HA configuration
- Automatic failover to standby replica
- Failover time: < 60 seconds

**Storage**:
- Multi-regional Cloud Storage buckets
- Cross-zone replication
- Versioning enabled

### Single Points of Failure

**Eliminated**:
- ✅ Single-zone node failures (multi-zone cluster)
- ✅ Database master failures (HA replica)
- ✅ Load balancer failures (GCP-managed, multi-zone)
- ✅ Network failures (VPC auto-mode, redundant paths)

**Remaining** (acceptable risk):
- Regional GCP outage (requires multi-region DR)
- DNS provider outage (Cloud DNS is highly available)
- External API dependencies (OpenAI, ServiceNow)

---

## Backup Strategy

### Automated Backups

#### Cloud SQL
```hcl
# terraform/modules/cloudsql/main.tf
backup_configuration {
  enabled                        = true
  point_in_time_recovery_enabled = true
  backup_retention_settings {
    retained_backups = 7  # 7 days of backups
  }
  transaction_log_retention_days = 7
}
```

**Backup Schedule**: Daily at 05:00 UTC
**Retention**: 7 days
**PITR Window**: 7 days (5-minute granularity)

#### Cloud Storage
```bash
# Versioning enabled on all buckets
gsutil versioning set on gs://knowledge-documents-prod
gsutil versioning set on gs://document-chunks-prod
gsutil versioning set on gs://backup-prod
```

**Lifecycle Policy**:
- Deleted objects retained for 30 days
- Old versions automatically cleaned after 90 days

#### Firestore
- Automatic multi-region replication
- Point-in-time restore available (managed by GCP)
- Export to Cloud Storage daily

```bash
# Daily Firestore export
gcloud firestore export gs://backup-prod/firestore/$(date +%Y-%m-%d) \
  --async
```

#### Infrastructure as Code
```bash
# Git repository serves as source of truth
git push origin main  # Automatic backup to GitHub

# Terraform state backup
gsutil versioning set on gs://terraform-state-prod
```

---

## Recovery Procedures

### Scenario 1: Pod Failure ⚠️

**Detection**: Pod health check failure, monitoring alert

**Automatic Recovery**:
1. Kubernetes detects unhealthy pod
2. Pod restart attempted (livenessProbe)
3. If restart fails, pod terminated and recreated
4. Traffic routed to healthy pods (Service)

**RTO**: < 1 minute
**Manual Intervention**: None required

---

### Scenario 2: Node Failure ⚠️

**Detection**: Node unreachable, pods evicted

**Automatic Recovery**:
1. GKE detects node failure
2. Pods rescheduled to healthy nodes
3. New node provisioned if cluster scaled down
4. Workloads restored

**RTO**: 2-5 minutes
**Manual Intervention**: None required

---

### Scenario 3: Zone Failure ⚠️⚠️

**Detection**: All nodes in zone unreachable

**Automatic Recovery**:
1. GKE redistributes workloads to remaining zones
2. New nodes provisioned in healthy zones
3. Pod anti-affinity ensures distribution
4. Services remain available (multi-zone LB)

**RTO**: 5-10 minutes
**Manual Intervention**: Monitor recovery, verify services

**Manual Steps**:
```bash
# Verify cluster health
kubectl get nodes -o wide
kubectl get pods -n production -o wide

# Check pod distribution
kubectl get pods -n production -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.nodeName}{"\n"}{end}'

# If needed, scale up manually
kubectl scale deployment/conversation-manager --replicas=6 -n production
```

---

### Scenario 4: Database Failure ⚠️⚠️⚠️

**Detection**: Database connection errors, monitoring alert

**Automatic Recovery (if HA replica healthy)**:
1. Cloud SQL detects master failure
2. Automatic failover to HA replica
3. New replica promoted to master
4. Applications reconnect automatically

**RTO**: < 60 seconds
**Manual Intervention**: None required (automatic failover)

**Manual Recovery (if HA replica also failed)**:
```bash
# 1. Check Cloud SQL status
gcloud sql instances describe prod-postgres \
  --project=${PROJECT_ID}

# 2. Restore from backup (if needed)
gcloud sql backups list \
  --instance=prod-postgres \
  --project=${PROJECT_ID}

# Get the latest backup ID
BACKUP_ID=$(gcloud sql backups list --instance=prod-postgres \
  --format="value(id)" --limit=1)

# Restore from backup
gcloud sql backups restore ${BACKUP_ID} \
  --backup-instance=prod-postgres \
  --backup-instance=${PROJECT_ID} \
  --project=${PROJECT_ID}

# 3. Verify database connectivity
kubectl run -it --rm db-test \
  --image=postgres:14 \
  --env="PGPASSWORD=..." \
  -- psql -h prod-postgres-ip -U username -d database
```

**RTO**: 10-30 minutes (restore from backup)

---

### Scenario 5: Regional Outage ⚠️⚠️⚠️⚠️

**Detection**: All resources in region unreachable

**Manual Recovery Required**:

**Prerequisites**:
- Multi-region DR environment pre-configured
- DNS failover mechanism
- Cross-region database replication

**Recovery Steps**:

**1. Activate DR Region**:
```bash
# Switch to DR region (us-central1)
export DR_REGION=us-central1
export DR_PROJECT_ID=${PROJECT_ID}

# Deploy infrastructure in DR region
cd terraform/environments/prod-dr
terraform init
terraform apply -auto-approve

# Deploy Kubernetes resources
gcloud container clusters get-credentials prod-ai-agent-gke-dr \
  --region=${DR_REGION}

kubectl apply -f ../../k8s/service-accounts/
kubectl apply -f ../../k8s/network-policies/
kubectl apply -f ../../k8s/deployments/
```

**2. Restore Data**:
```bash
# Restore Cloud SQL from latest backup
gcloud sql backups restore ${LATEST_BACKUP_ID} \
  --backup-instance=prod-postgres \
  --backup-instance=${PROJECT_ID} \
  --project=${PROJECT_ID} \
  --region=${DR_REGION}

# Restore Firestore (if needed)
gcloud firestore import gs://backup-prod/firestore/latest \
  --project=${PROJECT_ID}

# Cloud Storage is multi-region (no restore needed)
```

**3. Update DNS**:
```bash
# Update Cloud DNS to point to DR region
gcloud dns record-sets transaction start \
  --zone=production-zone

gcloud dns record-sets transaction add ${DR_IP_ADDRESS} \
  --name=api.servicenow-ai.com. \
  --ttl=60 \
  --type=A \
  --zone=production-zone

gcloud dns record-sets transaction execute \
  --zone=production-zone
```

**4. Verify Services**:
```bash
# Health check
curl https://api.servicenow-ai.com/healthz

# Test critical paths
./scripts/smoke-tests.sh

# Monitor for errors
kubectl logs -n production -l app=conversation-manager --tail=100
```

**RTO**: 2-4 hours (full regional failover)
**RPO**: 1 hour (last cross-region backup)

---

## Testing & Validation

### Monthly DR Tests

**Pod Failure Test**:
```bash
# Kill random pod
POD=$(kubectl get pods -n production -l app=conversation-manager -o name | shuf -n 1)
kubectl delete ${POD} -n production

# Verify automatic recovery
kubectl get pods -n production -w
```

**Node Drain Test**:
```bash
# Simulate node failure
NODE=$(kubectl get nodes -o name | shuf -n 1)
kubectl drain ${NODE} --ignore-daemonsets --delete-emptydir-data

# Verify pod rescheduling
kubectl get pods -n production -o wide

# Uncordon node
kubectl uncordon ${NODE}
```

**Database Failover Test**:
```bash
# Trigger manual failover (non-destructive)
gcloud sql instances failover prod-postgres \
  --project=${PROJECT_ID}

# Monitor application impact
kubectl logs -n production -l app=conversation-manager --tail=50 -f
```

### Quarterly DR Tests

**Backup Restore Test** (in staging):
```bash
# 1. Export prod database
gcloud sql export sql prod-postgres gs://backup-staging/test-restore.sql \
  --database=users

# 2. Restore to staging
gcloud sql import sql staging-postgres gs://backup-staging/test-restore.sql \
  --database=users

# 3. Validate data integrity
./scripts/validate-database.sh staging-postgres
```

**Full DR Failover Test** (annual):
- Deploy full infrastructure in DR region
- Restore all data from backups
- Failover DNS to DR region
- Run comprehensive tests
- Failback to primary region

---

## Incident Response

### Severity Levels

**SEV-1 (Critical)**: Complete service outage
- **Response Time**: 5 minutes
- **Notification**: Page on-call engineer, notify leadership
- **Actions**: Immediate triage, activate DR if needed

**SEV-2 (High)**: Partial service degradation
- **Response Time**: 15 minutes
- **Notification**: Alert on-call engineer
- **Actions**: Investigate and resolve, consider scaling resources

**SEV-3 (Medium)**: Non-critical issues
- **Response Time**: 1 hour
- **Notification**: Create ticket
- **Actions**: Schedule fix in next deployment

### Communication Plan

**Internal**:
- Slack: `#prod-incidents` (real-time updates)
- Email: eng-all@company.com (incident reports)
- Status page: Internal dashboard

**External**:
- Status page: https://status.servicenow-ai.com
- Email: support@company.com (affected customers)
- Social media: @ServiceNowAI (major outages)

---

## Data Retention & Compliance

### Backup Retention

| Data Type | Retention Period | Storage Location |
|-----------|------------------|------------------|
| Database Backups | 7 days | Cloud SQL managed |
| Database PITR Logs | 7 days | Cloud SQL managed |
| Cloud Storage Versions | 90 days | GCS versioning |
| Firestore Exports | 30 days | Cloud Storage |
| Application Logs | 30 days | Cloud Logging |
| Audit Logs | 365 days | Cloud Storage |
| Terraform State | Forever | GCS versioned |

### Data Destruction

**Decommissioning Process**:
```bash
# 1. Export data for archival
./scripts/export-all-data.sh

# 2. Verify backups
./scripts/verify-exports.sh

# 3. Delete with verification
terraform destroy -var-file=terraform.tfvars

# 4. Verify deletion
gcloud compute instances list --filter="labels.env=prod"
gcloud sql instances list --filter="prod-*"
gcloud container clusters list --filter="prod-*"
```

**Compliance**: GDPR, SOC 2, HIPAA

---

## Monitoring & Alerting

### DR-Specific Alerts

```yaml
# High backup age
- alert: BackupTooOld
  expr: (time() - cloudsql_backup_timestamp) > 86400
  annotations:
    summary: "Cloud SQL backup older than 24 hours"

# Backup failures
- alert: BackupFailed
  expr: cloudsql_backup_status == "FAILED"
  annotations:
    summary: "Cloud SQL backup failed"

# Cross-region replication lag
- alert: ReplicationLag
  expr: cloudsql_replication_lag_seconds > 300
  annotations:
    summary: "Database replication lag > 5 minutes"
```

---

## Cost Optimization

### Backup Storage Costs

**Current Monthly Costs** (estimated):
- Cloud SQL Backups: $50/month (7 days @ 200GB)
- Cloud Storage Versions: $100/month (90 days @ 500GB)
- Firestore Exports: $30/month
- **Total**: ~$180/month

**Cost Reduction Strategies**:
- Reduce backup retention to 3 days (save 50%)
- Use Nearline storage for old versions (save 30%)
- Compress Firestore exports (save 40%)

---

## Documentation & Training

### Runbooks

Located in `docs/runbooks/`:
- `pod-failure.md` - Pod recovery procedures
- `node-failure.md` - Node replacement steps
- `database-failover.md` - Database recovery
- `regional-failover.md` - Multi-region DR activation

### Training Schedule

**Monthly**: DR drill for on-call engineers
**Quarterly**: Backup restore test
**Annual**: Full DR failover test

### Team Responsibilities

| Role | Responsibility |
|------|----------------|
| On-Call Engineer | First responder, execute runbooks |
| Platform Lead | DR strategy, coordinate major incidents |
| Database Admin | Database recovery, backup verification |
| Security Team | Audit DR procedures, compliance review |

---

## Continuous Improvement

### Post-Incident Review

After each DR event:
1. Document timeline of events
2. Identify root cause
3. Update runbooks based on learnings
4. Implement preventive measures
5. Share learnings with team

### Metrics Tracking

**Key Metrics**:
- Actual RTO vs. target RTO
- Actual RPO vs. target RPO
- DR drill success rate
- Backup restore success rate
- Time to detect incidents

**Quarterly Review**:
- Analyze DR metrics
- Update recovery procedures
- Test new failure scenarios
- Review and update RTO/RPO targets

---

## Emergency Contacts

### On-Call Rotation

**Primary**: [PagerDuty schedule]
**Secondary**: [Backup on-call]
**Escalation**: Platform Lead → VP Engineering → CTO

### External Vendors

| Vendor | Contact | SLA |
|--------|---------|-----|
| Google Cloud Support | [Portal] | 1-hour response (P1) |
| DNS Provider | support@dns.com | 24/7 support |
| ServiceNow | partner-support@servicenow.com | 2-hour response |

---

## Appendix

### Scripts

**Backup Verification**:
```bash
#!/bin/bash
# scripts/verify-backups.sh

# Check Cloud SQL backups
LATEST_BACKUP=$(gcloud sql backups list --instance=prod-postgres \
  --format="value(windowStartTime)" --limit=1)

BACKUP_AGE=$(($(date +%s) - $(date -d "$LATEST_BACKUP" +%s)))

if [ $BACKUP_AGE -gt 86400 ]; then
  echo "ERROR: Latest backup is too old (${BACKUP_AGE}s)"
  exit 1
fi

echo "✅ Cloud SQL backup is recent"

# Check Firestore exports
LATEST_EXPORT=$(gsutil ls -l gs://backup-prod/firestore/ | tail -1 | awk '{print $2}')
# ... validation logic

echo "✅ All backups verified"
```

**Smoke Tests**:
```bash
#!/bin/bash
# scripts/smoke-tests.sh

# Test API Gateway
curl -f https://api.servicenow-ai.com/healthz || exit 1

# Test conversation flow
curl -f -X POST https://api.servicenow-ai.com/v1/conversations \
  -H "Authorization: Bearer ${API_KEY}" \
  -d '{"message":"test"}' || exit 1

echo "✅ All smoke tests passed"
```

---

**Last Reviewed**: 2025-11-03
**Next Review**: 2025-12-03
**Document Owner**: Platform Engineering Team
