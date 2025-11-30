# Security Access Analyzer

Automated IAM access analysis for detecting overly permissive policies and
generating least-privilege recommendations.

## Features

- **IAM Access Analyzer Integration**: Analyzes external access findings
- **Overprivileged Policy Detection**: Identifies policies with excessive
  permissions
- **Unused Permission Detection**: Finds permissions never used in 90+ days
- **Least-Privilege Recommendations**: Generates optimized policy suggestions
- **Automated Policy Updates**: Queue policy updates (dry-run mode supported)
- **Trust Policy Analysis**: Validates cross-account and external access

## Environment Variables

| Variable                 | Description                      | Required | Default |
| ------------------------ | -------------------------------- | -------- | ------- |
| `ANALYZER_ARN`           | IAM Access Analyzer ARN          | Yes      | -       |
| `NOTIFICATION_TOPIC_ARN` | SNS topic for notifications      | Yes      | -       |
| `POLICY_QUEUE_URL`       | SQS queue for policy updates     | No       | -       |
| `DRY_RUN`                | Test mode without actual changes | No       | false   |
| `AUTO_UPDATE_POLICIES`   | Auto-queue policy updates        | No       | false   |
| `AWS_ACCOUNT_ID`         | AWS Account ID                   | Yes      | -       |

## Event Structure

### Analyze Specific Roles

```json
{
  "roleArns": [
    "arn:aws:iam::123456789012:role/BedrockAgentRole",
    "arn:aws:iam::123456789012:role/LambdaExecutionRole"
  ],
  "analyzeFindings": true,
  "checkOverpermissive": true,
  "generateRecommendations": true
}
```

### Analyze All Access Analyzer Findings

```json
{
  "analyzeFindings": true
}
```

### Generate Recommendations Only

```json
{
  "roleArns": ["arn:aws:iam::123456789012:role/MyRole"],
  "analyzeFindings": false,
  "generateRecommendations": true
}
```

## Response Structure

```json
{
  "analysisId": "analysis-1234567890",
  "timestamp": "2025-01-17T10:00:00.000Z",
  "totalFindings": 8,
  "criticalFindings": 1,
  "highFindings": 3,
  "mediumFindings": 3,
  "lowFindings": 1,
  "duration": 5500,
  "dryRun": false,
  "policiesQueued": 2,
  "findings": [
    {
      "id": "MyRole-wildcard-trust",
      "type": "WILDCARD_PRINCIPAL",
      "title": "Trust policy allows wildcard principal",
      "description": "Role MyRole can be assumed by any AWS principal",
      "severity": "CRITICAL",
      "resourceArn": "arn:aws:iam::123456789012:role/MyRole",
      "resourceType": "IAMRole",
      "principal": "*",
      "action": "AssumeRole",
      "isPublic": true,
      "analyzedAt": "2025-01-17T10:00:00.000Z"
    }
  ],
  "recommendations": [
    {
      "id": "policy-rec-1234567890",
      "resourceArn": "arn:aws:iam::123456789012:role/MyRole",
      "resourceType": "IAMRole",
      "currentPolicy": {
        "Version": "2012-10-17",
        "Statement": [
          {
            "Effect": "Allow",
            "Action": ["s3:*"],
            "Resource": "*"
          }
        ]
      },
      "recommendedPolicy": {
        "Version": "2012-10-17",
        "Statement": [
          {
            "Effect": "Allow",
            "Action": ["s3:GetObject", "s3:PutObject"],
            "Resource": "arn:aws:s3:::my-bucket/*"
          }
        ]
      },
      "changesummary": [
        "Reduced wildcard actions from 1 to 0",
        "Reduced wildcard resources from 1 to 0"
      ],
      "permissionsRemoved": ["s3:*"],
      "permissionsAdded": ["s3:GetObject", "s3:PutObject"],
      "riskReduction": 45,
      "confidenceScore": 85
    }
  ],
  "unusedPermissions": [
    {
      "roleArn": "arn:aws:iam::123456789012:role/MyRole",
      "roleName": "MyRole",
      "permission": "ec2:*",
      "service": "EC2",
      "lastUsed": "2024-10-01T00:00:00.000Z",
      "neverUsed": false,
      "daysSinceLastUse": 108
    }
  ]
}
```

## Finding Types

### 1. ACCESS_ANALYZER

External access detected by IAM Access Analyzer:

- Public S3 buckets
- Cross-account IAM roles
- Shared KMS keys
- Lambda functions with resource policies

### 2. OVERPRIVILEGED

Policies with excessive permissions:

- Wildcard actions (`*:*`, `s3:*`)
- Wildcard resources (`*`)
- Admin-level permissions

### 3. UNUSED_PERMISSIONS

Permissions not used in 90+ days:

- Based on service last accessed data
- Requires CloudTrail for accuracy

### 4. WILDCARD_PRINCIPAL

Trust policies allowing any principal:

- `"Principal": "*"`
- `"Principal": {"AWS": "*"}`

### 5. MISSING_EXTERNAL_ID

Cross-account access without ExternalId:

- External account in trust policy
- Missing ExternalId condition
- Confused deputy vulnerability

## Trust Policy Validation

Checks for:

- **Wildcard Principals**: Trust policies allowing `*`
- **External Access**: Cross-account access patterns
- **Missing ExternalId**: Cross-account without ExternalId
- **Public Assume**: Publicly assumable roles

## Policy Risk Scoring

Risk score (0-100) based on:

- **Wildcard actions**: +20 per wildcard
- **Wildcard resources**: +15 per wildcard
- **Critical findings**: +30 per finding
- **High findings**: +20 per finding
- **Medium findings**: +10 per finding

## Least-Privilege Recommendations

Generated based on:

- CloudTrail activity (requires 90 days of data)
- Service last accessed information
- IAM Access Analyzer policy generation
- Wildcard reduction opportunities

### Confidence Score

Recommendations include confidence score (0-100):

- **90-100**: High confidence, extensive usage data
- **70-89**: Good confidence, sufficient usage data
- **50-69**: Medium confidence, limited usage data
- **<50**: Low confidence, insufficient data

## Unused Permission Detection

Identifies permissions:

- Never used
- Not used in 90+ days
- Services with zero access

Based on:

- `GetServiceLastAccessedDetails` API
- CloudTrail logs (if available)
- Access Advisor data

## IAM Permissions Required

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "access-analyzer:ListFindings",
        "access-analyzer:GetFinding",
        "access-analyzer:StartPolicyGeneration",
        "access-analyzer:GetGeneratedPolicy",
        "iam:GetRole",
        "iam:GetPolicy",
        "iam:GetPolicyVersion",
        "iam:ListAttachedRolePolicies",
        "iam:SimulatePrincipalPolicy",
        "iam:GenerateServiceLastAccessedDetails",
        "iam:GetServiceLastAccessedDetails",
        "sns:Publish",
        "sqs:SendMessage"
      ],
      "Resource": "*"
    }
  ]
}
```

## Automated Policy Updates

When `AUTO_UPDATE_POLICIES=true`:

1. Recommendations are queued in SQS
2. Separate Lambda processes updates
3. Dry-run mode tests changes first
4. Monitors for errors post-update
5. Automatic rollback on failure

## Testing

```bash
npm test
npm run test:coverage
```

## Dry Run Mode

Test analysis without making changes:

```bash
DRY_RUN=true node index.js
```

## Scheduled Analysis

Run weekly analysis with EventBridge:

```bash
aws events put-rule \
  --name weekly-access-analysis \
  --schedule-expression "cron(0 1 ? * MON *)"

aws events put-targets \
  --rule weekly-access-analysis \
  --targets "Id"="1","Arn"="arn:aws:lambda:us-east-1:123456789012:function:security-access-analyzer"
```

## Monitoring

- CloudWatch Logs: `/aws/lambda/security-access-analyzer`
- CloudWatch Metrics:
  - AnalysesCompleted
  - FindingsBySeverity
  - RecommendationsGenerated
  - PoliciesUpdated
- SNS Notifications for critical findings

## Best Practices

1. Run analysis weekly
2. Review recommendations before applying
3. Use dry-run mode first
4. Monitor CloudTrail for 90 days before generating recommendations
5. Test policy changes in non-production first
6. Keep Access Analyzer enabled
7. Set up automated notifications
8. Track unused permissions quarterly
9. Document policy change justifications
10. Maintain audit trail

## Common Findings

### Critical

- Wildcard principals in trust policies
- Public access to sensitive resources
- Admin permissions without MFA

### High

- Cross-account access without ExternalId
- Overly broad resource wildcards
- Unused admin permissions

### Medium

- Permissions unused for 90+ days
- Service-level wildcards
- Missing resource constraints

### Low

- Informational findings
- Optimization opportunities
- Best practice recommendations
