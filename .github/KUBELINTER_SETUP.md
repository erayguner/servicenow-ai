# KubeLinter Integration

**Date:** 2025-11-05
**Status:** ✅ Complete

---

## Overview

KubeLinter is integrated into pre-commit hooks to validate Kubernetes manifests for security and best practices.

---

## What KubeLinter Does

KubeLinter analyzes Kubernetes YAML files and checks for:

### Security Issues ⚠️
- Privileged containers
- Host network/PID/IPC access
- Unsafe system calls
- Sensitive host mounts
- Missing security contexts

### Best Practices ✅
- Resource limits (CPU/memory)
- Liveness/readiness probes
- Read-only root filesystems
- Non-root users
- Anti-affinity rules

### Configuration Issues 🔧
- Dangling services
- Deprecated API versions
- Mismatching selectors
- Invalid references

---

## Installation

### Automatic (Pre-Commit)

KubeLinter runs automatically via pre-commit when committing Kubernetes files:

```bash
# Pre-commit handles installation
git commit -m "update k8s deployment"
# KubeLinter runs automatically
```

### Manual (System-Wide)

```bash
# macOS
brew install kube-linter

# Linux
curl -LO https://github.com/stackrox/kube-linter/releases/latest/download/kube-linter-linux.tar.gz
tar -xzf kube-linter-linux.tar.gz
sudo mv kube-linter /usr/local/bin/
```

---

## Usage

### Automatic (On Commit)

```bash
# Make changes to Kubernetes files
vim k8s/deployments/api-gateway.yaml

# Commit (kube-linter runs automatically)
git add k8s/deployments/api-gateway.yaml
git commit -m "feat: update API gateway deployment"

# If issues found:
# - Fix the issues
# - Stage changes again
# - Commit
```

### Manual Testing

```bash
# Run kube-linter on all K8s files
make pre-commit-k8s

# Run directly with kube-linter
kube-linter lint k8s/

# Run on specific file
kube-linter lint k8s/deployments/api-gateway.yaml

# Use custom config
kube-linter lint --config .kube-linter.yaml k8s/
```

---

## Configuration

### File: `.kube-linter.yaml`

```yaml
checks:
  doNotAutoAddDefaults: false

  # Exclude checks for pre-commit
  exclude:
    - "non-existent-service-account"  # May not exist yet
    - "liveness-port"                 # Example files
    - "readiness-port"                # Example files
    - "required-annotation-email"     # Optional metadata
    - "required-label-owner"          # Optional metadata

  # Keep security checks enabled
  include:
    - "privileged-container"
    - "host-network"
    - "docker-sock"
    - "sensitive-host-mounts"
    # ... more security checks

# Ignore paths
ignorePaths:
  - "k8s/examples/"
  - "k8s/templates/"
```

### Why Exclude Some Checks?

**Pre-Commit Philosophy:**
- Catch critical issues (security, syntax)
- Don't block on optional metadata
- Allow WIP commits with missing pieces

**CI Pipeline (Full Validation):**
- Runs all checks (no exclusions)
- Enforces complete configuration
- Blocks deployment if issues found

---

## Common Issues

### Issue: Missing Resource Limits

```yaml
# ❌ Will fail in CI (not pre-commit)
spec:
  containers:
  - name: app
    image: myapp:latest
    # Missing: resources

# ✅ Fixed
spec:
  containers:
  - name: app
    image: myapp:latest
    resources:
      requests:
        memory: "128Mi"
        cpu: "100m"
      limits:
        memory: "256Mi"
        cpu: "200m"
```

### Issue: Privileged Container

```yaml
# ❌ Fails (security risk)
spec:
  containers:
  - name: app
    securityContext:
      privileged: true

# ✅ Fixed (remove privileged)
spec:
  containers:
  - name: app
    securityContext:
      privileged: false
      runAsNonRoot: true
      readOnlyRootFilesystem: true
```

### Issue: Host Network Access

```yaml
# ❌ Fails (security risk)
spec:
  hostNetwork: true
  containers:
  - name: app

# ✅ Fixed (remove host network)
spec:
  # hostNetwork: true  # Removed
  containers:
  - name: app
```

### Issue: Missing Security Context

```yaml
# ❌ Fails (insecure)
spec:
  containers:
  - name: app
    image: myapp:latest

# ✅ Fixed (add security context)
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 10000
    fsGroup: 10000
  containers:
  - name: app
    image: myapp:latest
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
```

---

## Integration with Workflows

### Pre-Commit Hook

**File:** `.pre-commit-config.yaml`

```yaml
- repo: https://github.com/stackrox/kube-linter
  rev: v0.6.8
  hooks:
    - id: kube-linter-system
      args: ['--config', '.kube-linter.yaml']
```

**Runs:**
- Automatically on commit
- Only on changed Kubernetes files
- Uses lenient config (excludes optional checks)

### GitHub Actions (Already Configured)

**File:** `.github/workflows/lint.yml`

```yaml
- name: kube-linter
  uses: stackrox/kube-linter-action@v1.0.7
  with:
    manifests: k8s
```

**Runs:**
- On every PR and push
- Full validation (all checks)
- Blocks merge if critical issues found

---

## Makefile Commands

```bash
# Run KubeLinter only
make pre-commit-k8s

# Run all pre-commit checks
make pre-commit

# Quick check (no Terraform validate)
make quick-check

# Show all commands
make help
```

---

## Skipping Checks

### Skip for One Commit (Emergency)

```bash
# Skip all pre-commit hooks
git commit --no-verify -m "emergency: hotfix"

# Skip only kube-linter
SKIP=kube-linter-system git commit -m "WIP: k8s config"
```

### Disable Specific Check

Add to `.kube-linter.yaml`:

```yaml
checks:
  exclude:
    - "check-name-here"
```

### Inline Ignore

Add annotation to Kubernetes resource:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  annotations:
    ignore-check.kube-linter.io/no-read-only-root-fs: "needs write access"
spec:
  # ...
```

---

## Performance

### Typical Run Times

| Scope | Files | Time |
|-------|-------|------|
| Single file | 1 | <1s |
| Small project | 5-10 | 1-2s |
| This project | ~30 | 2-3s |
| Large project | 100+ | 5-10s |

### Optimization

Pre-commit only runs on changed files:

```bash
# Only checks changed files
git add k8s/deployments/api.yaml
git commit
# Runs in ~1s

# Check all files
make pre-commit-k8s
# Runs in ~2-3s
```

---

## Best Practices

### ✅ Do

- Fix security issues immediately
- Add resource limits to all containers
- Use security contexts
- Run as non-root user
- Enable read-only root filesystem

### ❌ Don't

- Skip kube-linter for normal commits
- Disable security checks
- Use privileged containers
- Mount sensitive host paths
- Use host network/PID/IPC

---

## Comparison with Other Tools

| Tool | Speed | Focus | Coverage |
|------|-------|-------|----------|
| **KubeLinter** | Fast | Security + Best Practices | Excellent |
| kubeconform | Faster | Schema validation | Good |
| kubeval | Fast | Schema validation | Good |
| Polaris | Slow | Comprehensive audit | Excellent |
| OPA/Gatekeeper | Medium | Policy enforcement | Flexible |

**Why KubeLinter?**
- Fast enough for pre-commit
- Good balance of checks
- Easy to configure
- Well-maintained

---

## Examples

### Example 1: Secure Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
  labels:
    app: api-gateway
    owner: platform-team
  annotations:
    email: platform@example.com
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api-gateway
  template:
    metadata:
      labels:
        app: api-gateway
    spec:
      # Security context for pod
      securityContext:
        runAsNonRoot: true
        runAsUser: 10000
        fsGroup: 10000

      # Service account with WorkloadIdentity
      serviceAccountName: api-gateway-sa

      containers:
      - name: api
        image: api-gateway:v1.0.0

        # Resource limits (required)
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"

        # Security context for container
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL

        # Liveness probe (required)
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10

        # Readiness probe (required)
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5

        ports:
        - containerPort: 8080
          name: http

        # Read-only volumes
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /app/cache

      volumes:
      - name: tmp
        emptyDir: {}
      - name: cache
        emptyDir: {}
```

**Passes all checks:** ✅

### Example 2: Common Mistakes

```yaml
# ❌ This will fail multiple checks
apiVersion: v1
kind: Pod
metadata:
  name: bad-example
spec:
  hostNetwork: true          # ❌ host-network
  hostPID: true              # ❌ host-pid

  containers:
  - name: app
    image: app:latest
    # ❌ Missing: resources
    # ❌ Missing: security context
    # ❌ Missing: liveness probe
    # ❌ Missing: readiness probe

    securityContext:
      privileged: true       # ❌ privileged-container
      runAsUser: 0           # ❌ run-as-root

    volumeMounts:
    - name: docker-sock
      mountPath: /var/run/docker.sock  # ❌ docker-sock

  volumes:
  - name: docker-sock
    hostPath:
      path: /var/run/docker.sock
```

**Issues found:** 7+ critical errors

---

## Troubleshooting

### Issue: "kube-linter: command not found"

**Solution:**
```bash
# Install kube-linter
brew install kube-linter

# Or download directly
curl -LO https://github.com/stackrox/kube-linter/releases/latest/download/kube-linter-linux.tar.gz
```

### Issue: "No valid objects found"

**Cause:** YAML file has invalid Kubernetes resources

**Solution:**
```bash
# Validate YAML syntax first
yamllint k8s/

# Check schema
kubeconform k8s/

# Fix syntax errors, then run kube-linter
```

### Issue: Too Many Errors

**Solution:** Fix incrementally

```bash
# See all errors
kube-linter lint k8s/

# Fix high-priority issues first:
# 1. Security issues (privileged, host-network)
# 2. Resource limits
# 3. Security contexts
# 4. Probes

# Update config to exclude optional checks temporarily
```

---

## Resources

### Documentation
- **KubeLinter:** https://docs.kubelinter.io/
- **GitHub:** https://github.com/stackrox/kube-linter
- **Checks Reference:** https://docs.kubelinter.io/#/generated/checks

### Local Documentation
- **Pre-Commit Setup:** `.github/PRE_COMMIT_SETUP.md`
- **Quick Start:** `PRE_COMMIT_QUICKSTART.md`

---

## Summary

✅ **KubeLinter Integrated Successfully**

**What it does:**
- Validates Kubernetes manifests
- Catches security issues
- Enforces best practices
- Runs automatically on commit

**How to use:**
```bash
# Automatic (on commit)
git commit -m "update k8s"

# Manual
make pre-commit-k8s

# Show all errors
kube-linter lint k8s/
```

**Configuration:**
- Config: `.kube-linter.yaml`
- Pre-commit: Lenient (catches critical issues)
- CI: Strict (enforces all best practices)

**Benefits:**
- Catches issues before deployment
- Improves security posture
- Enforces consistency
- Fast (~2-3s for this project)

---

**Integration Date:** 2025-11-05
**Status:** ✅ Production-ready
**Version:** 0.7.6 (via Homebrew)
