# Development Environment Setup

This guide covers setting up your local development environment for the ServiceNow AI project.

## Quick Setup

Run the automated setup script:

```bash
./scripts/setup-dev-environment.sh
```

This will install and configure:
- Pre-commit hooks
- Terraform formatting
- Git hooks for automatic validation

## Manual Setup

### Prerequisites

Ensure you have these tools installed:

- **Git** (2.0+)
- **Python** (3.8+) and pip
- **Terraform** (1.11.0+) - [Download](https://developer.hashicorp.com/terraform/downloads)
- **Node.js** (18+) and npm (for Prettier)
- **Go** (1.21+) - for kubeconform (optional)

### 1. Install Pre-commit

Pre-commit automatically checks your code before each commit:

```bash
# Install pre-commit
pip install pre-commit

# Install the git hooks
pre-commit install

# Test the configuration
pre-commit run --all-files
```

### 2. Verify Terraform Installation

```bash
terraform version
```

**Expected:** Terraform v1.11.0 or later

### 3. Install Additional Tools (Optional)

#### kubeconform (Kubernetes validation)
```bash
go install github.com/yannh/kubeconform/cmd/kubeconform@latest
```

#### tflint (Terraform linting)
```bash
# macOS
brew install tflint

# Linux
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

# Windows
choco install tflint
```

## Automatic Formatting

### Terraform Files

**All Terraform files (`.tf`) are automatically formatted before commit.**

#### How It Works:

1. **Pre-commit Hook (Local)**
   - Runs `terraform fmt` on staged `.tf` files
   - Automatically formats before commit
   - Commit fails if formatting changes files

2. **GitHub Actions (CI)**
   - Validates all `.tf` files are formatted
   - Auto-formats and commits on pull requests
   - Blocks merge if formatting is incorrect

#### Manual Formatting:

```bash
# Format all Terraform files
make terraform-fmt

# Format specific directory
terraform fmt -recursive terraform/modules/gke/

# Check formatting without changes
terraform fmt -check -recursive
```

### Pre-commit Configuration

The project uses these pre-commit hooks (`.pre-commit-config.yaml`):

```yaml
- repo: https://github.com/antonbabenko/pre-commit-terraform
  rev: v1.96.1
  hooks:
    - id: terraform_fmt      # Auto-format Terraform files
    # - id: terraform_validate # Validate syntax (optional)
```

## Validation Tools

### Terraform Validation

```bash
# Format check
terraform fmt -check -recursive

# Syntax validation
make terraform-validate

# Security scanning
tflint --recursive

# Full CI validation
make pre-commit
```

### Kubernetes Validation

```bash
# YAML linting
yamllint -c .yamllint.yaml .

# Kubernetes security linting
kube-linter lint k8s

# Schema validation
make kubeconform

# Prettier formatting
prettier --check "**/*.{yml,yaml}"
```

### Python Validation

```bash
# Format check
black --check .

# Linting
ruff check .

# Type checking
mypy --ignore-missing-imports .
```

## Common Workflows

### Before Committing

```bash
# Run all pre-commit hooks
pre-commit run --all-files

# Or run specific hooks
pre-commit run terraform_fmt --all-files
```

### Working with Terraform

```bash
# 1. Make changes to .tf files
vim terraform/modules/gke/main.tf

# 2. Format automatically
terraform fmt terraform/modules/gke/

# 3. Validate syntax
cd terraform/modules/gke && terraform init -backend=false && terraform validate

# 4. Commit (pre-commit will run automatically)
git add terraform/modules/gke/main.tf
git commit -m "feat(gke): add new node pool configuration"
```

### Skipping Pre-commit (Not Recommended)

```bash
# Skip all hooks (use with caution!)
git commit --no-verify -m "wip: temporary commit"
```

⚠️ **Warning:** Skipping pre-commit hooks may cause CI failures. Only use for temporary commits that won't be pushed.

## CI/CD Integration

### Pull Request Workflow

1. **Developer pushes changes**
   ```bash
   git push origin feature/my-feature
   ```

2. **GitHub Actions automatically:**
   - Checks Terraform formatting
   - Validates Terraform syntax
   - Runs tflint security checks
   - Validates Kubernetes manifests
   - Checks YAML/JSON formatting

3. **Auto-formatting (if needed)**
   - If `.tf` files aren't formatted, the `terraform-auto-format` workflow:
     - Formats all Terraform files
     - Commits changes back to the PR
     - Adds a comment to the PR

4. **CI must pass before merge**

### GitHub Actions Workflows

| Workflow | Purpose | Trigger |
|----------|---------|---------|
| `terraform-auto-format.yml` | Auto-format Terraform files | PR with `.tf` changes |
| `terraform-ci-optimized.yml` | Validate all Terraform modules | Push to `terraform/**` |
| `lint.yml` | Lint all code (TF, K8s, Python, YAML) | PR/Push to main/develop |
| `security-check.yml` | Security scanning (tfsec, Checkov) | PR/Push |

## Troubleshooting

### Pre-commit Hook Fails

**Error:** `terraform_fmt failed`

**Solution:**
```bash
# Let pre-commit format the files
pre-commit run terraform_fmt --all-files

# Commit the formatted files
git add .
git commit -m "style(terraform): apply terraform fmt"
```

### Terraform Version Mismatch

**Error:** `Terraform version mismatch`

**Solution:**
```bash
# Check current version
terraform version

# Install specific version (using tfenv)
tfenv install 1.11.0
tfenv use 1.11.0

# Or download from HashiCorp
# https://developer.hashicorp.com/terraform/downloads
```

### Missing Dependencies

**Error:** `command not found: terraform`

**Solution:**
```bash
# macOS
brew install terraform

# Linux - download from HashiCorp
wget https://releases.hashicorp.com/terraform/1.11.0/terraform_1.11.0_linux_amd64.zip
unzip terraform_1.11.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Verify installation
terraform version
```

### Pre-commit Hook Not Running

**Solution:**
```bash
# Reinstall hooks
pre-commit uninstall
pre-commit install

# Verify installation
ls -la .git/hooks/pre-commit
```

## IDE Integration

### VS Code

Install these extensions:

```json
{
  "recommendations": [
    "hashicorp.terraform",
    "ms-python.python",
    "ms-python.black-formatter",
    "esbenp.prettier-vscode",
    "redhat.vscode-yaml"
  ]
}
```

Configure auto-format on save (`.vscode/settings.json`):

```json
{
  "editor.formatOnSave": true,
  "[terraform]": {
    "editor.defaultFormatter": "hashicorp.terraform",
    "editor.formatOnSave": true
  },
  "[python]": {
    "editor.defaultFormatter": "ms-python.black-formatter",
    "editor.formatOnSave": true
  }
}
```

### JetBrains IDEs (IntelliJ, PyCharm)

1. Install **HashiCorp Terraform / HCL** plugin
2. Enable auto-format on save:
   - Settings → Tools → Actions on Save
   - Check "Reformat code"
   - Configure file patterns: `*.tf`

## Make Targets Reference

```bash
# Pre-commit
make pre-commit              # Run all pre-commit hooks
make pre-commit-install      # Install hooks
make pre-commit-terraform    # Run Terraform hooks only

# Terraform
make terraform-fmt           # Format all Terraform files
make terraform-validate      # Validate all modules
make terraform-test          # Run Terraform tests

# Kubernetes
make kubeconform            # Validate K8s manifests

# Cleanup
make clean                  # Clean temporary files
```

## Best Practices

### 1. **Always format before committing**
   ```bash
   terraform fmt -recursive
   ```

### 2. **Validate syntax locally**
   ```bash
   make terraform-validate
   ```

### 3. **Run pre-commit before pushing**
   ```bash
   pre-commit run --all-files
   ```

### 4. **Keep Terraform version consistent**
   - Use version `1.11.0` (matches CI)
   - Check `.github/workflows/terraform-ci-optimized.yml` for current version

### 5. **Review auto-formatted changes**
   - Always review what `terraform fmt` changed
   - Ensure formatting doesn't break functionality

### 6. **Use consistent commit messages**
   ```bash
   # Good
   git commit -m "feat(gke): add GPU node pool configuration"
   git commit -m "fix(terraform): correct IAM role permissions"

   # Bad
   git commit -m "updated files"
   git commit -m "wip"
   ```

## Getting Help

- **Documentation:** See `docs/` directory
- **Makefile:** Run `make help` for all available commands
- **CI Logs:** Check GitHub Actions for detailed error messages
- **Terraform Docs:** https://developer.hashicorp.com/terraform/docs

## Additional Resources

- [Terraform Style Guide](https://developer.hashicorp.com/terraform/language/syntax/style)
- [Pre-commit Documentation](https://pre-commit.com/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
