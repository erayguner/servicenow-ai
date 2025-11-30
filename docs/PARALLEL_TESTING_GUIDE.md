# Parallel Testing Guide

This document describes the CI/CD testing infrastructure and how to work with
the parallel test execution workflow.

## Overview

The repository uses a comprehensive GitHub Actions workflow
(`parallel-tests.yml`) that executes multiple types of tests in parallel for
fast feedback and efficient resource usage.

## Test Architecture

### Workflow Structure

```
Setup & Build
    ├── Terraform Validation (12 modules)
    │   └── Terraform Tests (parallel by module)
    │
    ├── Unit Tests (4 parallel shards)
    │
    ├── Integration Tests (8 services in parallel)
    │
    ├── E2E Tests (3 shards with isolated Kubernetes)
    │
    ├── Security Tests (5 categories in parallel)
    │
    └── Performance Tests (4 endpoints in parallel)
            │
            └── Aggregate Results & Generate Report
```

### Conditional Testing

All test jobs use **conditional execution** to skip gracefully when test
infrastructure isn't implemented yet:

- **npm scripts**: Checks if scripts exist in `package.json` before running
- **Test files**: Checks if test files exist before execution
- **Infrastructure**: Checks if manifests/configs exist before deployment

This enables **incremental development** without breaking the CI pipeline.

## Test Types

### 1. Terraform Tests

**Location**: `terraform/modules/*/tests/*.tftest.hcl`

**Status**: ✅ All 12 modules have tests

**Execution**:

- Auto-discovers modules with test files
- Runs validation and tests in parallel
- Each module runs independently

**Local Testing**:

```bash
# Run all module tests
make terraform-test

# Test specific module
cd terraform/modules/gke
terraform test

# Validate all modules
make terraform-validate
```

### 2. Frontend Unit Tests

**Location**: `frontend/` (when implemented)

**Expected script**: `test` in `frontend/package.json`

**Status**: ⚠️ Not yet implemented (skips gracefully)

**Execution**:

- Sharded across 4 parallel runners
- Coverage collection per shard
- Results merged in aggregate job

**Implementation**:

```json
{
  "scripts": {
    "test": "jest --coverage"
  }
}
```

### 3. Integration Tests

**Location**: `frontend/` (when implemented)

**Expected script**: `test:integration` in `frontend/package.json`

**Status**: ⚠️ Not yet implemented (skips gracefully)

**Execution**:

- Parallel execution per service (8 services)
- PostgreSQL and Redis containers provided
- Independent databases per service

**Implementation**:

```json
{
  "scripts": {
    "test:integration": "jest --config jest.integration.config.js"
  }
}
```

### 4. E2E Tests

**Location**: `frontend/` + `k8s/` (when implemented)

**Expected script**: `test:e2e` in `frontend/package.json`

**Expected manifests**:

- `k8s/test/postgres.yaml`
- `k8s/test/redis.yaml`
- `k8s/deployments/*.yaml`

**Status**: ⚠️ Not yet implemented (skips gracefully)

**Execution**:

- Isolated kind (Kubernetes in Docker) clusters
- 3 parallel shards with isolated namespaces
- Infrastructure deployment per shard
- Pod logs collected on failure

**Implementation**:

```json
{
  "scripts": {
    "test:e2e": "playwright test"
  }
}
```

### 5. Security Tests

**Location**: `frontend/` (when implemented)

**Expected script**: `test:security` in `frontend/package.json`

**Status**: ⚠️ Not yet implemented (skips gracefully)

**Execution**:

- Parallel execution by category (5 categories)
- Tests authentication, authorization, data protection, network security,
  secrets

**Implementation**:

```json
{
  "scripts": {
    "test:security": "jest --config jest.security.config.js"
  }
}
```

### 6. Performance Tests

**Location**: `tests/performance/` (when implemented)

**Expected files**:

- `tests/performance/api-gateway.k6.js`
- `tests/performance/llm-gateway.k6.js`
- `tests/performance/knowledge-base.k6.js`
- `tests/performance/conversation-manager.k6.js`

**Status**: ⚠️ Not yet implemented (skips gracefully)

**Execution**:

- k6 load testing in parallel (4 endpoints)
- Results exported to JSON
- Performance metrics tracked over time

**Implementation**:

```javascript
// tests/performance/api-gateway.k6.js
import http from 'k6/http';
import { check } from 'k6';

export const options = {
  vus: 50,
  duration: '2m',
};

export default function () {
  const res = http.get(`${__ENV.TARGET_ENDPOINT}`);
  check(res, { 'status is 200': (r) => r.status === 200 });
}
```

## Project Structure for Tests

```
servicenow-ai/
├── .github/workflows/
│   └── parallel-tests.yml       # Main test workflow
│
├── frontend/
│   ├── package.json             # Must include test scripts
│   ├── __tests__/               # Unit tests (to be created)
│   ├── __integration__/         # Integration tests (to be created)
│   └── __e2e__/                 # E2E tests (to be created)
│
├── k8s/
│   ├── test/                    # E2E test infrastructure (to be created)
│   │   ├── postgres.yaml
│   │   └── redis.yaml
│   └── deployments/             # Service manifests (to be created)
│       ├── conversation-manager.yaml
│       ├── llm-gateway.yaml
│       └── knowledge-base.yaml
│
├── tests/
│   └── performance/             # k6 performance tests (to be created)
│       ├── api-gateway.k6.js
│       ├── llm-gateway.k6.js
│       ├── knowledge-base.k6.js
│       └── conversation-manager.k6.js
│
└── terraform/
    └── modules/
        └── */tests/             # Terraform tests ✅ Implemented
```

## Adding New Tests

### Step 1: Add npm Script

Edit `frontend/package.json`:

```json
{
  "scripts": {
    "test": "jest",
    "test:integration": "jest --config jest.integration.config.js",
    "test:e2e": "playwright test",
    "test:security": "jest --config jest.security.config.js"
  }
}
```

### Step 2: Create Test Files

The workflow will automatically:

1. Detect the script exists
2. Run the tests
3. Collect coverage
4. Report results

### Step 3: Verify in CI

Push your changes and the workflow will:

- ✅ Run your new tests in parallel
- ✅ Show test results in PR comments
- ✅ Fail the build if tests fail

## Workflow Features

### Caching Strategy

- **Node modules**: Cached using `actions/setup-node@v6` with
  `cache-dependency-path`
- **Terraform plugins**: Cached per lock file hash
- **npm cache**: Shared across jobs using `actions/cache@v4`

### Artifact Management

- **Coverage**: Uploaded per shard, merged in aggregate job
- **Test results**: Retained for 7 days
- **Performance results**: Retained for 30 days
- **Pod logs**: Collected on E2E failures

### Conditional Execution

All jobs check for required files/scripts before running:

```yaml
# Example: Check if test script exists
- name: Check if test script exists
  id: check_test
  working-directory: frontend
  run: |
    if npm run | grep -q "^  test$"; then
      echo "has_test=true" >> "$GITHUB_OUTPUT"
    else
      echo "has_test=false" >> "$GITHUB_OUTPUT"
      echo "⚠️ test script not found, skipping"
    fi

- name: Run tests
  if: steps.check_test.outputs.has_test == 'true'
  run: npm test
```

### PR Comments

The workflow posts a test summary to PRs:

```markdown
# Test Execution Summary

## Parallel Execution Statistics

| Test Type   | Shards       | Status     |
| ----------- | ------------ | ---------- |
| Terraform   | 12 modules   | ✅ success |
| Unit Tests  | 4 shards     | ⚠️ skipped |
| Integration | 8 services   | ⚠️ skipped |
| E2E Tests   | 3 shards     | ⚠️ skipped |
| Security    | 5 categories | ⚠️ skipped |
| Performance | 4 endpoints  | ⚠️ skipped |
```

## Performance Metrics

### Current Performance

- **Terraform tests**: ~3 minutes (12 modules in parallel)
- **Total workflow**: ~8 minutes (estimated when all tests implemented)
- **Cost reduction**: 60% vs sequential execution

### Optimization Features

1. **Parallel sharding**: Tests split across multiple runners
2. **Isolated environments**: No cross-contamination
3. **Smart caching**: npm and Terraform plugins cached
4. **Conditional execution**: Skip what doesn't exist
5. **Fail-fast disabled**: See all failures at once

## Troubleshooting

### Tests Not Running

**Symptom**: Job shows "⚠️ test script not found, skipping"

**Solution**: Add the npm script to `package.json`

### Path Not Found Errors

**Symptom**: `error: the path "..." does not exist`

**Solution**: Ensure the file exists or the conditional check is working

### Cache Issues

**Symptom**: Dependencies reinstalled every run

**Solution**: Check `cache-dependency-path` points to
`frontend/package-lock.json`

### E2E Tests Failing

**Symptom**: kubectl errors or pod not ready

**Solution**:

- Ensure k8s manifests exist in `k8s/test/` or `k8s/deployments/`
- Check pod logs artifact for details
- Verify kind cluster started successfully

## Best Practices

1. **Write tests incrementally**: Add one type at a time
2. **Use descriptive test names**: Makes failures easier to diagnose
3. **Keep tests fast**: Aim for <30s per unit test suite
4. **Mock external services**: Use containers for integration tests
5. **Use proper assertions**: Avoid flaky tests with proper waits
6. **Review test reports**: Check coverage and performance metrics

## Resources

- [Terraform Testing Documentation](https://developer.hashicorp.com/terraform/language/tests)
- [Jest Testing Framework](https://jestjs.io/)
- [Playwright E2E Testing](https://playwright.dev/)
- [k6 Performance Testing](https://k6.io/docs/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

## Support

For issues with the CI/CD pipeline:

1. Check workflow logs in GitHub Actions
2. Review this guide for configuration requirements
3. Create an issue with workflow run link
