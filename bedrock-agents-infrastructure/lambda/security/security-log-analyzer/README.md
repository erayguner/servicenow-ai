# Security Log Analyzer

Automated CloudTrail log analyzer for detecting suspicious activity, privilege escalation, and anomalous behavior.

## Features

- **CloudTrail Analysis**: Analyzes CloudTrail logs for security events
- **Suspicious API Detection**: Identifies dangerous or unusual API calls
- **Privilege Escalation Detection**: Detects IAM permission changes and escalation attempts
- **Unauthorized Access Monitoring**: Tracks failed access attempts and brute force patterns
- **Anomaly Detection**: Identifies unusual behavior based on baseline patterns
- **Real-time Alerts**: SNS notifications for critical security events
- **Security Hub Integration**: Reports findings to AWS Security Hub

## Environment Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `NOTIFICATION_TOPIC_ARN` | SNS topic for security alerts | Yes | - |
| `SECURITY_HUB_ENABLED` | Enable Security Hub reporting | No | true |
| `LOOKBACK_HOURS` | Hours of logs to analyze | No | 24 |
| `ALERT_THRESHOLD` | Minimum severity for alerts | No | MEDIUM |
| `AWS_ACCOUNT_ID` | AWS Account ID | Yes | - |
| `AWS_REGION` | AWS Region | Yes | - |

## Event Structure

### Basic Analysis
```json
{
  "analyzeCloudTrail": true,
  "detectSuspiciousAPI": true,
  "detectPrivilegeEscalation": true,
  "detectUnauthorizedAccess": true,
  "lookbackHours": 24
}
```

### Custom Suspicious Actions
```json
{
  "detectSuspiciousAPI": true,
  "suspiciousActions": [
    "DeleteTrail",
    "StopLogging",
    "CreateAccessKey",
    "PutUserPolicy",
    "AssumeRole"
  ]
}
```

### With Baseline Data for Anomaly Detection
```json
{
  "detectAnomalies": true,
  "baselineData": {
    "normalSourceIPs": ["203.0.113.1", "203.0.113.2"],
    "normalUserAgents": ["AWS-CLI/2.0", "Boto3/1.26"],
    "typicalActivityHours": [9, 10, 11, 12, 13, 14, 15, 16, 17],
    "averageAPICallsPerHour": 150
  }
}
```

## Response Structure

```json
{
  "analysisId": "log-analysis-1234567890",
  "timestamp": "2025-01-17T10:00:00.000Z",
  "timeRange": {
    "start": "2025-01-16T10:00:00.000Z",
    "end": "2025-01-17T10:00:00.000Z",
    "hours": 24
  },
  "totalEvents": 1250,
  "totalAnomalies": 12,
  "criticalAnomalies": 2,
  "highAnomalies": 4,
  "mediumAnomalies": 4,
  "lowAnomalies": 2,
  "duration": 8500,
  "alertsSent": 6,
  "anomalies": [
    {
      "id": "priv-esc-evt-12345",
      "type": "PRIVILEGE_ESCALATION",
      "description": "Potential privilege escalation detected: AttachUserPolicy",
      "severity": "CRITICAL",
      "timestamp": "2025-01-17T09:45:00.000Z",
      "eventName": "AttachUserPolicy",
      "userIdentity": "compromised-user",
      "sourceIP": "198.51.100.42",
      "indicators": [
        "Grants administrator access",
        "IAM policy attachment"
      ],
      "affectedResources": [
        "arn:aws:iam::123456789012:user/target-user"
      ],
      "riskScore": 95,
      "evidence": [
        {
          "type": "REQUEST_PARAMETERS",
          "description": "Policy grants broad permissions",
          "value": {
            "policyArn": "arn:aws:iam::aws:policy/AdministratorAccess"
          },
          "timestamp": "2025-01-17T09:45:00.000Z"
        }
      ]
    }
  ],
  "suspiciousPatterns": [
    {
      "id": "suspicious-api-DeleteTrail-1234567890",
      "pattern": "DeleteTrail",
      "description": "Detected 3 occurrences of suspicious API call: DeleteTrail",
      "occurrences": 3,
      "firstSeen": "2025-01-17T08:30:00.000Z",
      "lastSeen": "2025-01-17T09:15:00.000Z",
      "severity": "CRITICAL",
      "examples": [...]
    }
  ]
}
```

## Detection Capabilities

### 1. Suspicious API Calls

Monitors for security-relevant API calls:
- **Logging/Monitoring Evasion**: DeleteTrail, StopLogging, DeleteFlowLogs
- **Security Service Tampering**: DeleteDetector, DisassociateFromMasterAccount
- **Credential Access**: GetSecretValue, GetPasswordData, GetFederationToken
- **IAM Changes**: CreateAccessKey, AttachUserPolicy, PutRolePolicy
- **Privilege Escalation**: AssumeRole, CreateUser, UpdateAssumeRolePolicy

### 2. Privilege Escalation

Detects escalation attempts:
- IAM policy modifications granting admin access
- Policy attachments with wildcard permissions
- Role assumption changes
- New user/role creation with elevated privileges
- Permission boundary modifications

### 3. Unauthorized Access

Identifies access violations:
- Repeated AccessDenied errors (potential brute force)
- Failed authentication attempts
- Unauthorized API calls
- Access from unusual locations
- Off-hours access attempts

### 4. Anomalous Behavior

Detects deviations from baseline:
- Activity from new source IPs
- Unusual user agents
- Off-hours activity
- Spike in API call volume
- Geographic anomalies

## Anomaly Types

| Type | Description | Typical Severity |
|------|-------------|------------------|
| PRIVILEGE_ESCALATION | IAM permission changes | CRITICAL/HIGH |
| UNAUTHORIZED_ACCESS | Failed access attempts | HIGH/MEDIUM |
| SUSPICIOUS_API_CALL | Dangerous API calls | CRITICAL/HIGH |
| UNUSUAL_LOCATION | New source IP/region | MEDIUM |
| ANOMALOUS_BEHAVIOR | Deviation from baseline | MEDIUM/LOW |
| DATA_EXFILTRATION | Large data transfers | CRITICAL |
| CREDENTIAL_ACCESS | Secret/password access | HIGH |
| LATERAL_MOVEMENT | Cross-account activity | HIGH |

## Risk Score Calculation

Risk score (0-100) based on:
- **Number of indicators**: +15 per indicator
- **Evidence count**: +10 per evidence
- **High-risk keywords**: +20 per keyword (admin, full access, *:*)
- **Occurrence frequency**: +5 per occurrence

## Severity Thresholds

| Severity | Risk Score | Failed Attempts | Action |
|----------|------------|-----------------|--------|
| CRITICAL | 80-100 | 20+ | Immediate investigation |
| HIGH | 60-79 | 10-19 | Investigate within 4 hours |
| MEDIUM | 40-59 | 5-9 | Review within 24 hours |
| LOW | 0-39 | <5 | Review as time permits |

## Baseline Data

For accurate anomaly detection, provide baseline data:

```typescript
{
  normalSourceIPs: ['known-ip-1', 'known-ip-2'],
  normalUserAgents: ['expected-agent-1'],
  typicalActivityHours: [9, 10, 11, 12, 13, 14, 15, 16, 17],
  normalAPICallPatterns: {
    'DescribeInstances': 100,
    'ListBuckets': 50
  },
  averageAPICallsPerHour: 200
}
```

## IAM Permissions Required

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cloudtrail:LookupEvents",
        "cloudtrail:GetEventSelectors",
        "logs:FilterLogEvents",
        "logs:DescribeLogGroups",
        "guardduty:ListFindings",
        "guardduty:GetFindings",
        "securityhub:BatchImportFindings",
        "sns:Publish"
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

## Scheduled Analysis

Run hourly analysis with EventBridge:

```bash
aws events put-rule \
  --name hourly-log-analysis \
  --schedule-expression "cron(0 * * * ? *)"

aws events put-targets \
  --rule hourly-log-analysis \
  --targets "Id"="1","Arn"="arn:aws:lambda:us-east-1:123456789012:function:security-log-analyzer"
```

## Common Suspicious Patterns

### Critical Severity
- Deletion of CloudTrail trails
- Stopping of logging services
- Attachment of AdministratorAccess policy
- Disabling of GuardDuty
- Deletion of VPC Flow Logs

### High Severity
- Multiple failed login attempts (10+)
- IAM policy changes
- Access key creation
- Role assumption from unusual IP
- Off-hours administrative activity

### Medium Severity
- Unusual source IP addresses
- Failed API calls (5-9)
- Off-hours standard activity
- New user agent strings

## Alert Configuration

### Critical Alerts
Sent immediately for:
- Privilege escalation attempts
- Security service tampering
- Data exfiltration patterns
- 20+ failed access attempts

### High Alerts
Sent within minutes for:
- Suspicious API patterns
- 10+ failed access attempts
- Unusual administrative actions

## Monitoring

- CloudWatch Logs: `/aws/lambda/security-log-analyzer`
- CloudWatch Metrics:
  - EventsAnalyzed
  - AnomaliesDetected (by type and severity)
  - AlertsSent
  - AnalysisDuration
- Security Hub for centralized findings

## Best Practices

1. **Enable CloudTrail**: Ensure CloudTrail is logging all regions
2. **Set Baselines**: Establish baseline behavior patterns
3. **Regular Analysis**: Run hourly or more frequently
4. **Review Alerts**: Investigate all critical/high alerts promptly
5. **Tune Thresholds**: Adjust based on environment
6. **Archive Logs**: Retain CloudTrail logs for 90+ days
7. **Monitor Coverage**: Ensure all accounts are monitored
8. **Update Patterns**: Regularly update suspicious action lists
9. **Integration**: Connect with SIEM/incident response systems
10. **Training**: Use findings to train security team

## Example Use Cases

### Detect Compromised Credentials
- Monitor for unusual source IPs
- Track off-hours access
- Identify privilege escalation attempts
- Alert on suspicious API patterns

### Prevent Data Exfiltration
- Monitor S3 GetObject calls
- Track large data transfers
- Identify unusual download patterns
- Alert on public bucket access

### Insider Threat Detection
- Baseline normal user behavior
- Detect permission changes
- Monitor access to sensitive resources
- Track after-hours activity

### Compliance Monitoring
- Log all administrative actions
- Track policy changes
- Monitor access to protected data
- Generate audit reports
