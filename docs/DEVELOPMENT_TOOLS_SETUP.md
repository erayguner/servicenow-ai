# Development Tools Setup

**Date:** 2025-11-16
**Author:** Claude AI Assistant
**Session ID:** claude/setup-dev-tools-01NXhnBBL19CQNJokXdcKTZ6

## Overview

This document describes the development tools installed and configured for the ServiceNow AI project, including the tools added in this setup session and recommendations for future improvements.

## Installed Tools

### 1. Terraform v1.9.8

**Location:** `~/.local/bin/terraform`

**Purpose:** Infrastructure as Code (IaC) tool for managing cloud resources

**Status:** ✅ Installed and configured

**Usage:**
```bash
terraform --version
# Terraform v1.9.8

# Format Terraform files
terraform fmt -recursive

# Validate configuration
terraform validate

# Run tests
terraform test
```

**Integration:**
- Pre-commit hook: `terraform_fmt` and `terraform_validate`
- CI workflow: `.github/workflows/terraform-ci-optimized.yml`
- 17 Terraform modules with comprehensive test coverage
- Makefile targets: `make terraform-fmt`, `make terraform-validate`, `make terraform-test`

### 2. Checkov v3.2.493

**Location:** `~/.local/bin/checkov`

**Purpose:** Infrastructure security and compliance scanning

**Status:** ✅ Installed and configured

**Usage:**
```bash
checkov --version
# 3.2.493

# Scan Terraform files
checkov -d terraform/

# Scan Kubernetes manifests
checkov -d k8s/

# Scan Dockerfiles
checkov -f backend/Dockerfile
```

**Integration:**
- Used in CI/CD for security scanning
- Scans: Terraform, Kubernetes, Dockerfiles
- Security report: `docs/SECURITY_CHECKOV_REPORT.md`

### 3. Ruff Linter v0.14.3

**Location:** `/root/.local/bin/ruff`

**Purpose:** Fast Python linter and formatter

**Status:** ✅ Already installed (verified)

**Usage:**
```bash
ruff --version
# ruff 0.14.3

# Check Python files
ruff check .

# Format Python files
ruff format .
```

**Integration:**
- Pre-commit hook: `.pre-commit-config.yaml`
- Replaces: Black (formatter) + Flake8 (linter)
- Makefile target: `make pre-commit-python`

### 4. npx Tools Tested

**Attempted Commands:**
```bash
npx agentic flow       # ❌ Package not found
npx claude flow@alpha  # ⏸️ Attempted but incomplete
npx agentdb           # ✅ Successfully executed
```

**agentdb Features:**
- Frontier memory features for AI agents
- Vector search and similarity queries
- Reflexion: Episode storage and retrieval
- Skill management and consolidation
- Causal inference and A/B experiments
- QUIC synchronization for multi-agent coordination

## New Configurations Added

### 1. ESLint Configuration

**File:** `backend/.eslintrc.js`

**Features:**
- TypeScript support with type-aware linting
- Recommended rules from `@typescript-eslint`
- Security rules (no-eval, no-implied-eval)
- Code quality rules (max-lines, complexity)
- Custom rules for Express.js backend

**Usage:**
```bash
cd backend
npm run lint        # Check for errors
npm run lint:fix    # Auto-fix errors
```

### 2. Prettier Configuration

**Files:**
- `.prettierrc.json` - Formatting rules
- `.prettierignore` - Files to ignore

**Features:**
- Single quotes, semicolons, trailing commas
- 100 character line length
- Consistent formatting across all files
- Special rules for JSON and Markdown

**Usage:**
```bash
npm run format       # Format all files
npm run format:check # Check formatting
```

### 3. Jest Configuration

**File:** `backend/jest.config.js`

**Features:**
- TypeScript support with ts-jest
- Coverage thresholds: 70% (branches, functions, lines, statements)
- Multiple test types supported:
  - Unit tests: `*.test.ts`
  - Integration tests: `*.integration.test.ts`
  - E2E tests: `*.e2e.test.ts`
  - Security tests: `*.security.test.ts`
- Coverage reports: text, lcov, html, json-summary
- Test setup file: `backend/src/test/setup.ts`

**Usage:**
```bash
cd backend
npm test                  # Run all tests
npm run test:unit         # Unit tests only
npm run test:integration  # Integration tests
npm run test:e2e         # E2E tests
npm run test:security    # Security tests
npm run test:watch       # Watch mode
npm run test:coverage    # With coverage
```

### 4. Docker Compose for Local Development

**Files:**
- `docker-compose.yml` - Main configuration
- `docker-compose.dev.yml` - Development overrides
- `.env.example` - Environment template

**Services:**
- **postgres** - PostgreSQL 16 database
- **redis** - Redis 7 cache
- **backend** - Express.js API (port 3001)
- **frontend** - Next.js app (port 3000)
- **firestore-emulator** - GCP Firestore emulator

**Usage:**
```bash
# Copy environment file
cp .env.example .env

# Start all services
docker-compose up -d

# Start with hot reload
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up

# View logs
docker-compose logs -f

# Stop services
docker-compose down

# Stop and remove volumes
docker-compose down -v
```

**Ports:**
- 3000 - Frontend (Next.js)
- 3001 - Backend (Express.js API)
- 5432 - PostgreSQL
- 6379 - Redis
- 8080 - Firestore Emulator
- 4000 - Firestore Admin UI

### 5. EditorConfig

**File:** `.editorconfig`

**Features:**
- UTF-8 charset
- LF line endings
- 2-space indentation for TS/JS/YAML
- 4-space indentation for Python
- Tab indentation for Go and Makefiles
- Consistent settings across editors (VS Code, IntelliJ, Vim, etc.)

**Supported Editors:**
Most modern editors support EditorConfig natively or via plugin.

## Package.json Updates

### Backend Scripts Added

```json
{
  "scripts": {
    "test:watch": "jest --watch",
    "test:coverage": "jest --coverage",
    "test:unit": "jest --testPathPattern=\\.test\\.ts$",
    "test:integration": "jest --testPathPattern=\\.integration\\.test\\.ts$",
    "test:e2e": "jest --testPathPattern=\\.e2e\\.test\\.ts$",
    "test:security": "jest --testPathPattern=\\.security\\.test\\.ts$",
    "lint:fix": "eslint src --ext .ts --fix",
    "format:check": "prettier --check \"src/**/*.ts\""
  }
}
```

### New Dependencies Added

```json
{
  "devDependencies": {
    "@types/jest": "^29.5.14",
    "ts-jest": "^29.2.5"
  }
}
```

## Integration with CI/CD

All new configurations integrate seamlessly with existing GitHub Actions workflows:

### 1. Lint Workflow (`.github/workflows/lint.yml`)

- ✅ ESLint configuration will be used when linting TypeScript
- ✅ Prettier configuration will be used for formatting checks
- Conditional execution based on changed files

### 2. Parallel Tests Workflow (`.github/workflows/parallel-tests.yml`)

- ✅ Jest configuration enables all test types
- ✅ New npm scripts support matrix testing
- ✅ Coverage reports will be generated
- Expected test categories:
  - Unit tests (4 shards)
  - Integration tests (8 services)
  - E2E tests (3 shards with Kind clusters)
  - Security tests (5 categories)

### 3. Pre-commit Hooks

All tools integrate with existing pre-commit configuration:
- Terraform: fmt + validate
- Python: Ruff linting + formatting
- Secrets: detect-secrets
- YAML: yamllint
- Kubernetes: kube-linter

## Next Steps: Recommended Improvements

### High Priority (Implement Next)

1. **Write Test Suites**
   - Create initial test files for critical paths
   - Target: 70%+ code coverage
   - Focus: API endpoints, authentication, database operations

2. **Install Missing Dependencies**
   ```bash
   cd backend
   npm install  # Will install @types/jest and ts-jest
   ```

3. **API Documentation**
   - Add OpenAPI/Swagger specification
   - Serve docs at `/api-docs`
   - Auto-generate from code annotations

### Medium Priority (Within 2 Weeks)

4. **Frontend Testing Setup**
   - React Testing Library
   - Playwright or Cypress for E2E
   - Visual regression testing

5. **Code Coverage Enforcement**
   - Enforce 70% threshold in CI
   - Upload to Codecov
   - Block PRs below threshold

6. **Performance Monitoring**
   - Lighthouse CI
   - Web Vitals monitoring
   - Performance budgets

### Low Priority (Nice to Have)

7. **Enhanced Git Hooks**
   - Commitlint for conventional commits
   - Branch name validation
   - Ticket reference enforcement

8. **Code Quality Metrics**
   - SonarCloud integration
   - Technical debt tracking
   - Maintainability scores

9. **Bundle Analysis**
   - @next/bundle-analyzer
   - Size limits in CI
   - Tree-shaking optimization

## Quick Reference

### Running Development Environment

```bash
# Option 1: Docker Compose (recommended)
docker-compose up -d

# Option 2: Local development
cd backend && npm run dev
cd frontend && npm run dev

# Run tests
cd backend && npm test

# Run linters
npm run lint
npm run format:check

# Run pre-commit hooks
make pre-commit
```

### Verifying Tool Installation

```bash
# Check Terraform
terraform --version

# Check Checkov
checkov --version

# Check Ruff
ruff --version

# Check Node/npm tools
cd backend
npm run lint -- --version
npm run format -- --version
npx jest --version
```

### Project Structure

```
servicenow-ai/
├── .editorconfig                 # NEW: Editor consistency
├── .prettierrc.json             # NEW: Prettier config
├── .prettierignore              # NEW: Prettier ignore
├── .env.example                 # NEW: Environment template
├── docker-compose.yml           # NEW: Local dev environment
├── docker-compose.dev.yml       # NEW: Dev overrides
├── backend/
│   ├── .eslintrc.js            # NEW: ESLint config
│   ├── jest.config.js          # NEW: Jest config
│   ├── package.json            # UPDATED: New scripts & deps
│   └── src/
│       └── test/
│           └── setup.ts        # NEW: Jest setup
├── frontend/
│   └── ... (no changes)
├── terraform/
│   └── ... (17 modules, already configured)
├── k8s/
│   └── ... (already configured)
└── docs/
    └── DEVELOPMENT_TOOLS_SETUP.md  # NEW: This file
```

## Troubleshooting

### ESLint Errors

```bash
# Fix auto-fixable issues
cd backend && npm run lint:fix

# Check specific file
npx eslint src/index.ts
```

### Prettier Formatting

```bash
# Format all files
npm run format

# Check without modifying
npm run format:check
```

### Jest Test Failures

```bash
# Run with verbose output
npm test -- --verbose

# Run specific test file
npm test -- src/path/to/test.test.ts

# Update snapshots
npm test -- -u
```

### Docker Compose Issues

```bash
# Rebuild containers
docker-compose build --no-cache

# View container logs
docker-compose logs -f backend

# Check container status
docker-compose ps

# Remove all containers and volumes
docker-compose down -v
```

## Additional Resources

- [ESLint Documentation](https://eslint.org/docs/latest/)
- [Prettier Documentation](https://prettier.io/docs/en/)
- [Jest Documentation](https://jestjs.io/docs/getting-started)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Terraform Documentation](https://developer.hashicorp.com/terraform/docs)
- [Checkov Documentation](https://www.checkov.io/documentation/)
- [Ruff Documentation](https://docs.astral.sh/ruff/)

## Summary

### What We Accomplished

✅ Installed Terraform v1.9.8
✅ Installed Checkov v3.2.493
✅ Verified Ruff v0.14.3 installation
✅ Created ESLint configuration for backend
✅ Created Prettier configuration (root level)
✅ Created Jest configuration with test setup
✅ Added missing npm test scripts
✅ Created Docker Compose for local development
✅ Created .editorconfig for editor consistency
✅ Updated backend package.json with new dependencies

### Key Benefits

1. **Consistent Code Quality:** ESLint + Prettier ensure code consistency
2. **Comprehensive Testing:** Jest config supports unit, integration, E2E, and security tests
3. **Local Development:** Docker Compose provides full-stack local environment
4. **Security:** Checkov scans infrastructure for security issues
5. **Infrastructure:** Terraform manages cloud resources
6. **Editor Support:** EditorConfig ensures consistent settings across team

### What's Missing (Needs Implementation)

⚠️ **Test Files:** No actual test files exist yet (*.test.ts, *.integration.test.ts)
⚠️ **Dependencies:** Need to run `npm install` to install new packages
⚠️ **API Docs:** No OpenAPI/Swagger specification
⚠️ **Frontend Testing:** No testing framework configured for Next.js

---

**Next Session:** Focus on implementing test suites to achieve 70%+ code coverage
