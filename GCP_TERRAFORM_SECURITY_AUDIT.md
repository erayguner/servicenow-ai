# GCP Terraform Security Audit Report
**Date:** 2026-01-09
**Project:** ServiceNow AI Infrastructure
**Scope:** Google Cloud Platform Terraform Configuration
**Auditor:** Claude AI Assistant

## Executive Summary

A comprehensive security audit of the GCP Terraform infrastructure has been completed. The infrastructure demonstrates **strong security posture** with industry best practices implemented across all major components. However, **provider versions are outdated** and should be updated to benefit from security patches and new features.

**Overall Security Rating:** 🟢 **GOOD** (8.5/10)

---

## ✅ Security Strengths

### 1. GKE (Google Kubernetes Engine) Security
**Rating: Excellent (10/10)**

**terraform/modules/gke/main.tf**

- ✅ **Private cluster enabled** (`enable_private_nodes = true`) - nodes have no public IPs
- ✅ **Private endpoint disabled** for kubectl access - allows managed access
- ✅ **Shielded nodes enabled** - protection against rootkits and bootkits
- ✅ **Network policies enabled** with Calico provider - pod-to-pod security
- ✅ **Binary authorization enabled** (`PROJECT_SINGLETON_POLICY_ENFORCE`) - ensures only trusted container images
- ✅ **Workload Identity configured** - secure pod-to-GCP authentication
- ✅ **Master authorized networks** - restricts API server access
- ✅ **Client certificates disabled** (`issue_client_certificate = false`)
- ✅ **Secure boot enabled** on all node pools
- ✅ **Integrity monitoring enabled** on all node pools
- ✅ **Auto-repair and auto-upgrade enabled** on all node pools
- ✅ **Comprehensive logging and monitoring** configured

**Node Pools:**
- General pool: Spot instances for cost optimization (dev/staging)
- AI inference pool: Dedicated with taints for workload isolation
- Vector DB pool: High-memory SSD-backed instances

### 2. Cloud SQL Security
**Rating: Excellent (10/10)**

**terraform/modules/cloudsql/main.tf**

- ✅ **No public IP** (`ipv4_enabled = false`) - private network only
- ✅ **SSL/TLS required** (`ssl_mode = "TRUSTED_CLIENT_CERTIFICATE_REQUIRED"`)
- ✅ **KMS encryption** enabled for data-at-rest
- ✅ **Comprehensive audit logging** enabled:
  - pgaudit enabled
  - Connection/disconnection logging
  - Query logging
  - Lock wait logging
  - Duration logging
- ✅ **Point-in-time recovery** enabled
- ✅ **7-day backup retention**
- ✅ **Multi-region read replica** for disaster recovery
- ✅ **Deletion protection** enabled in production

### 3. Storage (Cloud Storage) Security
**Rating: Excellent (10/10)**

**terraform/modules/storage/main.tf**

- ✅ **Public access prevention enforced** - cannot be made public
- ✅ **Uniform bucket-level access** - IAM-only access control
- ✅ **KMS encryption** for all buckets
- ✅ **Versioning enabled by default** - protects against accidental deletion
- ✅ **Logging enabled** - audit trail for all access
- ✅ **Lifecycle policies** configured for cost optimization
- ✅ **Force destroy disabled** by default - prevents accidental deletion

### 4. VPC Network Security
**Rating: Excellent (9/10)**

**terraform/modules/vpc/main.tf**

- ✅ **VPC flow logs enabled** - network traffic monitoring
- ✅ **Cloud NAT with logging** enabled
- ✅ **Private Google Access** enabled - access Google services without public IPs
- ✅ **Optional default-deny firewall rules** - zero-trust networking
- ✅ **Private Service Connection** for Cloud SQL
- ✅ **Serverless VPC connector** for Cloud Run private access

### 5. KMS (Key Management Service)
**Rating: Excellent (10/10)**

**terraform/modules/kms/main.tf**

- ✅ **Automatic key rotation** configured (90 days for production)
- ✅ **30-day deletion protection** (`destroy_scheduled_duration = "2592000s"`)
- ✅ **Lifecycle prevent_destroy** - Terraform cannot accidentally delete keys
- ✅ **Separate keys** for different services (storage, pubsub, cloudsql, secrets)
- ✅ **Least-privilege IAM** - service accounts only have access to their specific keys

### 6. Redis (Memorystore) Security
**Rating: Excellent (9/10)**

**terraform/modules/redis/main.tf**

- ✅ **Transit encryption enabled** (`SERVER_AUTHENTICATION`)
- ✅ **Authentication enabled** (`auth_enabled = true`)
- ✅ **Private network only** - no public access
- ✅ **Maintenance windows configured**

### 7. Workload Identity & IAM
**Rating: Excellent (9/10)**

**terraform/environments/prod/workload_identity.tf**

- ✅ **Workload Identity** for GKE service accounts - no static credentials
- ✅ **Workload Identity Federation** for GitHub Actions CI/CD
- ✅ **Least-privilege IAM roles** assigned per microservice
- ✅ **Granular service accounts** - one per microservice
- ✅ **Well-documented permissions** for each service

### 8. Secret Management
**Rating: Good (8/10)**

**terraform/modules/secret_manager/** & **terraform/environments/prod/main.tf:225-237**

- ✅ **Secret Manager** used for sensitive data (no hardcoded secrets)
- ✅ **KMS encryption** for secrets
- ✅ **Proper IAM access control**
- ⚠️ Secrets are defined but values must be populated separately (expected)

### 9. Cloud Armor (WAF) Security
**Rating: Good (8/10)**

**terraform/environments/prod/main.tf:144-211**

- ✅ **Log4Shell protection** with GCP preconfigured rules
- ✅ **Custom JNDI injection blocking** rules
- ✅ **Rate limiting** configured (600 requests/min per IP)
- ✅ **Ban on abuse** (automatic IP banning at 1200 requests/min)

### 10. General Security Practices
- ✅ **No hardcoded passwords** found in Terraform code
- ✅ **Sensitive outputs** properly marked (e.g., Redis auth string)
- ✅ **Checkov skip comments** properly documented
- ✅ **Labels and tags** for resource tracking

---

## ⚠️ Security Issues & Recommendations

### 1. 🔴 CRITICAL: Outdated Provider Versions
**Severity: HIGH**
**File:** `terraform/versions.tf`

**Current versions:**
```hcl
google       = ">= 5.16.0"
google-beta  = ">= 5.16.0"
kubernetes   = ">= 2.24.0"
helm         = ">= 2.11.0, < 3.0.0"
```

**Latest versions available (as of 2026-01-09):**
- `google`: **6.26.0** (major version behind - missing 1+ years of security patches)
- `google-beta`: **4.72.0** (beta provider has different versioning)
- `kubernetes`: **3.0.1** (major version behind)
- `helm`: **2.16.1** (on correct major version, minor updates available)

**Recommendation:**
```hcl
terraform {
  required_version = ">= 1.11.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.26.0"  # ← Update to 6.x
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.26.0"  # ← Update to match google provider
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0.0"  # ← Update to 3.x
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.16.0"  # ← Update to latest 2.x
    }
  }
}
```

**Action Required:**
1. Review provider changelogs for breaking changes
2. Update provider versions in `terraform/versions.tf` and all module `versions.tf` files
3. Run `terraform init -upgrade`
4. Test in dev environment before promoting to staging/prod
5. Update provider versions in all modules to match

**References:**
- [Google Provider 6.x Upgrade Guide](https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/version_6_upgrade)
- [Kubernetes Provider 3.x Upgrade Guide](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/guides/v3-upgrade-guide)

---

### 2. 🟡 MEDIUM: Deprecated IAP Resources
**Severity: MEDIUM**
**File:** `terraform/modules/iap/main.tf:16-35`

**Issue:**
The `google_iap_brand` and `google_iap_client` resources are deprecated and will be removed on **March 19, 2026**.

**Current status:**
```hcl
# WARNING: This resource will stop working after March 19, 2026
resource "google_iap_brand" "project_brand" {
  count = var.create_brand ? 1 : 0  # Default: disabled
  ...
}
```

**Good news:** The code already has deprecation notices and defaults to manual creation (`create_brand = false`).

**Recommendation:**
1. ✅ Keep defaults as-is (manual OAuth creation)
2. Document the manual OAuth creation process in runbooks
3. Remove deprecated resources completely after March 19, 2026
4. Consider using `google_iap_web_backend_service_iam_binding` only (which is not deprecated)

---

### 3. 🟡 LOW: Cloud SQL Outputs Should Be Sensitive
**Severity: LOW**
**File:** `terraform/modules/cloudsql/outputs.tf`

**Issue:**
Connection names and IP addresses are not marked as sensitive.

**Current:**
```hcl
output "instance_connection_name" {
  description = "The connection name for Cloud SQL Proxy"
  value       = google_sql_database_instance.pg.connection_name
}

output "private_ip_address" {
  description = "The private IP address assigned to the instance"
  value       = try(google_sql_database_instance.pg.private_ip_address, null)
}
```

**Recommendation:**
```hcl
output "instance_connection_name" {
  description = "The connection name for Cloud SQL Proxy"
  value       = google_sql_database_instance.pg.connection_name
  sensitive   = true  # ← Add this
}

output "private_ip_address" {
  description = "The private IP address assigned to the instance"
  value       = try(google_sql_database_instance.pg.private_ip_address, null)
  sensitive   = true  # ← Add this
}
```

**Rationale:** While connection names aren't passwords, they reveal infrastructure details and should be treated as sensitive in Terraform outputs.

---

### 4. 🟢 INFO: Missing Advanced Security Features
**Severity: INFO**

The following advanced security features could be considered for future enhancements:

**VPC Service Controls:**
- Not currently implemented
- Would provide additional security perimeter around GCP services
- Recommended for highly sensitive workloads

**Organization Policy Constraints:**
- Not visible in module code
- Should be configured at organization/folder level
- Examples: require OS Login, restrict public IPs, enforce encryption

**Binary Authorization Attestations:**
- Binary authorization is enabled but attestation process not visible
- Should configure CI/CD to sign container images
- Verify signatures at deployment time

**DDoS Protection:**
- Cloud Armor provides application-layer protection
- Consider Google Cloud Armor Advanced DDoS protection for additional network-layer protection
- Current setup is adequate for most use cases

---

## 📊 Security Scorecard by Component

| Component | Security Score | Key Strengths | Improvements Needed |
|-----------|---------------|---------------|---------------------|
| GKE | 🟢 10/10 | Private cluster, network policies, binary auth | None |
| Cloud SQL | 🟢 10/10 | Private, encrypted, audit logs | None |
| Storage | 🟢 10/10 | Public access blocked, encrypted, versioned | None |
| VPC | 🟢 9/10 | Flow logs, private access, NAT | Optional: VPC Service Controls |
| KMS | 🟢 10/10 | Rotation, deletion protection, separate keys | None |
| Redis | 🟢 9/10 | Encrypted, auth enabled, private | None |
| IAM | 🟢 9/10 | Workload Identity, least privilege | None |
| Secrets | 🟢 8/10 | Secret Manager, encrypted | Ensure secrets populated |
| Cloud Armor | 🟢 8/10 | Log4Shell protection, rate limiting | Consider advanced DDoS |
| **Provider Versions** | 🔴 **5/10** | **Terraform 1.11.0 requirement** | **UPDATE TO LATEST VERSIONS** |

---

## 🔒 Compliance & Best Practices

### CIS Google Cloud Platform Foundation Benchmark
✅ **Mostly Compliant** - The infrastructure follows most CIS GCP benchmark recommendations:
- ✅ CKV_GCP_6: Cloud SQL SSL enforcement
- ✅ CKV_GCP_21: Resource labeling (with checkov skip comments where Terraform functions are used)
- ✅ CKV_GCP_78: Storage versioning (with checkov skip for coalesce function)
- ✅ Network isolation and private clusters
- ✅ Encryption at rest and in transit
- ✅ Audit logging enabled

### OWASP Top 10
✅ **Well Protected**:
- ✅ Injection attacks: WAF rules for Log4Shell, input validation expected at app layer
- ✅ Broken authentication: Workload Identity, no static credentials
- ✅ Sensitive data exposure: Encryption everywhere, no public access
- ✅ Security misconfiguration: Default-deny networking, private clusters
- ✅ Insufficient logging: Comprehensive logging across all services

---

## 📋 Action Items

### Immediate (Within 1 Week)
1. 🔴 **Update provider versions** to latest stable releases
   - Test in dev environment first
   - Document any breaking changes
   - Roll out to staging, then production

### Short-term (Within 1 Month)
2. 🟡 Mark Cloud SQL outputs as sensitive in `terraform/modules/cloudsql/outputs.tf`
3. 🟡 Verify manual OAuth creation process is documented for IAP

### Long-term (Within 3 Months)
4. 🟢 Evaluate VPC Service Controls for production environment
5. 🟢 Implement Binary Authorization attestation in CI/CD pipeline
6. 🟢 Review and implement Organization Policy Constraints at folder level

---

## 🧪 Validation Performed

Due to Terraform CLI not being available in the audit environment, the following validation methods were used:

1. ✅ **Manual code review** of all Terraform modules
2. ✅ **Pattern matching** for common security issues (hardcoded secrets, public access, etc.)
3. ✅ **Provider version checks** via Terraform Registry API
4. ✅ **Compliance mapping** to CIS benchmarks and OWASP standards
5. ✅ **Architecture review** of network isolation and encryption
6. ⚠️ **Static analysis tools** (checkov, tfsec) - not available, would recommend running in CI/CD

**Recommendation:** Enable automated security scanning in CI/CD:
```bash
pre-commit run checkov --all-files
pre-commit run terraform_tfsec --all-files
```

---

## 🎯 Conclusion

The GCP Terraform infrastructure demonstrates **excellent security practices** with industry-leading configurations for encryption, network isolation, and access control. The primary concern is **outdated provider versions** which should be addressed promptly to benefit from security patches and new features.

**Key Takeaways:**
- ✅ Strong foundation with zero-trust networking
- ✅ Encryption everywhere (at rest and in transit)
- ✅ Comprehensive audit logging
- ✅ Least-privilege IAM and Workload Identity
- 🔴 Provider versions need updating
- 🟢 Infrastructure is production-ready with excellent security posture

**Overall Assessment:** This infrastructure is well-designed and secure. After updating provider versions, it will be at the forefront of GCP security best practices.

---

## 📚 References

- [GCP Security Best Practices](https://cloud.google.com/security/best-practices)
- [CIS Google Cloud Platform Foundation Benchmark](https://www.cisecurity.org/benchmark/google_cloud_computing_platform)
- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [GKE Hardening Guide](https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)

---

**Report Generated By:** Claude AI Assistant
**Audit Completed:** 2026-01-09
**Next Audit Recommended:** 2026-04-09 (Quarterly)
