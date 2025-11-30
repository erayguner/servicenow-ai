# Contributing to ServiceNow AI Infrastructure

Thank you for your interest in contributing! This document provides guidelines
for contributing to this project.

---

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Conventional Commits](#conventional-commits)
- [Development Workflow](#development-workflow)
- [Pull Request Process](#pull-request-process)
- [Testing Guidelines](#testing-guidelines)
- [Release Process](#release-process)

---

## Code of Conduct

This project adheres to a code of conduct. By participating, you are expected to
uphold this code.

---

## Getting Started

### Prerequisites

- Terraform >= 1.11.0
- Google Cloud SDK
- kubectl
- pre-commit
- Python 3.11+ (for Ruff linting)
- Docker (optional)
- GitHub CLI (optional)

### Setup

1. **Clone the repository**:

   ```bash
   git clone https://github.com/erayguner/servicenow-ai.git
   cd servicenow-ai
   ```

2. **Install dependencies**:

   ```bash
   # Install Terraform
   brew install terraform

   # Install gcloud
   brew install google-cloud-sdk

   # Install kubectl
   brew install kubectl

   # Install pre-commit
   brew install pre-commit
   ```

3. **Install pre-commit hooks**:

   ```bash
   # Install git hooks
   pre-commit install

   # Test hooks (optional)
   pre-commit run --all-files
   ```

   > See [PRE_COMMIT_QUICKSTART.md](PRE_COMMIT_QUICKSTART.md) for details

4. **Configure GCP credentials**:
   ```bash
   gcloud auth application-default login
   gcloud config set project YOUR_PROJECT_ID
   ```

---

## Conventional Commits

This project uses
**[Conventional Commits](https://www.conventionalcommits.org/)** for automated
versioning and changelog generation.

### Commit Message Format

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Commit Types

| Type       | Description                           | Version Bump  |
| ---------- | ------------------------------------- | ------------- |
| `feat`     | A new feature                         | Minor (0.x.0) |
| `fix`      | A bug fix                             | Patch (0.0.x) |
| `docs`     | Documentation only changes            | None          |
| `style`    | Code style changes (formatting, etc.) | None          |
| `refactor` | Code refactoring                      | None          |
| `perf`     | Performance improvements              | Patch         |
| `test`     | Adding/updating tests                 | None          |
| `build`    | Build system changes                  | None          |
| `ci`       | CI/CD changes                         | None          |
| `chore`    | Other changes (dependencies, etc.)    | None          |
| `revert`   | Revert a previous commit              | Patch         |

### Breaking Changes

Add `!` after the type or add `BREAKING CHANGE:` in the footer:

```bash
# Option 1: ! notation
feat!: remove support for Node 12

# Option 2: Footer notation
feat: update authentication flow

BREAKING CHANGE: API endpoints now require authentication header
```

**Result**: Major version bump (x.0.0)

### Examples

#### ✅ Good Commit Messages

```bash
# Feature (minor bump)
feat(gke): add autopilot mode support

# Bug fix (patch bump)
fix(vpc): correct firewall rule priority

# Breaking change (major bump)
feat(cloudsql)!: migrate to Cloud SQL v2 API

# Documentation (no bump)
docs: update deployment instructions

# Multiple changes
feat(workload-identity): add federation support

Adds Workload Identity Federation for GitHub Actions.
Includes keyless authentication and OIDC provider setup.

Closes #123
```

#### ❌ Bad Commit Messages

```bash
# Too vague
update files

# No type
added new feature

# Not following format
FIX: bug in vpc module
```

---

## Development Workflow

### 1. Create a Feature Branch

```bash
git checkout -b feat/your-feature-name
# or
git checkout -b fix/bug-description
```

### 2. Make Your Changes

- Follow Terraform best practices
- Add tests for new modules
- Update documentation

### 3. Test Your Changes

```bash
# Run pre-commit checks (runs automatically on commit)
make pre-commit

# Or run specific checks
make pre-commit-terraform  # Terraform fmt + validate
make pre-commit-python     # Ruff linting
make pre-commit-secrets    # Secret scanning
make pre-commit-k8s        # KubeLinter

# Run Terraform tests
make terraform-test

# Full CI simulation
make ci
```

### 4. Commit Your Changes

```bash
# Stage changes
git add .

# Commit with conventional format (pre-commit runs automatically)
git commit -m "feat(module-name): add new feature"

# If pre-commit modifies files, stage and commit again
git add -u
git commit -m "feat(module-name): add new feature"
```

> **Note**: Pre-commit hooks will run automatically and may auto-fix issues. If
> files are modified, you'll need to stage and commit again.

### 5. Push and Create PR

```bash
git push origin feat/your-feature-name

# Create PR (using GitHub CLI)
gh pr create --title "feat: add new feature" --body "Description of changes"
```

---

## Pull Request Process

### PR Requirements

1. ✅ **Conventional Commit** title format
2. ✅ **Pre-commit checks passing** - All hooks must pass
3. ✅ **Tests passing** - All Terraform tests must pass
4. ✅ **Code formatted** - Terraform fmt, Ruff format
5. ✅ **Security scan clean** - No secrets detected
6. ✅ **Kubernetes lint** - KubeLinter passing
7. ✅ **Documentation updated** - Update README if needed
8. ✅ **No merge conflicts** - Rebase on latest main
9. ✅ **Review approved** - At least one approval required

### PR Title Format

Use conventional commit format for PR titles:

```
feat(gke): add workload identity support
fix(vpc): correct NAT gateway configuration
docs: update deployment guide
```

### PR Description Template

```markdown
## Description

Brief description of changes

## Type of Change

- [ ] Bug fix (patch)
- [ ] New feature (minor)
- [ ] Breaking change (major)
- [ ] Documentation update

## Testing

- [ ] Pre-commit checks pass (`make pre-commit`)
- [ ] Terraform validate passes
- [ ] Terraform test passes
- [ ] KubeLinter passes (if K8s changes)
- [ ] No secrets detected
- [ ] Manual testing completed

## Checklist

- [ ] Code follows project style
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] Tests added/updated
```

---

## Testing Guidelines

### Terraform Module Tests

Each module should have a test file in `tests/basic.tftest.hcl`:

```hcl
# terraform/modules/example/tests/basic.tftest.hcl
mock_provider "google" {}

run "plan_example" {
  command = plan

  variables {
    project_id = "test-project"
    region     = "europe-west2"
  }

  assert {
    condition     = resource.google_example.main.name == "expected-name"
    error_message = "Resource name should match expected value"
  }
}
```

### Frontend Tests

Frontend tests use npm scripts and are automatically detected by the CI/CD
pipeline:

```json
{
  "scripts": {
    "test": "jest", // Unit tests
    "test:integration": "jest --config jest.integration.config.js", // Integration
    "test:e2e": "playwright test", // End-to-end
    "test:security": "jest --config jest.security.config.js" // Security
  }
}
```

The workflow uses **conditional execution** - tests are automatically skipped if
scripts don't exist yet.

### Running Tests

```bash
# Run all pre-commit checks
make pre-commit

# Run all tests
make terraform-test

# Test specific module
cd terraform/modules/gke
terraform test

# Validate all modules
make terraform-validate

# Full CI simulation
make ci

# Quick checks (no terraform validate)
make quick-check

# Frontend tests (when implemented)
cd frontend
npm test                  # Unit tests
npm run test:integration  # Integration tests
npm run test:e2e          # E2E tests
npm run test:security     # Security tests
```

**📚 For comprehensive testing documentation, see
[docs/PARALLEL_TESTING_GUIDE.md](docs/PARALLEL_TESTING_GUIDE.md)**

### Pre-commit Checks

Pre-commit runs the following automatically:

- **trailing-whitespace** - Remove trailing spaces
- **end-of-file-fixer** - Ensure files end with newline
- **check-yaml** - Validate YAML syntax
- **check-json** - Validate JSON syntax
- **pretty-format-json** - Format JSON files
- **ruff-check** - Python linting with auto-fix
- **ruff-format** - Python code formatting
- **detect-secrets** - Scan for credentials
- **terraform_fmt** - Format Terraform files
- **terraform_validate** - Validate Terraform syntax
- **kube-linter-system** - Kubernetes manifest validation

---

## Release Process

This project uses
**[Release Please](https://github.com/googleapis/release-please)** for automated
releases.

### How Releases Work

1. **Commits are pushed to main** using conventional commit format
2. **Release Please analyzes commits** and determines version bump
3. **Release PR is created/updated** with:
   - Updated CHANGELOG.md
   - Version bumps in relevant files
   - Release notes
4. **Merge the Release PR** to:
   - Create GitHub release
   - Tag the release
   - Upload release artifacts

### Release Workflow

```mermaid
graph LR
    A[Conventional Commit] --> B[Push to main]
    B --> C[Release Please analyzes]
    C --> D[Creates/Updates Release PR]
    D --> E[Review & Merge PR]
    E --> F[GitHub Release Created]
    F --> G[Artifacts Uploaded]
```

### Version Bumping

| Commit Type | Example                       | Version Change |
| ----------- | ----------------------------- | -------------- |
| `fix:`      | fix(vpc): correct subnet CIDR | 1.0.0 → 1.0.1  |
| `feat:`     | feat(gke): add autopilot mode | 1.0.0 → 1.1.0  |
| `feat!:`    | feat!: remove deprecated API  | 1.0.0 → 2.0.0  |

### Manual Release Trigger

If needed, you can trigger a release manually:

```bash
# Using GitHub CLI
gh workflow run release-please.yml

# Or via GitHub UI
# Actions → Release Please → Run workflow
```

---

## Code Style Guidelines

### Terraform Style

- Use 2-space indentation
- Run `terraform fmt` before committing
- Use meaningful resource names
- Add comments for complex logic
- Follow module structure:
  ```
  module/
  ├── main.tf       # Main resources
  ├── variables.tf  # Input variables
  ├── outputs.tf    # Output values
  ├── versions.tf   # Provider versions
  └── tests/
      └── basic.tftest.hcl
  ```

### Documentation Style

- Use clear, concise language
- Include code examples
- Add diagrams where helpful
- Keep README.md up to date

---

## Branch Strategy

### Main Branches

- `main` - Production-ready code, protected branch
- `feat/*` - Feature branches
- `fix/*` - Bug fix branches
- `docs/*` - Documentation branches

### Branch Protection

The `main` branch is protected with:

- ✅ Require pull request reviews
- ✅ Require status checks to pass
- ✅ Require branches to be up to date
- ✅ Require conversation resolution
- ❌ No direct pushes allowed

---

## Getting Help

- 📖 Read the [Documentation](./README.md)
- 🐛 Open an [Issue](https://github.com/erayguner/servicenow-ai/issues)
- 💬 Start a
  [Discussion](https://github.com/erayguner/servicenow-ai/discussions)
- 📧 Contact maintainers

---

## License

By contributing, you agree that your contributions will be licensed under the
same license as the project.

---

## Quick Reference

### Common Commands

```bash
# Setup pre-commit
pre-commit install

# Run all checks
make pre-commit

# Conventional commit (pre-commit runs automatically)
git commit -m "feat(gke): add new node pool configuration"

# Run tests
make terraform-test

# Full CI simulation
make ci

# Create PR
gh pr create --title "feat: description" --body "Details"
```

### Useful Links

- [Conventional Commits](https://www.conventionalcommits.org/)
- [Semantic Versioning](https://semver.org/)
- [Release Please](https://github.com/googleapis/release-please)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)

---

**Thank you for contributing! 🎉**
