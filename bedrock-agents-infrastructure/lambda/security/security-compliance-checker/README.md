# Security Compliance Checker

Automated security compliance checker for Amazon Bedrock agents infrastructure.

## Features

- **Bedrock Agent Configuration Checks**: Validates agent configurations, encryption settings, and IAM roles
- **IAM Policy Validation**: Detects overly permissive policies and wildcard permissions
- **Secret Scanning**: Identifies exposed secrets and credentials in code and configurations
- **Encryption Validation**: Ensures proper encryption with customer-managed KMS keys
- **Security Hub Integration**: Reports compliance violations to AWS Security Hub

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `AWS_ACCOUNT_ID` | AWS Account ID | Yes |
| `AWS_REGION` | AWS Region | Yes |
| `LOG_LEVEL` | Logging level (INFO, WARN, ERROR) | No |

## Event Structure

```json
{
  "targetRoles": [
    "arn:aws:iam::123456789012:role/BedrockAgentRole"
  ],
  "resourceArns": [
    "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
  ],
  "checkTypes": ["bedrock", "iam", "secrets", "encryption"],
  "severity": "HIGH"
}
```

## Response Structure

```json
{
  "checkId": "compliance-check-1234567890",
  "timestamp": "2025-01-17T10:00:00.000Z",
  "totalFindings": 5,
  "criticalFindings": 1,
  "highFindings": 2,
  "mediumFindings": 2,
  "lowFindings": 0,
  "complianceStatus": "FAILED",
  "findings": [
    {
      "id": "bedrock-agent-xyz-no-cmk",
      "title": "Bedrock Agent not using customer-managed encryption",
      "description": "Agent MyAgent is not configured with a customer-managed KMS key",
      "severity": "HIGH",
      "resourceArn": "arn:aws:bedrock:us-east-1:123456789012:agent/xyz",
      "resourceType": "BedrockAgent",
      "complianceStatus": "FAILED",
      "remediationSteps": [
        "Configure a customer-managed KMS key for the Bedrock agent",
        "Update agent configuration to use the CMK",
        "Ensure proper key policies are in place"
      ]
    }
  ]
}
```

## Compliance Checks

### 1. Bedrock Agent Checks
- Customer-managed encryption key usage
- IAM role permissions
- Agent configuration validation
- Resource tagging

### 2. IAM Policy Checks
- Wildcard principal detection
- Overly permissive actions
- Unused permissions
- Trust policy validation

### 3. Secret Exposure Checks
- Hardcoded credentials
- API keys in code
- AWS access keys
- Private keys
- JWT tokens

### 4. Encryption Checks
- KMS key usage
- Key rotation status
- Key state validation
- Customer vs AWS-managed keys

## Security Hub Integration

Findings are automatically reported to AWS Security Hub with:
- Normalized severity scores
- Resource metadata
- Compliance status
- Remediation recommendations

## IAM Permissions Required

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:GetAgent",
        "bedrock:ListAgents",
        "iam:GetRole",
        "iam:GetPolicy",
        "iam:SimulatePrincipalPolicy",
        "kms:DescribeKey",
        "secretsmanager:ListSecrets",
        "securityhub:BatchImportFindings"
      ],
      "Resource": "*"
    }
  ]
}
```

## Testing

```bash
npm test
npm run test:coverage
```

## Deployment

Deploy using AWS SAM, Terraform, or directly via AWS Console.

## Monitoring

- CloudWatch Logs: `/aws/lambda/security-compliance-checker`
- CloudWatch Metrics: Custom metrics for findings by severity
- Security Hub: Centralized security findings dashboard
