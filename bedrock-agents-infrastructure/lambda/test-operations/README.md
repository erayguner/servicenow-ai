# Test Operations Lambda Function

Lambda function for Bedrock Agent test operations action group. Provides test
generation, execution, and coverage reporting capabilities with Jest
integration.

## Features

### 1. Generate Tests (`generate-tests`)

Automatically generate comprehensive test suites for source files.

**Parameters:**

- `sourceFile` (required): Path to source file to generate tests for
- `testFramework` (optional): Testing framework (jest, mocha, vitest, pytest) -
  default: jest
- `testType` (optional): Type of tests (unit, integration, e2e, performance) -
  default: unit
- `coverage` (optional): Coverage level (basic, comprehensive, exhaustive) -
  default: comprehensive
- `bucket` (optional): S3 bucket name

**Example:**

```json
{
  "sourceFile": "src/utils/calculator.ts",
  "testFramework": "jest",
  "testType": "unit",
  "coverage": "comprehensive"
}
```

**Response:**

```json
{
  "sourceFile": "src/utils/calculator.ts",
  "testFile": "src/utils/calculator.test.ts",
  "testFramework": "jest",
  "testType": "unit",
  "testsGenerated": 15,
  "coverage": 90,
  "content": "... test code ..."
}
```

### 2. Run Tests (`run-tests`)

Execute test suites and collect results.

**Parameters:**

- `testPath` (optional): Specific test file or directory - default: all tests
- `testFramework` (optional): Testing framework - default: jest
- `environment` (optional): Test environment - default: test
- `parallel` (optional): Run tests in parallel - default: false
- `timeout` (optional): Test timeout in ms - default: 300000

**Example:**

```json
{
  "testPath": "src/utils/calculator.test.ts",
  "testFramework": "jest",
  "parallel": true,
  "timeout": 60000
}
```

**Response:**

```json
{
  "testRunId": "test-run-1234567890",
  "totalTests": 45,
  "passed": 43,
  "failed": 2,
  "skipped": 0,
  "duration": 5432,
  "coverage": {
    "lines": { "percentage": 85 },
    "statements": { "percentage": 85 },
    "functions": { "percentage": 90 },
    "branches": { "percentage": 80 }
  },
  "failures": [
    {
      "testName": "should handle divide by zero",
      "error": "Expected exception not thrown"
    }
  ]
}
```

### 3. Coverage Report (`coverage-report`)

Generate detailed coverage reports with metrics and recommendations.

**Parameters:**

- `testRunId` (optional): Specific test run ID - default: latest
- `format` (optional): Report format (json, html, text) - default: json
- `threshold` (optional): Coverage threshold percentage - default: 80
- `includeFiles` (optional): Comma-separated list of files to include

**Example:**

```json
{
  "testRunId": "test-run-1234567890",
  "format": "json",
  "threshold": 80
}
```

**Response:**

```json
{
  "testRunId": "test-run-1234567890",
  "timestamp": "2025-11-17T10:30:00Z",
  "overallCoverage": {
    "lines": 85,
    "statements": 85,
    "functions": 90,
    "branches": 80,
    "total": 85
  },
  "coverageByType": {
    "unit": 85,
    "integration": 68,
    "e2e": 51
  },
  "meetsThreshold": true,
  "reportUrl": "s3://bucket/coverage-reports/test-run-1234567890.json",
  "recommendations": []
}
```

## Supported Test Frameworks

- **Jest**: Full support with coverage, mocking, and async testing
- **Mocha**: Classic framework with chai assertions
- **Vitest**: Modern, fast unit testing
- **Pytest**: Python testing framework
- **JUnit**: Java testing framework

## Environment Variables

- `AWS_REGION`: AWS region (default: us-east-1)
- `CODE_BUCKET`: S3 bucket for code and test storage
- `TEST_RESULTS_TABLE`: DynamoDB table for test results
- `TEST_METRICS_TABLE`: DynamoDB table for test metrics

## Test Generation Capabilities

### Unit Tests

- Function-level testing
- Input validation tests
- Edge case handling
- Error condition testing
- Mock dependencies

### Integration Tests

- Component interaction testing
- API endpoint testing
- Database integration
- External service mocking

### E2E Tests

- Full workflow testing
- User journey simulation
- Cross-system integration

### Performance Tests

- Load testing
- Stress testing
- Response time validation
- Resource usage monitoring

## Coverage Metrics

The function tracks and reports on:

1. **Line Coverage**: Percentage of code lines executed
2. **Statement Coverage**: Percentage of statements executed
3. **Function Coverage**: Percentage of functions called
4. **Branch Coverage**: Percentage of branches taken

## DynamoDB Schema

### Test Results Table

```
testRunId (PK): string
timestamp: string
framework: string
totalTests: number
passed: number
failed: number
coverage: object
failures: array
```

### Test Metrics Table

```
testRunId (PK): string
timestamp: string
successRate: number
averageTestDuration: number
coverageScore: number
```

## IAM Permissions Required

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::${CODE_BUCKET}/*",
        "arn:aws:s3:::${CODE_BUCKET}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ],
      "Resource": [
        "arn:aws:dynamodb:*:*:table/${TEST_RESULTS_TABLE}",
        "arn:aws:dynamodb:*:*:table/${TEST_METRICS_TABLE}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
```

## Deployment

```bash
npm install
npm run build
npm run package
```

Deploy with Terraform:

```hcl
resource "aws_lambda_function" "test_operations" {
  filename      = "test-operations/function.zip"
  function_name = "bedrock-agent-test-operations"
  role          = aws_iam_role.lambda_role.arn
  handler       = "dist/index.handler"
  runtime       = "nodejs20.x"
  timeout       = 300
  memory_size   = 1024

  environment {
    variables = {
      CODE_BUCKET        = aws_s3_bucket.code_storage.id
      TEST_RESULTS_TABLE = aws_dynamodb_table.test_results.name
      TEST_METRICS_TABLE = aws_dynamodb_table.test_metrics.name
    }
  }
}
```

## Integration with CI/CD

This Lambda function can be triggered from CI/CD pipelines:

```yaml
# GitHub Actions example
- name: Run Tests via Bedrock Agent
  run: |
    aws bedrock-agent invoke \
      --action-group "TestOperations" \
      --action "run-tests" \
      --parameters '{"testPath": "src/**/*.test.ts"}'
```

## Best Practices

1. **Always generate tests before running**: Ensure comprehensive coverage
2. **Set appropriate timeouts**: Long-running tests need higher timeout values
3. **Use parallel execution**: Speed up test runs for large suites
4. **Monitor coverage trends**: Track coverage over time in DynamoDB
5. **Review failures promptly**: Address failing tests before merging code

## License

MIT
