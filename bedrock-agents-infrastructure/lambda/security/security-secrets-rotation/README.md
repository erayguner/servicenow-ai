# Security Secrets Rotation

Automated secrets rotation system for Bedrock agents infrastructure credentials
and API keys.

## Features

- **Bedrock API Key Rotation**: Rotate Bedrock service API keys
- **Database Credential Rotation**: Rotate RDS/database passwords
- **Lambda Environment Variables**: Rotate Lambda function environment secrets
- **Generic Secret Rotation**: Support for any secret type
- **Automatic Verification**: Validates rotation success
- **Rollback Support**: Can revert failed rotations
- **Notification System**: SNS notifications for rotation status

## Supported Rotation Types

### 1. BEDROCK_API_KEY

Rotates API keys for Amazon Bedrock services.

### 2. DATABASE_CREDENTIALS

Rotates database passwords for:

- Amazon RDS (MySQL, PostgreSQL, Oracle, SQL Server)
- Amazon Aurora
- Self-managed databases

### 3. LAMBDA_ENVIRONMENT

Rotates secrets stored in Lambda environment variables.

### 4. GENERIC_SECRET

Rotates any generic secret value.

## Environment Variables

| Variable                 | Description                      | Required | Default |
| ------------------------ | -------------------------------- | -------- | ------- |
| `NOTIFICATION_TOPIC_ARN` | SNS topic for notifications      | Yes      | -       |
| `DRY_RUN`                | Test mode without actual changes | No       | false   |

## Event Structure

### Basic Rotation Event

```json
{
  "SecretId": "arn:aws:secretsmanager:us-east-1:123456789012:secret:my-secret",
  "ClientRequestToken": "unique-token-123",
  "rotationType": "BEDROCK_API_KEY"
}
```

### Lambda Environment Rotation

```json
{
  "secretArn": "arn:aws:secretsmanager:us-east-1:123456789012:secret:lambda-secrets",
  "rotationType": "LAMBDA_ENVIRONMENT",
  "lambdaFunctions": ["bedrock-agent-function-1", "bedrock-agent-function-2"]
}
```

### Database Rotation

```json
{
  "SecretId": "arn:aws:secretsmanager:us-east-1:123456789012:secret:db-creds",
  "rotationType": "DATABASE_CREDENTIALS",
  "ClientRequestToken": "rotation-token-456"
}
```

## Response Structure

```json
{
  "rotationId": "rotation-1234567890",
  "secretArn": "arn:aws:secretsmanager:us-east-1:123456789012:secret:my-secret",
  "status": "SUCCESS",
  "rotationType": "BEDROCK_API_KEY",
  "steps": [
    {
      "step": "CREATE_SECRET",
      "status": "SUCCESS",
      "timestamp": "2025-01-17T10:00:00.000Z",
      "message": "New API key generated and stored"
    },
    {
      "step": "SET_SECRET",
      "status": "SUCCESS",
      "timestamp": "2025-01-17T10:00:01.000Z",
      "message": "Secret updated in Secrets Manager"
    },
    {
      "step": "TEST_SECRET",
      "status": "SUCCESS",
      "timestamp": "2025-01-17T10:00:02.000Z",
      "message": "New secret tested successfully"
    },
    {
      "step": "FINISH_SECRET",
      "status": "SUCCESS",
      "timestamp": "2025-01-17T10:00:03.000Z",
      "message": "Rotation finalized"
    },
    {
      "step": "VERIFICATION",
      "status": "SUCCESS",
      "timestamp": "2025-01-17T10:00:04.000Z",
      "message": "Rotation verified successfully"
    }
  ],
  "duration": 4500,
  "verificationResult": {
    "success": true,
    "message": "All verification checks passed",
    "checks": [
      {
        "checkName": "Secret Accessibility",
        "passed": true,
        "details": "Secret is accessible and contains value"
      },
      {
        "checkName": "Secret Format",
        "passed": true,
        "details": "Secret is valid JSON"
      },
      {
        "checkName": "Rotation Metadata",
        "passed": true,
        "details": "Secret contains rotation metadata"
      },
      {
        "checkName": "Bedrock API Key Validation",
        "passed": true,
        "details": "API key meets minimum length requirement"
      }
    ],
    "timestamp": "2025-01-17T10:00:04.000Z"
  },
  "dryRun": false
}
```

## Rotation Steps

All rotations follow the standard 4-step process:

### 1. CREATE_SECRET

- Generates new credential/key
- Stores as AWSPENDING version
- Does not affect current secret

### 2. SET_SECRET

- Updates target resource with new credential
- Database: Updates password
- Lambda: Updates environment variables
- Bedrock: Updates API key configuration

### 3. TEST_SECRET

- Tests new credential against target resource
- Verifies connectivity and permissions
- Rolls back on failure

### 4. FINISH_SECRET

- Promotes AWSPENDING to AWSCURRENT
- Archives old version
- Completes rotation

### 5. VERIFICATION

- Validates rotation success
- Checks secret accessibility
- Verifies format and metadata
- Type-specific validation

## Secret Complexity Requirements

### Passwords

- Minimum 12 characters
- At least one uppercase letter
- At least one lowercase letter
- At least one digit
- At least one special character (!@#$%^&\*)

### API Keys

- Minimum 32 characters
- Alphanumeric only

## IAM Permissions Required

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetSecretValue",
        "secretsmanager:PutSecretValue",
        "secretsmanager:UpdateSecretVersionStage",
        "lambda:GetFunctionConfiguration",
        "lambda:UpdateFunctionConfiguration",
        "rds:ModifyDBInstance",
        "rds:DescribeDBInstances",
        "sns:Publish"
      ],
      "Resource": "*"
    }
  ]
}
```

## Automatic Rotation Schedule

Configure in Secrets Manager:

```bash
aws secretsmanager rotate-secret \
  --secret-id my-secret \
  --rotation-lambda-arn arn:aws:lambda:us-east-1:123456789012:function:security-secrets-rotation \
  --rotation-rules AutomaticallyAfterDays=30
```

## Testing

```bash
npm test
npm run test:coverage
```

## Dry Run Mode

Test rotations without making changes:

```bash
DRY_RUN=true node index.js
```

## Rollback

If rotation fails during SET_SECRET or TEST_SECRET, the function automatically:

- Does not promote AWSPENDING version
- Keeps AWSCURRENT version active
- Logs failure details
- Sends failure notification

Manual rollback if needed:

```bash
aws secretsmanager update-secret-version-stage \
  --secret-id my-secret \
  --version-stage AWSCURRENT \
  --remove-from-version-id [new-version] \
  --move-to-version-id [old-version]
```

## Monitoring

- CloudWatch Logs: `/aws/lambda/security-secrets-rotation`
- CloudWatch Metrics:
  - RotationsSucceeded
  - RotationsFailed
  - RotationDuration
  - VerificationFailures
- SNS Notifications for all rotations

## Best Practices

1. Always test with DRY_RUN first
2. Set up automatic rotation schedules
3. Monitor SNS notifications
4. Keep rotation logs for audit
5. Test rollback procedures
6. Use strong complexity requirements
7. Rotate secrets regularly (30-90 days)
8. Verify applications use updated secrets
