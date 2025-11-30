# Security Incident Response

Automated incident response system for security threats detected in Bedrock
agents infrastructure.

## Features

- **GuardDuty Integration**: Automatically responds to GuardDuty findings
- **Resource Isolation**: Isolates compromised EC2 instances, Bedrock agents,
  and Lambda functions
- **Forensic Snapshots**: Creates EBS snapshots for forensic analysis
- **Security Team Notifications**: Sends SNS notifications to security team
- **Incident Ticketing**: Creates tickets in incident management system
- **Automated Remediation**: Takes immediate action on critical findings

## Environment Variables

| Variable                     | Description                          | Required | Default |
| ---------------------------- | ------------------------------------ | -------- | ------- |
| `SECURITY_TOPIC_ARN`         | SNS topic for security notifications | Yes      | -       |
| `INCIDENT_QUEUE_URL`         | SQS queue for incident tickets       | Yes      | -       |
| `AUTO_ISOLATE`               | Auto-isolate compromised resources   | No       | false   |
| `DRY_RUN`                    | Test mode without actual changes     | No       | false   |
| `STOP_COMPROMISED_INSTANCES` | Stop compromised EC2 instances       | No       | false   |

## Event Structure

### GuardDuty Event

```json
{
  "detectorId": "abc123",
  "findingIds": ["finding-1", "finding-2"],
  "source": "guardduty"
}
```

### EventBridge Event

```json
{
  "source": "aws.guardduty",
  "detail": {
    "severity": 8.5,
    "type": "Recon:EC2/PortProbeUnprotectedPort",
    "resource": {
      "instanceDetails": {
        "instanceId": "i-1234567890abcdef"
      }
    }
  }
}
```

## Response Structure

```json
{
  "incidentId": "incident-1234567890",
  "timestamp": "2025-01-17T10:00:00.000Z",
  "status": "SUCCESS",
  "actionsToken": 4,
  "findings": [
    {
      "id": "finding-1",
      "type": "Recon:EC2/PortProbeUnprotectedPort",
      "severity": "HIGH",
      "resourceArn": "i-1234567890abcdef"
    }
  ],
  "responseTime": 2500,
  "dryRun": false
}
```

## Incident Response Actions

### 1. Resource Isolation

**EC2 Instances**:

- Modify security groups to deny all traffic
- Tag instance as ISOLATED
- Optionally stop the instance

**Bedrock Agents**:

- Update IAM role to deny all actions
- Log isolation for manual review

**Lambda Functions**:

- Set reserved concurrency to 0
- Update IAM role to deny all actions

### 2. Forensic Snapshots

- Creates EBS snapshots of compromised instances
- Tags snapshots with incident metadata
- Preserves evidence for investigation

### 3. Notifications

- **Critical/High**: Immediate SNS notification
- **Medium/Low**: Ticket creation only
- Includes finding details and actions taken

### 4. Incident Tickets

- Creates SQS messages for ticket system
- Includes severity, finding details, and actions
- Tracked with unique incident ID

## Severity Assessment

| GuardDuty Score | Severity | Actions                                               |
| --------------- | -------- | ----------------------------------------------------- |
| 9.0 - 10.0      | CRITICAL | Immediate isolation + notification + snapshot         |
| 7.0 - 8.9       | HIGH     | Isolation (if AUTO_ISOLATE) + notification + snapshot |
| 4.0 - 6.9       | MEDIUM   | Ticket creation + notification                        |
| 0.0 - 3.9       | LOW      | Ticket creation only                                  |

## IAM Permissions Required

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "guardduty:GetFindings",
        "guardduty:ArchiveFindings",
        "ec2:DescribeInstances",
        "ec2:CreateSnapshot",
        "ec2:StopInstances",
        "ec2:ModifyInstanceAttribute",
        "ec2:CreateTags",
        "bedrock:GetAgent",
        "bedrock:UpdateAgent",
        "lambda:GetFunctionConfiguration",
        "lambda:UpdateFunctionConfiguration",
        "sns:Publish",
        "sqs:SendMessage"
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

## Dry Run Mode

Set `DRY_RUN=true` to test without making actual changes:

```bash
DRY_RUN=true AUTO_ISOLATE=true node index.js
```

## Rollback Procedures

Each isolation action includes rollback instructions:

- **EC2**: Restore original security groups and restart
- **Bedrock**: Restore original IAM role
- **Lambda**: Restore IAM role and VPC configuration

## Monitoring

- CloudWatch Logs: `/aws/lambda/security-incident-response`
- CloudWatch Metrics:
  - IncidentsProcessed
  - IsolationsPerformed
  - SnapshotsCreated
  - ResponseTime
- SNS Notifications for all critical incidents

## Best Practices

1. Test in DRY_RUN mode first
2. Use AUTO_ISOLATE with caution
3. Monitor false positives
4. Regular testing with simulated incidents
5. Document rollback procedures
6. Maintain incident playbooks
