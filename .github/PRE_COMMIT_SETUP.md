# Pre-Commit Setup Guide

## Overview

This repository uses [pre-commit](https://pre-commit.com/) to automatically check and fix common issues before commits.

---

## What Pre-Commit Does

Pre-commit runs the following checks automatically:

### 1. **Basic File Checks**
- ✅ Removes trailing whitespace
- ✅ Ensures files end with newline
- ✅ Validates YAML syntax (including Kubernetes multi-document files)
- ✅ Validates JSON syntax
- ✅ Formats JSON files consistently

### 2. **Python Linting** (if Python files exist)
- ✅ Runs `ruff` for linting with auto-fix
- ✅ Runs `ruff-format` for code formatting

### 3. **Security**
- ✅ Scans for secrets (API keys, tokens, passwords)
- ✅ Uses baseline to avoid false positives

### 4. **Terraform**
- ✅ Formats Terraform files (`terraform fmt`)
- ✅ Validates Terraform syntax (`terraform validate`)

### 5. **Kubernetes** ☸️ (~2-3s)
- ✅ Validates Kubernetes manifests
- ✅ Checks for security issues
- ✅ Enforces best practices

---

## Installation

### One-Time Setup

```bash
# Install pre-commit (if not already installed)
brew install pre-commit  # macOS
# or
pip install pre-commit  # Python/pip

# Install the git hooks
cd /Users/eray/servicenow-ai
pre-commit install
```

**That's it!** Pre-commit will now run automatically on every commit.

---

## Usage

### Automatic (Recommended)

Pre-commit runs automatically when you commit:

```bash
git add .
git commit -m "your message"
# Pre-commit runs automatically and may modify files
# If files were modified, you'll need to stage and commit again
```

### Manual Testing

Run pre-commit manually on all files:

```bash
# Run on all files
pre-commit run --all-files

# Run specific hook
pre-commit run terraform_fmt --all-files
pre-commit run detect-secrets --all-files

# Run on specific files
pre-commit run --files terraform/modules/vpc/*.tf
```

### Using Make (Easier)

We've provided a Makefile for convenience:

```bash
# Run all pre-commit checks
make pre-commit

# Run specific checks
make pre-commit-terraform
make pre-commit-python
make pre-commit-secrets

# Skip pre-commit for a single commit (emergency only!)
git commit --no-verify -m "emergency fix"
```

---

## Common Workflows

### Normal Commit Workflow

```bash
# 1. Make your changes
vim terraform/modules/vpc/main.tf

# 2. Add files
git add terraform/modules/vpc/main.tf

# 3. Commit (pre-commit runs automatically)
git commit -m "feat: add VPC peering support"

# If pre-commit modified files:
# 4. Stage the auto-fixed files
git add -u

# 5. Commit again
git commit -m "feat: add VPC peering support"
```

### Test Before Committing

```bash
# Run pre-commit before staging
make pre-commit

# Review changes
git diff

# Stage and commit
git add -A
git commit -m "your message"
```

### CI/CD Integration

Pre-commit also runs in GitHub Actions (`.github/workflows/lint.yml`):
- Runs on every PR and push to main/develop
- Same checks as local pre-commit
- Ensures consistency across team

---

## Hooks Configuration

The configuration is in `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    hooks:
      - trailing-whitespace  # Removes trailing spaces
      - end-of-file-fixer   # Ensures final newline
      - check-yaml          # Validates YAML
      - check-json          # Validates JSON
      - pretty-format-json  # Formats JSON

  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.14.3
    hooks:
      - ruff-check     # Python linting (with --fix)
      - ruff-format    # Python formatting

  - repo: https://github.com/Yelp/detect-secrets
    hooks:
      - detect-secrets  # Finds secrets/credentials

  - repo: https://github.com/antonbabenko/pre-commit-terraform
    hooks:
      - terraform_fmt       # Formats Terraform
      - terraform_validate  # Validates Terraform
```

---

## Secrets Detection

### How It Works

The `detect-secrets` hook scans for:
- API keys (AWS, GCP, GitHub, etc.)
- Private keys and certificates
- Passwords and tokens
- Other sensitive data

### Baseline File

The `.secrets.baseline` file stores known "secrets" that are actually safe:
- Example values in documentation
- Test fixtures
- Public keys

### If You Get a False Positive

1. **Review the detected secret** - Is it actually sensitive?

2. **If it's safe**, update the baseline:
   ```bash
   detect-secrets scan --update .secrets.baseline
   ```

3. **If it's real**, remove it and use environment variables or secret management

### Adding Real Secrets

**Never commit real secrets!** Instead:

```bash
# Use environment variables
export API_KEY="your-key"

# Or use GCP Secret Manager
gcloud secrets create my-secret --data-file=-

# Or use .env files (add .env to .gitignore)
echo "API_KEY=your-key" > .env
```

---

## Terraform Validation

### What It Checks

The `terraform_validate` hook:
- Runs `terraform init` (in backend-less mode)
- Runs `terraform validate`
- Checks syntax and configuration

### Module-Level Validation

Validation runs on each module independently:
- `terraform/modules/vpc/`
- `terraform/modules/gke/`
- `terraform/environments/dev/`
- etc.

### If Validation Fails

1. **Check the error message** - Usually syntax or missing variables

2. **Test manually**:
   ```bash
   cd terraform/modules/vpc
   terraform init
   terraform validate
   ```

3. **Fix the issue** and commit again

### Skipping Validation (Not Recommended)

If you must skip validation (e.g., incomplete WIP):

```bash
# Skip all pre-commit hooks
git commit --no-verify -m "WIP: incomplete module"

# Or disable specific hook temporarily
pre-commit run --hook-stage manual terraform_validate
```

---

## Terraform Formatting

### Automatic Formatting

The `terraform_fmt` hook automatically formats Terraform files:

```hcl
# Before
resource"google_compute_network""vpc"{name="my-vpc"}

# After (automatically formatted)
resource "google_compute_network" "vpc" {
  name = "my-vpc"
}
```

### Manual Formatting

```bash
# Format all Terraform files
terraform fmt -recursive

# Format specific directory
terraform fmt terraform/modules/vpc/

# Check formatting without changes
terraform fmt -check -recursive
```

---

## Troubleshooting

### Issue: "pre-commit: command not found"

**Solution:**
```bash
brew install pre-commit
# or
pip install pre-commit
```

### Issue: "detect-secrets: command not found"

**Solution:** Pre-commit will install it automatically on first run:
```bash
pre-commit run detect-secrets --all-files
```

### Issue: "terraform: command not found"

**Solution:**
```bash
brew install terraform
# or follow: https://developer.hashicorp.com/terraform/downloads
```

### Issue: "Hook failed, but files were modified"

**Solution:** This is normal! Stage and commit the auto-fixed files:
```bash
git add -u
git commit -m "your message"
```

### Issue: "Validation failed: Invalid baseline"

**Solution:** Regenerate the secrets baseline:
```bash
python3 -c "import json; print(json.dumps({'version': '1.5.0', 'plugins_used': [], 'results': {}}, indent=2))" > .secrets.baseline
```

### Issue: "terraform init failed in pre-commit"

**Solution:** This can happen if:
- Module dependencies changed
- Provider versions conflict
- Network issues

Fix:
```bash
# Clean Terraform cache
rm -rf terraform/modules/*/.terraform

# Run pre-commit again
pre-commit run terraform_validate --all-files
```

---

## Updating Pre-Commit Hooks

Keep hooks up to date:

```bash
# Update to latest versions
pre-commit autoupdate

# Review changes
git diff .pre-commit-config.yaml

# Test
pre-commit run --all-files

# Commit
git add .pre-commit-config.yaml
git commit -m "chore: update pre-commit hooks"
```

---

## CI/CD Integration

Pre-commit runs in GitHub Actions:

**File:** `.github/workflows/lint.yml`

**Runs:**
- On every PR
- On push to main/develop
- Same hooks as local pre-commit

**Benefits:**
- Enforces standards across team
- Catches issues before merge
- No "works on my machine" problems

---

## Best Practices

### ✅ Do

- Run `pre-commit run --all-files` before opening PR
- Keep `.secrets.baseline` up to date
- Fix issues instead of skipping hooks
- Update hook versions regularly
- Review auto-fixed changes before committing

### ❌ Don't

- Use `--no-verify` for normal commits
- Commit real secrets (use environment variables)
- Disable hooks without team discussion
- Skip CI checks in PRs

---

## Performance

### Hook Timing

Typical run times on this project:

| Hook | Time | Why |
|------|------|-----|
| trailing-whitespace | ~0.5s | Fast (regex) |
| terraform_fmt | ~1s | Fast (local) |
| detect-secrets | ~2s | Medium (file scanning) |
| terraform_validate | ~10s | Slow (init + validate) |

### Optimization Tips

1. **Only commit relevant files**
   ```bash
   git add terraform/modules/vpc/  # Not the entire repo
   ```

2. **Use `--files` for testing**
   ```bash
   pre-commit run --files terraform/modules/vpc/*.tf
   ```

3. **Skip expensive hooks for WIP commits**
   ```bash
   SKIP=terraform_validate git commit -m "WIP"
   ```

---

## Advanced Configuration

### Exclude Files

Add to `.pre-commit-config.yaml`:

```yaml
exclude: |
  (?x)^(
    vendor/.*|
    \.terraform/.*|
    node_modules/.*
  )$
```

### Add Custom Hooks

```yaml
- repo: local
  hooks:
    - id: custom-check
      name: Custom validation
      entry: ./scripts/custom-check.sh
      language: script
```

### Run Hooks in Docker

```yaml
- repo: https://github.com/pre-commit/pre-commit-hooks
  hooks:
    - id: trailing-whitespace
      language: docker
      entry: python:3.11
```

---

## Support

### Documentation

- **Pre-commit:** https://pre-commit.com/
- **Ruff:** https://docs.astral.sh/ruff/
- **Detect Secrets:** https://github.com/Yelp/detect-secrets
- **Terraform Hooks:** https://github.com/antonbabenko/pre-commit-terraform

### Getting Help

1. Check this guide
2. Review hook output (usually clear error messages)
3. Test manually with tool directly (`terraform validate`, `ruff check`, etc.)
4. Check GitHub Actions logs for CI failures

---

## Quick Reference

```bash
# Install
pre-commit install

# Run all hooks
pre-commit run --all-files

# Run specific hook
pre-commit run terraform_fmt --all-files

# Update hooks
pre-commit autoupdate

# Skip for one commit (emergency)
git commit --no-verify

# Clean cache
pre-commit clean

# Uninstall
pre-commit uninstall
```

---

## Summary

✅ **Pre-commit is installed and configured!**

**What happens now:**
1. You make changes and commit
2. Pre-commit runs automatically
3. Files are checked and auto-fixed
4. You review and commit again if needed

**Benefits:**
- ✅ Consistent code formatting
- ✅ Catches errors before CI
- ✅ Prevents secret leaks
- ✅ Enforces best practices
- ✅ Saves review time

**Next steps:**
- Test it: `make pre-commit`
- Make a commit and see it work!
- Enjoy cleaner commits! 🚀
