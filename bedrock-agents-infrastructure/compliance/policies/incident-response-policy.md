# Incident Response Policy
## Amazon Bedrock Agents Infrastructure

**Document Version:** 1.0
**Effective Date:** 2025-11-17
**Policy Owner:** Chief Information Security Officer (CISO)
**Incident Response Team Lead:** Security Operations Manager

---

## 1. Purpose

This Incident Response Policy establishes procedures for detecting, responding to, investigating, and recovering from security incidents affecting Amazon Bedrock Agents infrastructure.

## 2. Scope

- All security incidents affecting Bedrock infrastructure
- Data breaches involving PII, PHI, PCI, or RESTRICTED data
- Unauthorized access to AWS resources
- Malware, ransomware, or cryptojacking incidents
- Denial of service attacks
- Insider threats
- Third-party security incidents affecting our data

## 3. Incident Classification

### Severity Levels

**CRITICAL (P1):**
- Active data breach with confirmed exfiltration
- Ransomware encryption of production systems
- Complete service outage affecting business operations
- Unauthorized access to RESTRICTED data (PII/PHI/PCI)
- Response time: Immediate (within 1 hour)

**HIGH (P2):**
- Suspected data breach (unconfirmed exfiltration)
- Malware infection on production systems
- Unauthorized access to CONFIDENTIAL data
- Attempted ransomware attack (blocked)
- Major service degradation
- Response time: Within 4 hours

**MEDIUM (P3):**
- Security control failure
- Unauthorized access to INTERNAL data
- Phishing attempt targeting employees
- Suspicious activity detected
- Minor service degradation
- Response time: Within 24 hours

**LOW (P4):**
- Policy violations
- False positive security alerts
- Informational security events
- Response time: Within 72 hours

## 4. Incident Response Team

**Roles:**
- **Incident Commander:** Overall incident coordination
- **Security Lead:** Technical investigation and containment
- **Communications Lead:** Internal and external communications
- **Legal Counsel:** Legal and regulatory guidance
- **Privacy Officer:** Data protection and GDPR/HIPAA compliance
- **Business Owner:** Business impact assessment and decisions
- **Technical Subject Matter Experts:** AWS, Bedrock, networking, forensics

## 5. Incident Response Phases

### Phase 1: Preparation
- Incident response plan documented and tested
- IR team identified and trained (quarterly)
- Detection tools configured (GuardDuty, Security Hub, Macie)
- Playbooks developed for common scenarios
- Contact lists maintained and current
- Forensic tools and environments ready

### Phase 2: Detection and Analysis
**Detection Sources:**
- AWS GuardDuty alerts
- Security Hub findings
- Macie sensitive data findings
- CloudWatch alarms
- VPC Flow Log analysis
- User reports
- Third-party threat intelligence

**Initial Analysis:**
1. Alert triage and validation
2. Incident classification (severity)
3. Scope determination
4. Evidence preservation
5. IR team activation

**Automated Detection:**
```hcl
# GuardDuty automated response
resource "aws_cloudwatch_event_rule" "guardduty_finding" {
  name        = "guardduty-critical-finding"
  description = "Trigger on critical GuardDuty findings"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [7, 8, 9]  # High and Critical findings
    }
  })
}

resource "aws_cloudwatch_event_target" "guardduty_lambda" {
  rule      = aws_cloudwatch_event_rule.guardduty_finding.name
  target_id = "GuardDutyResponseLambda"
  arn       = aws_lambda_function.incident_response_automation.arn
}
```

### Phase 3: Containment

**Short-term Containment:**
- Isolate affected resources (security group modification)
- Disable compromised credentials
- Block malicious IP addresses (NACL, WAF)
- Snapshot systems for forensics
- Preserve evidence (CloudTrail logs, memory dumps)

**Long-term Containment:**
- Apply patches and security updates
- Rebuild compromised systems
- Implement additional monitoring
- Deploy compensating controls

**Automated Containment:**
```python
# Lambda function for automated containment
import boto3

def lambda_handler(event, context):
    ec2 = boto3.client('ec2')
    iam = boto3.client('iam')

    finding = event['detail']
    severity = finding['severity']
    resource_type = finding['resource']['resourceType']

    if severity >= 7:  # High or Critical
        if resource_type == 'Instance':
            instance_id = finding['resource']['instanceDetails']['instanceId']
            # Isolate instance by modifying security group
            isolate_instance(ec2, instance_id)

        elif resource_type == 'AccessKey':
            access_key_id = finding['resource']['accessKeyDetails']['accessKeyId']
            # Disable compromised access key
            disable_access_key(iam, access_key_id)

        # Send critical alert
        send_alert(finding)

    return {
        'statusCode': 200,
        'body': 'Containment actions executed'
    }

def isolate_instance(ec2, instance_id):
    # Create isolation security group
    isolation_sg = create_isolation_security_group(ec2)
    # Apply to instance
    ec2.modify_instance_attribute(
        InstanceId=instance_id,
        Groups=[isolation_sg['GroupId']]
    )

def disable_access_key(iam, access_key_id):
    iam.update_access_key(
        AccessKeyId=access_key_id,
        Status='Inactive'
    )
```

### Phase 4: Eradication
- Remove malware and malicious artifacts
- Close attack vectors
- Delete unauthorized accounts
- Revoke unauthorized permissions
- Patch vulnerabilities exploited
- Update security controls

### Phase 5: Recovery
- Restore systems from clean backups
- Verify system integrity
- Enable monitoring
- Return to normal operations
- Gradual service restoration
- Continuous monitoring for re-infection

### Phase 6: Post-Incident Activity
- Incident report documentation
- Root cause analysis
- Lessons learned session
- Update incident response procedures
- Security control improvements
- Training updates
- Compliance notifications (if required)

## 6. Data Breach Response

### GDPR Data Breach (72-hour notification)
1. **Detection:** Identify breach involving EU personal data
2. **Assessment:** Determine risk to data subjects
3. **Documentation:** Record breach details
4. **Notification to Supervisory Authority:**
   - Timeline: 72 hours of becoming aware
   - Content: Nature, categories, approximate numbers, DPO contact, consequences, measures taken
5. **Notification to Data Subjects:**
   - Condition: High risk to rights and freedoms
   - Timeline: Without undue delay
   - Method: Direct communication (email, letter)
6. **Breach Register:** Update internal breach register

### HIPAA Breach (60-day notification)
1. **Discovery:** Unauthorized PHI access, use, or disclosure
2. **Risk Assessment:** Apply HIPAA risk assessment methodology
3. **Notification to HHS:**
   - \>500 individuals: Within 60 days
   - <500 individuals: Annual log to HHS
4. **Notification to Individuals:** Within 60 days
5. **Media Notification:** If >500 individuals in same state
6. **Business Associate Notification:** Within 60 days to covered entity

### PCI DSS Data Breach
1. **Immediate Actions:** Contain breach, preserve evidence
2. **Notification to Acquirer:** Immediately
3. **Notification to Card Brands:** Per card brand rules
4. **Forensic Investigation:** PFI-qualified forensic investigator
5. **Remediation:** Address vulnerabilities
6. **Compliance Validation:** Post-incident PCI DSS assessment

**Automated Breach Detection:**
```hcl
# Macie job for sensitive data exposure detection
resource "aws_macie2_classification_job" "pii_phi_pci_detection" {
  job_type = "SCHEDULED"
  name     = "pii-phi-pci-detection-daily"

  s3_job_definition {
    bucket_definitions {
      account_id = data.aws_caller_identity.current.account_id
      buckets    = var.bedrock_data_bucket_names
    }
  }

  schedule_frequency {
    daily_schedule = true
  }

  custom_data_identifier_ids = [
    aws_macie2_custom_data_identifier.ssn.id,
    aws_macie2_custom_data_identifier.credit_card.id,
    aws_macie2_custom_data_identifier.health_record.id
  ]
}

# EventBridge rule for Macie findings
resource "aws_cloudwatch_event_rule" "macie_sensitive_data_finding" {
  name        = "macie-sensitive-data-exposure"
  description = "Alert on sensitive data exposure findings"

  event_pattern = jsonencode({
    source      = ["aws.macie"]
    detail-type = ["Macie Finding"]
    detail = {
      severity = {
        description = ["High", "Critical"]
      }
      category = ["CLASSIFICATION"]
    }
  })
}

resource "aws_cloudwatch_event_target" "breach_response_lambda" {
  rule      = aws_cloudwatch_event_rule.macie_sensitive_data_finding.name
  target_id = "BreachResponseLambda"
  arn       = aws_lambda_function.data_breach_response.arn
}
```

## 7. Communication Plan

### Internal Communications
- **Incident Commander:** Overall updates, executive briefings
- **Security Team:** Technical details, investigation status
- **Legal:** Regulatory implications, litigation holds
- **PR/Communications:** External messaging, media inquiries
- **Business Units:** Service impact, recovery timelines

### External Communications
- **Customers:** Breach notifications, service status
- **Regulators:** GDPR (72h), HIPAA (60d), PCI DSS (immediate)
- **Law Enforcement:** If criminal activity suspected
- **Media:** Coordinated with PR team
- **Partners/Vendors:** If third-party data affected

### Communication Templates
- Critical incident email template
- Customer breach notification letter (GDPR, HIPAA)
- Regulatory authority notification template
- Media statement template
- Internal status update template

## 8. Evidence Preservation

**Critical Evidence:**
- CloudTrail logs (all regions)
- VPC Flow Logs
- S3 access logs
- Bedrock invocation logs
- CloudWatch Logs
- GuardDuty findings
- Security Hub findings
- Macie findings
- Memory dumps (if applicable)
- Disk snapshots (forensic copies)

**Chain of Custody:**
- Evidence collected by authorized personnel only
- Hash values calculated and documented
- Secure storage with encryption
- Access logged and restricted
- Integrity verification before analysis

**Retention:**
- Incident evidence: 7 years minimum
- Legal hold: Indefinite until lifted by legal counsel

**Implementation:**
```hcl
# Forensic S3 bucket for evidence storage
resource "aws_s3_bucket" "forensic_evidence" {
  bucket = "forensic-evidence-${var.account_id}"
}

resource "aws_s3_bucket_versioning" "forensic_evidence" {
  bucket = aws_s3_bucket.forensic_evidence.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "forensic_evidence" {
  bucket = aws_s3_bucket.forensic_evidence.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.forensic_cmk.arn
    }
  }
}

resource "aws_s3_bucket_object_lock_configuration" "forensic_evidence" {
  bucket = aws_s3_bucket.forensic_evidence.id
  rule {
    default_retention {
      mode  = "COMPLIANCE"
      years = 7
    }
  }
}
```

## 9. Incident Playbooks

### Playbook 1: Ransomware Attack
1. **Detect:** GuardDuty finding for ransomware or unusual encryption activity
2. **Contain:**
   - Isolate affected instances (modify security groups)
   - Disable user accounts with unusual file modification activity
   - Snapshot instances before shutdown
3. **Eradicate:**
   - DO NOT pay ransom
   - Terminate infected instances
   - Scan backups for malware before restore
4. **Recover:**
   - Restore from last known good backup
   - Verify backup integrity and cleanliness
   - Rebuild infrastructure from Infrastructure as Code (Terraform)
5. **Post-Incident:**
   - Patch vulnerabilities
   - Implement additional endpoint detection
   - Update backup procedures

### Playbook 2: Unauthorized Bedrock Access
1. **Detect:** CloudTrail log shows unauthorized Bedrock agent invocation
2. **Analyze:**
   - Identify user/role/access key used
   - Determine scope (what data accessed)
   - Check for data exfiltration
3. **Contain:**
   - Disable compromised credentials
   - Revoke active sessions (STS token revocation)
   - Block source IP (NACL, WAF)
4. **Investigate:**
   - Review all API calls by compromised identity
   - Analyze Bedrock invocation logs for sensitive queries
   - Determine if PII/PHI/PCI accessed
5. **Notify:**
   - If RESTRICTED data accessed, initiate breach notification procedures

### Playbook 3: Credential Compromise
1. **Detect:** GuardDuty "UnauthorizedAccess" or "Exfiltration" finding
2. **Contain:**
   - Disable access keys immediately
   - Rotate all secrets in Secrets Manager
   - Revoke all active sessions for user
3. **Investigate:**
   - Review CloudTrail for all API calls by compromised credential
   - Determine resources accessed
   - Check for privilege escalation
4. **Remediate:**
   - Issue new credentials securely
   - Enforce MFA if not already enabled
   - Review and tighten IAM policies

## 10. Metrics and Reporting

**Key Performance Indicators:**
- Mean Time to Detect (MTTD): <15 minutes for CRITICAL
- Mean Time to Respond (MTTR): <1 hour for CRITICAL
- Mean Time to Contain (MTTC): <4 hours for CRITICAL
- Mean Time to Recover (MTTRec): <24 hours for CRITICAL
- False Positive Rate: <10%

**Incident Reporting:**
- Executive summary: Within 24 hours of resolution
- Technical report: Within 7 days
- Lessons learned: Within 14 days
- Quarterly incident trend analysis
- Annual incident response effectiveness review

## 11. Testing and Training

**Tabletop Exercises:**
- Frequency: Quarterly
- Scenarios: Data breach, ransomware, insider threat, DDoS
- Participants: IR team, executives, business owners

**Simulated Incidents:**
- Frequency: Annual
- Technical execution of response procedures
- Forensic analysis practice
- Communication drills

**Training:**
- IR team: Advanced training annually
- All employees: Annual security awareness (incident reporting)
- New hires: Within first 30 days

## Document Control

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-11-17 | CISO | Initial policy |

**Next Review:** 2026-11-17
