# Terraform Validation Guide

**Last Updated:** 2025-11-13 **Status:** Active

---

## Overview

This guide provides instructions for validating Terraform configurations in the
ServiceNow AI Infrastructure project using `npx claude-flow@alpha` and standard
terraform tools.

---

## Prerequisites

### Required Tools

```bash
# Terraform >= 1.11.0
terraform --version

# Claude Flow (for advanced validation)
npx claude-flow@alpha --version

# Pre-commit (for automated checks)
pre-commit --version
```

---

## Validation Methods

### Method 1: Standard Terraform Validation ✅

**Quick validation of all modules:**

```bash
# Format check (non-destructive)
terraform fmt -check -recursive terraform/

# Format all files (auto-fix)
terraform fmt -recursive terraform/

# Validate all modules
make terraform-validate

# Run module tests
make terraform-test
```

**Individual module validation:**

```bash
cd terraform/modules/<module-name>
terraform init -backend=false
terraform validate
terraform fmt -check
```

---

### Method 2: Pre-commit Hooks ✅ RECOMMENDED

**Automatic validation on every commit:**

```bash
# Install pre-commit hooks (one-time)
pre-commit install

# Run all hooks manually
pre-commit run --all-files

# Run specific hooks
pre-commit run terraform_fmt --all-files
pre-commit run terraform_validate --all-files
```

**What pre-commit checks:**

- ✅ Terraform formatting (terraform_fmt)
- ✅ Terraform validation (terraform_validate)
- ✅ Python linting (ruff)
- ✅ Secrets detection (detect-secrets)
- ✅ Kubernetes linting (kube-linter)
- ✅ YAML/JSON formatting

Reference: [.pre-commit-config.yaml](../.pre-commit-config.yaml)

---

### Method 3: Claude Flow Advanced Validation ✅

**Using npx claude-flow@alpha for AI-powered validation:**

```bash
# Start claude-flow with terraform context
npx claude-flow@alpha start --swarm

# Or use specific terraform validation commands
npx claude-flow@alpha agent booster benchmark
```

**Claude Flow Benefits:**

- AI-powered code review
- Advanced linting beyond standard tools
- Context-aware suggestions
- Integration with 90+ MCP tools

Reference: [Claude Flow Documentation](https://github.com/ruvnet/claude-flow)

---

### Method 4: CI/CD Pipeline ✅

**Automated validation in GitHub Actions:**

The CI/CD pipeline automatically runs on every push:

```yaml
# .github/workflows/terraform-ci-optimized.yml
- Terraform formatting check
- Terraform validation (all modules)
- Terraform tests (parallel execution)
- Security scanning (Checkov)
- Cost estimation (Infracost)
```

**Workflow triggers:**

- Push to any branch
- Pull request creation/update
- Manual workflow dispatch

Reference:
[.github/workflows/terraform-ci-optimized.yml](../.github/workflows/terraform-ci-optimized.yml)

---

## UK AI Playbook Compliance Validation

### Security Standards

**Validate compliance with:**

- ✅ Government Cyber Security Strategy (2022-2030)
- ✅ Secure by Design principles
- ✅ NCSC Cloud Security Principles

**Commands:**

```bash
# Check security configuration
grep -r "workload_identity" terraform/modules/
grep -r "binary_authorization" terraform/modules/gke/
grep -r "encryption_key" terraform/modules/

# Validate private cluster config
grep -r "enable_private" terraform/modules/gke/

# Check secret rotation
grep -r "rotation" terraform/modules/secret_manager/
```

### Data Protection

**Validate GDPR compliance:**

```bash
# Check data residency (EU regions)
grep -r "region.*=.*\"europe" terraform/environments/

# Verify encryption at rest
grep -r "kms_key" terraform/modules/

# Check backup configuration
grep -r "backup" terraform/modules/cloudsql/
```

### Governance Alignment

**Validate against AI Governance Framework:**

```bash
# Verify all environments have required resources
ls -la terraform/environments/

# Check KMS key rotation
grep -r "rotation_period" terraform/modules/kms/

# Validate multi-region setup
grep -r "replica" terraform/modules/cloudsql/
```

---

## Common Validation Issues & Fixes

### Issue 1: Formatting Errors

**Error:**

```
terraform fmt -check
└─ [FAIL] terraform/modules/gke/main.tf
```

**Fix:**

```bash
terraform fmt terraform/modules/gke/main.tf
# Or format all files
terraform fmt -recursive terraform/
```

---

### Issue 2: Variable Type Mismatch

**Error:**

```
Error: Invalid value for variable
```

**Fix:**

```hcl
# Ensure variable types match in variables.tf and module calls
# Example:
variable "spot_instance_pools" {
  type = list(string)
  default = []
}

# Usage:
spot_instance_pools = ["general", "ai-inference"]
```

---

### Issue 3: Cyclic Dependencies

**Error:**

```
Error: Cycle: module.vpc, module.gke
```

**Fix:**

```hcl
# Use explicit depends_on to break cycles
module "gke" {
  # ...
  depends_on = [module.vpc]
}
```

---

### Issue 4: Checkov Security Failures

**Error:**

```
CKV_GCP_21: Ensure GKE clusters are configured with labels
```

**Fix:**

```hcl
# Add required labels
resource "google_container_cluster" "primary" {
  resource_labels = merge(
    {
      managed_by  = "terraform"
      environment = var.environment
    },
    var.labels
  )
}

# Or skip check with justification
# checkov:skip=CKV_GCP_21:Labels are configured via merge()
```

---

## Validation Checklist

**Before committing:**

- [ ] Run `terraform fmt -recursive terraform/`
- [ ] Run `make terraform-validate`
- [ ] Run `pre-commit run --all-files`
- [ ] Check CI/CD pipeline passes
- [ ] Review terraform plan output
- [ ] Verify security best practices (no hardcoded secrets, encryption enabled)
- [ ] Check UK AI Playbook alignment (if applicable)

**Before deploying:**

- [ ] Review terraform plan in target environment
- [ ] Verify cost estimates (Infracost)
- [ ] Check for breaking changes
- [ ] Ensure backups are current
- [ ] Have rollback plan ready
- [ ] Notify stakeholders

---

## UK AI Playbook Specific Checks

### Principle 3: Security

**Validation:**

```bash
# Check Workload Identity (no service account keys)
! grep -r "service_account_key" terraform/

# Verify encryption
grep -r "encryption_key_name" terraform/modules/

# Check Binary Authorization
grep "binary_authorization" terraform/modules/gke/main.tf
```

### Principle 5: Lifecycle Management

**Validation:**

```bash
# Check monitoring configuration
grep -r "monitoring_service" terraform/modules/gke/

# Verify backup configuration
grep -r "backup_configuration" terraform/modules/cloudsql/

# Check auto-updates
grep -r "auto_upgrade" terraform/modules/gke/
```

### Principle 10: Organizational Alignment

**Validation:**

```bash
# Verify all environments have consistent configuration
diff terraform/environments/dev/main.tf terraform/environments/staging/main.tf

# Check labeling for resource tracking
grep -r "labels" terraform/modules/
```

---

## Advanced Validation with Claude Flow

### Interactive Validation Session

```bash
# Start claude-flow in interactive mode
npx claude-flow@alpha start

# Then ask Claude to:
# - Review terraform modules for best practices
# - Check for security vulnerabilities
# - Suggest optimizations
# - Validate UK AI Playbook compliance
```

### Automated Code Review

```bash
# Use agent booster for ultra-fast validation
npx claude-flow@alpha agent booster edit terraform/modules/gke/main.tf

# Batch validation of multiple files
npx claude-flow@alpha agent booster batch "terraform/modules/*/main.tf"

# Run benchmark to validate performance
npx claude-flow@alpha agent booster benchmark
```

### Example Claude Flow Prompts

**Security review:**

```
Review all terraform modules for UK Government Cyber Security Strategy compliance.
Check for: Workload Identity, encryption at rest/transit, private clusters, key rotation.
```

**Cost optimization:**

```
Analyze terraform configurations for cost optimization opportunities.
Focus on: spot instances, committed use discounts, right-sizing, storage lifecycle.
```

**Best practices:**

```
Review terraform modules against best practices for:
- DRY principles (module reuse)
- Variable naming conventions
- Resource naming patterns
- Documentation completeness
```

---

## Monitoring & Continuous Validation

### Automated Checks (CI/CD)

**On every commit:**

- Terraform format check
- Terraform validate (all modules)
- Security scanning (Checkov)
- Pre-commit hooks

**On pull request:**

- Full terraform test suite
- Cost estimation
- Plan output review
- Security audit

**Weekly:**

- Dependency updates (Dependabot)
- Security advisories check
- Compliance audit

### Manual Reviews

**Monthly:**

- Architecture review
- Cost analysis
- Security posture assessment
- UK AI Playbook compliance check

**Quarterly:**

- External security audit
- Compliance certification renewal
- Disaster recovery drill
- Incident response tabletop

---

## Troubleshooting

### Validation Fails But Code Looks Correct

```bash
# Clear terraform cache
find terraform -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true

# Re-initialize
terraform init -backend=false

# Try again
terraform validate
```

### Pre-commit Hooks Failing

```bash
# Update pre-commit hooks
pre-commit autoupdate

# Clear cache
pre-commit clean

# Re-install
pre-commit install --install-hooks

# Run again
pre-commit run --all-files
```

### CI/CD Pipeline Failing

```bash
# Run same checks locally
make ci

# If passing locally, check:
# - GitHub Actions workflow syntax
# - Environment variables
# - Secrets configuration
# - Runner compatibility
```

---

## Best Practices Summary

1. **Always format before committing:** `terraform fmt -recursive terraform/`
2. **Use pre-commit hooks:** Catch issues before CI/CD
3. **Write tests:** Every module should have tests in `tests/` directory
4. **Document changes:** Update ADRs for significant decisions
5. **Review plans:** Always review terraform plan output
6. **Monitor costs:** Use Infracost for cost estimates
7. **Security first:** Follow Secure by Design principles
8. **UK Playbook aligned:** Ensure compliance with 10 principles
9. **Regular audits:** Quarterly compliance reviews
10. **Continuous learning:** Stay updated on terraform and cloud best practices

---

## References

### Internal Documentation

- [Pre-commit Quickstart](../PRE_COMMIT_QUICKSTART.md)
- [Parallel Testing Guide](../docs/PARALLEL_TESTING_GUIDE.md)
- [Security Configuration](../terraform/docs/SECURITY_CONFIGURATION.md)
- [UK AI Playbook Compliance](../docs/ai-governance/UK_AI_PLAYBOOK_COMPLIANCE.md)

### External References

- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [Google Cloud Terraform Modules](https://github.com/terraform-google-modules)
- [UK AI Playbook](https://www.gov.uk/government/publications/ai-playbook-for-the-uk-government)
- [Government Cyber Security Strategy](https://www.gov.uk/government/publications/government-cyber-security-strategy-2022-to-2030)

---

**Document Owner:** Cloud Infrastructure Team **Last Updated:** 2025-11-13
**Next Review:** 2025-02-13

---

**END OF GUIDE**
