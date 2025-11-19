# Threat Detection Guide

## Table of Contents

1. [Threat Detection Architecture](#threat-detection-architecture)
2. [GuardDuty Configuration](#guardduty-configuration)
3. [Security Hub Insights](#security-hub-insights)
4. [Anomaly Detection](#anomaly-detection)
5. [Threat Intelligence](#threat-intelligence)
6. [Indicators of Compromise](#indicators-of-compromise)
7. [Response Automation](#response-automation)
8. [Finding Analysis](#finding-analysis)
9. [Threat Hunting](#threat-hunting)
10. [Detection Tuning](#detection-tuning)

## Threat Detection Architecture

### Multi-Layer Detection Stack

```
┌──────────────────────────────────────────────────────────────┐
│                     Data Collection                           │
├──────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌──────────────────┐  ┌──────────────────┐  ┌────────────┐  │
│  │   CloudTrail     │  │   VPC Flow Logs  │  │ AWS Config │  │
│  │  (API calls)     │  │ (Network traffic)│  │(Config)    │  │
│  └──────────────────┘  └──────────────────┘  └────────────┘  │
│                                                                │
└──────────────────────────────────────────────────────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
        ▼                 ▼                 ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  GuardDuty   │  │ Security Hub │  │  CloudWatch  │
│ - Threats    │  │ - Compliance │  │ - Anomalies  │
│ - Abuse      │  │ - Standards  │  │ - Patterns   │
│ - Crypto     │  │ - Findings   │  │ - Trends     │
└──────────────┘  └──────────────┘  └──────────────┘
        │                 │                 │
        └─────────────────┼─────────────────┘
                          │
                          ▼
        ┌─────────────────────────────┐
        │   Analysis & Correlation    │
        │ - Severity assessment       │
        │ - Context enrichment        │
        │ - Deduplication             │
        │ - Prioritization            │
        └─────────────────────────────┘
                          │
                          ▼
        ┌─────────────────────────────┐
        │   Alerting & Response       │
        │ - SNS notifications         │
        │ - PagerDuty escalation      │
        │ - Lambda automation         │
        │ - Runbook execution         │
        └─────────────────────────────┘
```

## GuardDuty Configuration

### GuardDuty Overview

GuardDuty is an intelligent threat detection service that analyzes:
- CloudTrail logs (API activity)
- VPC Flow Logs (network traffic)
- DNS logs (query patterns)
- S3 protection (object-level activity)
- EKS protection (Kubernetes activity)

### Enabling GuardDuty

#### Create Detector
```bash
aws guardduty create-detector \
  --enable \
  --finding-publishing-frequency FIFTEEN_MINUTES
```

#### Enable S3 Protection
```bash
aws guardduty create-s3-protection-enabled-auditing \
  --detector-id DETECTOR_ID \
  --enable
```

#### Enable EKS Protection (if applicable)
```bash
aws guardduty create-eks-protection-enabled-auditing \
  --detector-id DETECTOR_ID \
  --enable
```

### Finding Types and Severity

#### EC2 Findings
```
High Severity:
- EC2_UnauthorizedAccess - Unusual port activity
- EC2_Cryptocurrency_Bitcoin - Cryptomining activity
- EC2_SuspiciousNetworkConnectivity - C&C communication
- EC2_MaliciousIPCaller - Compromised instance

Medium Severity:
- EC2_InstanceContactingS3 - Instance accessing S3
- EC2_UnexpectedNetworkExposure - Public exposure
- EC2_NetworkPermissionModification - Security group changes

Low Severity:
- EC2_PrivilegeEscalation - IAM policy grants
```

#### IAM Findings
```
High Severity:
- IAM_AnomalousUserActivity - Unusual API calls
- IAM_PrivilegeEscalation - Permission escalation
- IAM_UnauthorizedAccess - Failed access attempts

Medium Severity:
- IAM_UnusualPrincipalActivity - New type of API call
- IAM_InstanceRoleExfiltrationUnauthorizedAccess - Role abuse

Low Severity:
- IAM_NewPublicAccessKey - New public S3 key
```

#### S3 Findings
```
High Severity:
- S3_DataExfiltration - Large download
- S3_UnauthorizedAccess - Non-owner access
- S3_BucketEnumeration - Bucket listing

Medium Severity:
- S3_PutObjectAcl - Public ACL modification
- S3_GetObject - Unusual object access
```

### GuardDuty Findings Processing

#### Query Findings
```bash
# List findings
aws guardduty list-findings \
  --detector-id DETECTOR_ID

# Get finding details
aws guardduty get-findings \
  --detector-id DETECTOR_ID \
  --finding-ids FINDING_ID_1 FINDING_ID_2

# Create finding filter
aws guardduty create-filter \
  --detector-id DETECTOR_ID \
  --name "High-Severity-Findings" \
  --finding-criteria '{
    "Criterion": {
      "severity": {
        "Gte": 7
      },
      "type": {
        "Neq": ["Software and Configuration Checks"]
      }
    }
  }'
```

#### Export Findings
```bash
# Create SNS topic for findings
aws sns create-topic --name guardduty-findings

# Create publishing destination
aws guardduty create-publishing-destination \
  --detector-id DETECTOR_ID \
  --destination-type S3 \
  --destination-properties 'DestinationArn=arn:aws:s3:::bedrock-guardduty-findings'

# Enable findings export
aws guardduty update-detector \
  --detector-id DETECTOR_ID \
  --findings-export-options 'S3Bucket=bedrock-guardduty-findings,Enabled=true'
```

## Security Hub Insights

### Security Hub Overview

Security Hub aggregates findings from:
- GuardDuty (threat detection)
- AWS Config (configuration compliance)
- Inspector (vulnerability assessment)
- IAM Access Analyzer (resource permissions)
- 90+ AWS services

### Enabled Standards

#### Enable AWS Foundational Security Best Practices
```bash
aws securityhub batch-enable-standards \
  --standards-subscription-requests '[
    {
      "StandardsArn": "arn:aws:securityhub:REGION::standards/aws-foundational-security-best-practices/v/1.0.0"
    }
  ]'
```

#### Enable CIS AWS Foundations Benchmark
```bash
aws securityhub batch-enable-standards \
  --standards-subscription-requests '[
    {
      "StandardsArn": "arn:aws:securityhub:REGION::standards/cis-aws-foundations-benchmark/v/1.2.0"
    }
  ]'
```

#### Enable PCI DSS (if applicable)
```bash
aws securityhub batch-enable-standards \
  --standards-subscription-requests '[
    {
      "StandardsArn": "arn:aws:securityhub:REGION::standards/pci-dss/v/3.2.1"
    }
  ]'
```

### Custom Insights

#### High-Risk IAM Changes
```bash
aws securityhub create-insight \
  --name "High-Risk-IAM-Changes" \
  --filters '{
    "ResourceType": [{"Value": "AwsIam", "Comparison": "EQUALS"}],
    "Type": [
      {"Value": "*Privilege*", "Comparison": "PREFIX"}
    ],
    "SeverityLabel": [
      {"Value": "CRITICAL", "Comparison": "EQUALS"},
      {"Value": "HIGH", "Comparison": "EQUALS"}
    ]
  }' \
  --group-by-attribute RESOURCE_ID
```

#### Unresolved Security Issues
```bash
aws securityhub create-insight \
  --name "Unresolved-Critical-Issues" \
  --filters '{
    "SeverityLabel": [
      {"Value": "CRITICAL", "Comparison": "EQUALS"}
    ],
    "RecordState": [
      {"Value": "ACTIVE", "Comparison": "EQUALS"}
    ],
    "ComplianceStatus": [
      {"Value": "FAILED", "Comparison": "EQUALS"}
    ]
  }' \
  --group-by-attribute RESOURCE_ID
```

## Anomaly Detection

### CloudWatch Anomaly Detector

#### Configure Anomaly Detection
```bash
# Enable anomaly detection on metric
aws cloudwatch put-metric-alarm \
  --alarm-name "Lambda-Duration-Anomaly" \
  --alarm-description "Detect unusual Lambda duration" \
  --metric-name Duration \
  --namespace AWS/Lambda \
  --statistic Average \
  --period 300 \
  --evaluation-periods 2 \
  --threshold-metric-id d1 \
  --comparison-operator LessThanLowerOrGreaterThanUpperThreshold \
  --metrics '[
    {
      "Id": "d1",
      "ReturnData": true,
      "MetricStat": {
        "Metric": {
          "Namespace": "AWS/Lambda",
          "MetricName": "Duration",
          "Dimensions": [
            {
              "Name": "FunctionName",
              "Value": "bedrock-agent"
            }
          ]
        },
        "Period": 300,
        "Stat": "Average"
      }
    },
    {
      "Id": "ad1",
      "Expression": "ANOMALY_DETECTOR(d1, 2)",
      "ReturnData": true
    }
  ]'
```

### Statistical Anomaly Detection

#### Baseline Establishment
```
Procedure:
1. Collect 1-2 weeks of normal metrics
2. Calculate mean and standard deviation
3. Set thresholds at mean ± 2σ (95% confidence)
4. Monitor for deviations
5. Adjust thresholds quarterly

Metrics to monitor:
- API response times (latency)
- Error rates by type
- Database query times
- Network traffic volume
- Resource utilization (CPU, memory)
- Authentication attempts
```

#### Anomaly Scoring
```
Calculation:
Score = (Observed - Baseline) / StandardDeviation

Interpretation:
|Score| < 1σ: Normal (68% of data)
1σ < |Score| < 2σ: Unusual (16% of data)
2σ < |Score| < 3σ: Anomalous (2.1% of data)
|Score| > 3σ: Alert (0.1% of data)

Alert thresholds:
- 2σ: MEDIUM severity, investigate
- 3σ: HIGH severity, escalate
- 4σ: CRITICAL severity, immediate action
```

## Threat Intelligence

### AWS Threat Intelligence Integration

#### GuardDuty Threat Intelligence
```
Built-in Intelligence:
- Malicious IP reputation
- Botnet command & control domains
- Cryptocurrency mining pools
- Known malicious S3 buckets
- Vulnerability exploits

Feeds from:
- AWS threat research team
- Security vendor partnerships
- Abuse.ch
- SANS Internet Storm Center
- Commercial threat intelligence
```

### External Threat Intelligence

#### Integrate Third-Party Feeds
```bash
# Store threat intelligence in DynamoDB
aws dynamodb create-table \
  --table-name threat-intelligence \
  --attribute-definitions \
    AttributeName=IOCHash,AttributeType=S \
    AttributeName=Type,AttributeType=S \
  --key-schema \
    AttributeName=IOCHash,KeyType=HASH \
    AttributeName=Type,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST

# Lambda to correlate findings with feeds
def check_threat_intelligence(ip_address, feed):
    """Check if IP in threat intelligence feed"""
    response = dynamodb.get_item(
        TableName='threat-intelligence',
        Key={'IOCHash': {'S': hash_ip(ip_address)}}
    )
    return 'Item' in response
```

### Threat Intelligence Sharing

#### STIX Format Export
```json
{
  "type": "bundle",
  "id": "bundle--bedrock-ioc",
  "objects": [
    {
      "type": "malware",
      "id": "malware--bedrock-malware-1",
      "name": "Bedrock.Stealer",
      "created": "2024-11-17T00:00:00Z"
    },
    {
      "type": "indicator",
      "id": "indicator--bedrock-ioc-1",
      "pattern": "[file:hashes.MD5 = 'd41d8cd98f00b204e9800998ecf8427e']",
      "valid_from": "2024-11-17T00:00:00Z"
    }
  ]
}
```

## Indicators of Compromise

### IOC Categories

#### File-Based IOCs
```
Hash values:
- MD5: d41d8cd98f00b204e9800998ecf8427e
- SHA-1: da39a3ee5e6b4b0d3255bfef95601890afd80709
- SHA-256: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855

File names:
- malware.exe
- system32.dll
- rundll32.exe (suspicious parent)
- lsass.exe (if not in system32)

Paths:
- C:\Users\*\AppData\Roaming\suspicious
- C:\ProgramData\malware
- /tmp/malicious.sh
```

#### Network IOCs
```
Malicious IPs:
- 192.0.2.0/24 (known botnet)
- 198.51.100.5 (C&C server)
- 203.0.113.0/25 (malicious ISP)

Malicious Domains:
- malware.com
- command-and-control.ru
- crypto-miner.cn

URLs:
- http://attacker.com/payload.exe
- https://c2.malicious.net/check-in
- ftp://exfil.attacker.com/stolen-data
```

#### Behavioral IOCs
```
Suspicious Process Activity:
- cmd.exe spawning powershell
- lsass.exe spawning calc.exe
- system.exe with network connections
- explorer.exe with parent other than userinit

Suspicious Network Activity:
- Large data transfers to unknown IP
- Connection to known C&C on port 443
- DNS requests to suspicious domains
- Unencrypted transmission of secrets
```

#### Log IOCs
```
Suspicious log entries:
- Failed login attempts (>5 in 5 min)
- Privilege escalation attempts
- Deleted audit logs
- Suspicious scheduled tasks
- New user accounts in night hours
```

### IOC Detection Implementation

#### CloudWatch Logs Insights Query
```
# Detect known malicious IP connections
fields @timestamp, sourceIP, destinationIP, bytes_out
| filter sourceIP IN ["192.0.2.0", "198.51.100.5", "203.0.113.10"]
| stats sum(bytes_out) as total_exfil by sourceIP

# Detect suspicious process spawning
fields @timestamp, process_name, parent_process
| filter parent_process = "explorer.exe" and process_name NOT IN ["notepad", "calc"]
| stats count() by sourceIP
```

#### Lambda Detection Function
```python
import json
import hashlib
from boto3 import client

dynamodb = client('dynamodb')
security_hub = client('securityhub')

IOC_TABLE = 'threat-intelligence'

def check_ioc(ioc_value, ioc_type):
    """Check if value in threat intelligence database"""
    response = dynamodb.get_item(
        TableName=IOC_TABLE,
        Key={
            'IOCHash': {'S': hashlib.sha256(ioc_value.encode()).hexdigest()},
            'Type': {'S': ioc_type}
        }
    )
    return 'Item' in response

def detect_compromise(event, context):
    """Detect IOCs in logs and alert"""
    findings = []

    for record in event['Records']:
        log_event = json.loads(record['body'])

        # Check file hashes
        if 'file_hash' in log_event:
            if check_ioc(log_event['file_hash'], 'file_hash'):
                findings.append({
                    'Title': 'Malicious File Detected',
                    'Severity': 'CRITICAL',
                    'Details': f"Known malware hash: {log_event['file_hash']}"
                })

        # Check IPs
        if 'source_ip' in log_event:
            if check_ioc(log_event['source_ip'], 'ip'):
                findings.append({
                    'Title': 'Malicious IP Connection',
                    'Severity': 'CRITICAL',
                    'Details': f"Known malicious IP: {log_event['source_ip']}"
                })

    if findings:
        for finding in findings:
            security_hub.batch_import_findings(
                Findings=[
                    {
                        'Title': finding['Title'],
                        'Severity': {'Label': finding['Severity']},
                        'Description': finding['Details']
                    }
                ]
            )

    return {'statusCode': 200}
```

## Response Automation

### Automated Response Workflows

#### High-Severity GuardDuty Finding
```python
import boto3

guardduty = boto3.client('guardduty')
ec2 = boto3.client('ec2')
sns = boto3.client('sns')

def respond_to_finding(finding):
    """Automated response to high-severity findings"""

    severity = finding['Severity']
    finding_type = finding['Type']

    if severity >= 7:  # High or Critical

        if 'EC2_UnauthorizedAccess' in finding_type:
            # Isolate compromised instance
            instance_id = finding['Resource']['InstanceDetails']['InstanceId']

            # Remove from load balancer
            ec2.modify_instance_attribute(
                InstanceId=instance_id,
                DisableApiTermination={'Value': False}
            )

            # Revoke outbound access
            response = ec2.describe_security_groups(
                GroupIds=[finding['Resource']['InstanceDetails']['NetworkInterfaces'][0]['GroupSet'][0]['GroupId']]
            )
            sg_id = response['SecurityGroups'][0]['GroupId']

            # Remove all egress rules except essential
            for rule in response['SecurityGroups'][0]['IpPermissionsEgress']:
                if rule['IpProtocol'] != '-1':  # Not "all traffic"
                    ec2.revoke_security_group_egress(
                        GroupId=sg_id,
                        IpPermissions=[rule]
                    )

            # Notify team
            sns.publish(
                TopicArn='arn:aws:sns:region:account:critical-alerts',
                Subject='EC2 Instance Compromised - Isolated',
                Message=f'Instance {instance_id} has been isolated due to unauthorized access'
            )

        elif 'IAM_PrivilegeEscalation' in finding_type:
            # Get IAM details
            principal = finding['Resource']['AccessKeyDetails']['PrincipalId']

            # Deactivate access keys
            iam = boto3.client('iam')
            user = finding['Resource']['AccessKeyDetails']['UserName']

            keys = iam.list_access_keys(UserName=user)
            for key in keys['AccessKeyMetadata']:
                iam.update_access_key(
                    UserName=user,
                    AccessKeyId=key['AccessKeyId'],
                    Status='Inactive'
                )

            # Notify team
            sns.publish(
                TopicArn='arn:aws:sns:region:account:critical-alerts',
                Subject='IAM Privilege Escalation Detected',
                Message=f'User {user} attempted privilege escalation. Keys deactivated.'
            )

def lambda_handler(event, context):
    """Process GuardDuty findings"""

    finding = json.loads(event['detail'])

    if finding['severity'] >= 7:
        respond_to_finding(finding)

    return {'statusCode': 200}
```

## Finding Analysis

### Analysis Procedures

#### Severity Assessment
```
High Severity Factors:
- Data access (confidentiality impact)
- Unauthorized system changes (integrity impact)
- Service disruption (availability impact)
- Multiple failed attempts (escalation risk)
- Known exploit patterns (attack confidence)

Low Severity Factors:
- Internal-only impact
- Easily reversible
- Limited scope
- No sensitive data
- Informational only
```

#### Context Enrichment
```
Add to finding:
1. Business Context
   - What data could be accessed?
   - What is the impact?
   - Who should be notified?

2. Technical Context
   - When was it detected?
   - How long was access available?
   - What actions were taken?
   - What IAM permissions available?

3. Historical Context
   - Has this happened before?
   - Is this a pattern?
   - Related to known threat?
   - Industry-wide activity?
```

## Threat Hunting

### Proactive Hunting Procedures

#### Hunt Scenario: Unauthorized Data Access
```
Hypothesis: Attacker gained access and exfiltrated data

Investigation steps:

1. Query CloudTrail for anomalous GetObject calls
   - Filter by unusual time of day
   - Filter by unusual source IP
   - Filter by bulk download patterns

2. Correlate with network logs
   - Check VPC Flow Logs for large outbound transfers
   - Identify destination IPs
   - Check if destinations are known malicious

3. Review database activity
   - Check RDS audit logs for unusual queries
   - Look for SELECT * (full table scans)
   - Check for data exports
   - Look for connection from unusual IPs

4. Analyze user behavior
   - Review MFA bypass attempts
   - Check for credential sharing
   - Look for unusual API calls
   - Review approval logs

Queries:
- CloudTrail: s3:GetObject from unusual IPs
- VPC Flow Logs: Large data transfers out
- RDS Audit: SELECT from sensitive tables
- IAM: AssumeRole by unusual principals
```

#### Hunt Scenario: Lateral Movement
```
Hypothesis: Attacker gained initial access and moved laterally

Investigation steps:

1. Map initial compromise
   - CloudTrail: Initial API call
   - VPC Flow Logs: First connection
   - GuardDuty: Initial finding

2. Track lateral movement
   - IAM: AssumeRole calls in timeline
   - EC2: SecurityGroupIngress rule changes
   - RDS: New connections from unexpected IPs
   - Lambda: Function invocations from IPs

3. Identify additional compromise
   - New access keys created
   - SSH keys added
   - Database password changes
   - Role policy modifications

4. Determine scope
   - All systems accessed
   - All data accessed
   - All modifications made
   - Timeline of movement
```

## Detection Tuning

### Reducing False Positives

#### Whitelist Known Activity
```bash
# Create Security Hub custom insight to exclude known-good
aws securityhub create-insight \
  --name "Important-Findings-Only" \
  --filters '{
    "SeverityLabel": [{"Value": "CRITICAL", "Comparison": "EQUALS"}],
    "ResourceType": [{"Value": "AwsIam", "Comparison": "EQUALS"}],
    "ComplianceStatus": [{"Value": "FAILED", "Comparison": "EQUALS"}],
    "RecordState": [{"Value": "ACTIVE", "Comparison": "EQUALS"}]
  }'
```

#### Suppress Known False Positives
```python
def suppress_finding(finding_id, reason):
    """Suppress low-value finding"""
    security_hub.batch_update_findings(
        FindingUpdates=[
            {
                'FindingIdentifiers': {
                    'Id': finding_id
                },
                'RecordState': 'SUPPRESSED',
                'Note': {
                    'Text': reason
                }
            }
        ]
    )
```

### Alert Tuning

#### Adjust GuardDuty Sensitivity
```bash
# Update finding publishing frequency
aws guardduty update-detector \
  --detector-id DETECTOR_ID \
  --finding-publishing-frequency FIFTEEN_MINUTES
```

#### Alert Threshold Adjustment
```bash
# Increase alert threshold for low-risk metric
aws cloudwatch put-metric-alarm \
  --alarm-name "API-Errors-Alert" \
  --metric-name APIErrors \
  --threshold 5  # Instead of 1, reducing noise
```

---

**Document Version**: 1.0
**Last Updated**: November 2024
**Next Review**: May 2025
