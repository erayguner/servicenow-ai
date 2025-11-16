# Security Scanning Guide

Comprehensive guide to security scanning tools and processes in the ServiceNow AI platform.

## Overview

The project implements a **multi-layered security scanning approach** covering all stages of the software development lifecycle.

## Security Scanning Layers

### Layer 1: Pre-Commit (Developer Workstation)

**Tools:** Pre-commit hooks (`.pre-commit-config.yaml`)

**Scans:**
1. **Secret Detection** (detect-secrets)
   - Scans all staged files for secrets
   - Baseline: `.secrets.baseline`
   - Updates baseline when new false positives found

2. **Terraform Security**
   - `terraform fmt` - Code formatting
   - `terraform validate` - Configuration validation

3. **Python Security**
   - Ruff linter and formatter
   - Checks for security anti-patterns

4. **Kubernetes Security**
   - kube-linter - Security best practices

**Setup:**
```bash
make pre-commit-install
```

**Usage:**
```bash
# Automatically runs on git commit
git commit -m "message"

# Manual run
make pre-commit

# Update hooks
pre-commit autoupdate
```

---

### Layer 2: Pull Request (CI/CD - Lint Workflow)

**Workflow:** `.github/workflows/lint.yml`

**Scans:**
1. **YAML Linting**
   - yamllint (configuration quality)
   - Prettier (formatting)

2. **Infrastructure as Code**
   - **Checkov**: 200+ security checks for Terraform
   - **tfsec**: Terraform security scanner
   - **terraform validate**: Syntax and logic validation

3. **Kubernetes Manifests**
   - **kube-linter**: 40+ security checks
   - **kubeconform**: Schema validation

4. **GitHub Actions**
   - actionlint: Workflow security and correctness

**Conditional Execution:**
- Only runs linters for changed file types
- Skips if no relevant files modified

**Example:**
```bash
# Simulate CI linting locally
make ci
```

---

### Layer 3: Code Analysis (CI/CD - CodeQL)

**Workflow:** `.github/workflows/codeql-analysis.yaml`

**Tool:** GitHub CodeQL

**Languages Analyzed:**
- JavaScript
- TypeScript
- Python (if .py files exist)

**Query Suites:**
- `security-extended`: Extended security queries
- `security-and-quality`: Security + code quality

**Features:**
- Runs on push to main/develop
- Runs on all pull requests
- Weekly scheduled scan (Mondays 6 AM UTC)
- Fails build on high-severity findings
- Uploads SARIF to Security tab

**Detected Issues:**
- SQL injection
- XSS vulnerabilities
- Command injection
- Path traversal
- Insecure cryptography
- Hard-coded credentials
- And 300+ more patterns

**Viewing Results:**
```
GitHub → Security → Code scanning alerts
```

---

### Layer 4: Container Security (CI/CD - Deploy Workflow)

**Workflow:** `.github/workflows/deploy.yml`

**Scans:**
1. **Trivy Container Scanning**
   - Scans container images for CVEs
   - Checks: OS packages, application dependencies
   - Severity filter: CRITICAL, HIGH
   - Fails build if vulnerabilities found
   - Uploads SARIF to Security tab

2. **SBOM Generation (Syft)**
   - Creates Software Bill of Materials
   - Format: SPDX-JSON
   - Lists all packages and dependencies
   - Uploaded as workflow artifact

**What's Scanned:**
- Base image (alpine, node, etc.)
- OS packages (apk, apt, etc.)
- Application dependencies (npm, pip, etc.)
- Embedded binaries

**Example Trivy Output:**
```
Total: 5 (CRITICAL: 2, HIGH: 3)

┌──────────┬──────────────┬──────────┬──────────────┬──────────────┐
│ Library  │ Vulnerability│ Severity │ Installed    │ Fixed Version│
├──────────┼──────────────┼──────────┼──────────────┼──────────────┤
│ openssl  │ CVE-2024-1234│ CRITICAL │ 3.1.1-r0     │ 3.1.1-r1     │
│ curl     │ CVE-2024-5678│ HIGH     │ 8.1.0-r0     │ 8.1.0-r1     │
└──────────┴──────────────┴──────────┴──────────────┴──────────────┘
```

**SBOM Location:**
```
Actions → [Workflow Run] → Artifacts → anchore-sbom
```

---

### Layer 5: Secret Detection (CI/CD)

**Workflow:** `.github/workflows/security-check.yml`

**Checks:**
1. **No Service Account Keys**
   - Scans Terraform for `google_service_account_key`
   - Enforces Workload Identity usage

2. **No Credential Files**
   - Finds: *credentials*.json, *-key.json, service-account-*.json
   - Excludes: node_modules, .git

3. **No Hardcoded Credentials**
   - Searches for GOOGLE_APPLICATION_CREDENTIALS
   - Excludes: .env.example, workflow files

4. **No Base64 Encoded Keys**
   - Detects: "private_key", "client_email" in YAML/JSON
   - Excludes: .github directory

5. **Workload Identity Verification**
   - Checks GitHub Actions uses WIF
   - Verifies K8s ServiceAccounts have WI annotations

**Runs On:**
- Push to main/develop
- All pull requests

---

### Layer 6: Dependency Scanning

**Tool:** Dependabot (`.github/dependabot.yml`)

**Scans:**
- Terraform providers/modules (weekly)
- GitHub Actions (weekly)
- Docker base images (weekly)
- npm dependencies (weekly)
- Python dependencies (weekly)

**Features:**
- Automated security updates
- Grouped updates (dev + prod dependencies)
- Version compatibility checks

**Configuration:**
```yaml
updates:
  - package-ecosystem: npm
    directory: /backend
    schedule:
      interval: weekly
    groups:
      dev-dependencies:
        patterns: ["@types/*", "eslint*", "prettier"]
```

---

## Security Scanning Matrix

| Layer | Tool | Target | Trigger | Fail Build? |
|-------|------|--------|---------|-------------|
| Pre-commit | detect-secrets | Secrets | git commit | ✅ Yes |
| Pre-commit | Ruff | Python code | git commit | ✅ Yes |
| CI | Checkov | Terraform | PR/Push | ✅ Yes |
| CI | tfsec | Terraform | PR/Push | ⚠️ Warning |
| CI | kube-linter | K8s manifests | PR/Push | ✅ Yes |
| CI | CodeQL | TypeScript/JS | PR/Push/Weekly | ✅ Yes (high) |
| CI | Trivy | Container images | Deploy | ✅ Yes (crit/high) |
| CI | Syft | SBOM | Deploy | ℹ️ Info only |
| CI | Security Check | Secrets/Keys | PR/Push | ✅ Yes |
| CI | Dependabot | Dependencies | Weekly | ℹ️ PR created |

---

## Compliance Standards

### NIST SSDF (Secure Software Development Framework)

- ✅ **PO.3.1**: Store code securely (GitHub)
- ✅ **PO.3.2**: Secure repository (branch protection, signed commits)
- ✅ **PW.4.1**: Automated testing (CodeQL, Trivy)
- ✅ **PW.4.4**: Scan for vulnerabilities (multi-layer)
- ✅ **PW.7.1**: Generate SBOM
- ✅ **PW.8.1**: Review code (required reviews)
- ✅ **RV.1.1**: Identify vulnerabilities (continuous scanning)

### SLSA (Supply-chain Levels for Software Artifacts)

**Current Level: SLSA 2** (partial)

- ✅ Source: Version controlled (Git)
- ✅ Build service: GitHub Actions
- ✅ Build: Automated, reproducible
- ⚠️ Provenance: Binary Authorization only (not full SLSA provenance)
- ⚠️ Non-falsifiable: Needs Sigstore integration

**Path to SLSA 3:**
1. Add SLSA provenance generation
2. Implement Cosign signing
3. Use reusable workflows
4. Hermetic builds

### OWASP ASVS (Application Security Verification Standard)

- ✅ V1.14: Secure configuration review (Checkov, tfsec)
- ✅ V7.3: Log injection protection (CodeQL)
- ✅ V8.3: Data protection (secret scanning)
- ✅ V14.2: Dependency security (Dependabot, Trivy)
- ✅ V14.4: SBOM generation

---

## Viewing Security Results

### GitHub Security Tab

**Location:** Repository → Security

**Sections:**
1. **Code scanning alerts**
   - CodeQL findings (TypeScript/JavaScript)
   - Trivy container scan results
   - Organized by severity

2. **Dependabot alerts**
   - Vulnerable dependencies
   - Suggested fixes
   - Auto-generated PRs

3. **Secret scanning alerts**
   - Detected secrets (if enabled)
   - Token expiration

### Workflow Run Details

**Location:** Actions → [Workflow Name] → [Run]

**Artifacts:**
- CodeQL SARIF files
- Trivy scan results
- SBOM (SPDX-JSON)

**Logs:**
- Detailed scan output
- CVE information
- Remediation suggestions

---

## Remediation Workflow

### For CodeQL Findings

1. Review alert in Security tab
2. Click "Show paths" to see vulnerable code flow
3. Read CodeQL query documentation
4. Fix code according to recommendation
5. Re-run security scan
6. Dismiss alert if false positive

### For Container Vulnerabilities

1. Review Trivy scan results in workflow logs
2. Identify affected package and CVE
3. **Option A**: Update base image
   ```dockerfile
   FROM node:20-alpine3.18  # Old
   FROM node:20-alpine3.19  # New (fixed)
   ```
4. **Option B**: Update application dependency
   ```bash
   npm update <package>
   ```
5. **Option C**: Accept risk (document in security review)

### For Dependency Vulnerabilities

1. Review Dependabot PR
2. Check changelog for breaking changes
3. Run tests locally
4. Approve and merge if safe
5. Or manually update:
   ```bash
   npm audit fix
   # or
   pip install --upgrade <package>
   ```

---

## False Positive Handling

### CodeQL

Mark as false positive in Security tab:
1. Open alert
2. Click "Dismiss alert"
3. Select reason: "False positive"
4. Add comment explaining why

### Trivy

Add to `.trivyignore`:
```
# False positive - not exploitable in our use case
CVE-2024-1234
```

### detect-secrets

Update `.secrets.baseline`:
```bash
detect-secrets scan --baseline .secrets.baseline --update
```

---

## Security Scanning Metrics

Track in dashboards:
- CodeQL findings per week
- Container CVE count over time
- MTTR (Mean Time To Remediate)
- False positive rate
- Dependabot PR merge rate

---

## Best Practices

### For Developers

1. **Run pre-commit hooks** before pushing
2. **Fix security findings** before requesting review
3. **Never commit secrets** (even in .env.example - use placeholders)
4. **Update dependencies** regularly
5. **Review Dependabot PRs** within 1 week

### For Reviewers

1. **Check Security tab** before approving PR
2. **Verify scan results** in workflow runs
3. **Require fixes** for high/critical findings
4. **Document risk acceptance** for medium findings

### For Security Team

1. **Weekly review** of all open security alerts
2. **Prioritize critical** vulnerabilities
3. **Update baselines** for false positives
4. **Track metrics** in security dashboard
5. **Annual review** of scanning tools

---

## Troubleshooting

### CodeQL Scan Fails

```bash
# Check workflow logs
gh run view <run-id> --log

# Common issues:
# - Build failure (check autobuild step)
# - Out of memory (increase ram: 6144 → 8192)
# - Timeout (increase timeout-minutes)
```

### Trivy Scan Timeout

```yaml
# Increase timeout in deploy.yml
timeout: '15m'  # Default is 10m
```

### Pre-commit Hooks Not Running

```bash
# Reinstall hooks
make pre-commit-install

# Or manually
pre-commit install
```

---

## References

- [CodeQL Documentation](https://codeql.github.com/docs/)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [Checkov Documentation](https://www.checkov.io/)
- [NIST SSDF](https://csrc.nist.gov/Projects/ssdf)
- [SLSA Framework](https://slsa.dev/)
- [OWASP ASVS](https://owasp.org/www-project-application-security-verification-standard/)

---

## Updates

**Last Updated:** 2025-11-16
**Scanning Tools Version:**
- CodeQL: Latest (GitHub-hosted)
- Trivy: 0.28.0
- Checkov: 3.2.493
- Syft: 0.17.9
- detect-secrets: 1.5.0

**Next Review:** 2025-12-16
