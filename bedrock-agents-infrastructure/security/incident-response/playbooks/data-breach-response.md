# Data Breach Response Playbook

## Overview

This playbook provides a structured response to suspected or confirmed data
breaches affecting Bedrock agents infrastructure.

## Detection Criteria

- Unauthorized data exfiltration detected by DLP systems
- Unusual data access patterns in CloudWatch logs
- Third-party notification of data appearing in breach databases
- Large data transfers to unknown external IPs
- Unexpected S3 bucket public access
- Database backup accessed outside normal windows

## Severity Classification

### Critical (P1)

- Production database data exposed
- Customer PII (names, email, phone) compromised
- Payment card information (PCI) exposed
- More than 10,000 records affected
- Regulatory breach requiring immediate notification

### High (P2)

- Non-production data exposed
- 1,000-10,000 records affected
- Internal data leaked
- Source code or configuration exposed

### Medium (P3)

- Less than 1,000 records
- Non-sensitive internal data
- No customer impact

### Low (P4)

- Metadata only
- No actual data accessed
- Internal use case

## Response Steps

### Phase 1: Immediate Response (0-2 hours)

1. **Activate Incident Response Team**

   - Page on-call security lead
   - Activate incident war room (Slack channel #incident-response)
   - Notify CISO and Legal within 15 minutes

2. **Verify the Breach**

   - Confirm alert authenticity
   - Check detection source reliability
   - Validate scope of exposure
   - Document initial findings

3. **Preserve Evidence**

   - Enable forensics mode on affected agents
   - Capture CloudWatch logs (6 months retention)
   - Create S3 snapshots of accessed data
   - Preserve network traffic captures (PCAP files)
   - Lock affected IAM credentials (do not delete)

4. **Initial Containment**
   - Execute `isolate-compromised-agent.json` runbook
   - Revoke suspicious IAM sessions
   - Disable affected service accounts
   - Block suspicious IPs at WAF level

### Phase 2: Investigation (2-8 hours)

1. **Scope Determination**

   - Query CloudTrail for affected resources
   - Analyze S3 access logs
   - Review RDS query logs
   - Determine what data was accessed/exfiltrated
   - Identify affected customer accounts

2. **Root Cause Analysis**

   - Examine compromise vector (credential theft, vulnerability, etc.)
   - Trace access path through infrastructure
   - Identify lateral movement attempts
   - Document timeline of events
   - Run `timeline-builder.py` forensics script

3. **Evidence Collection**

   - Execute `capture-logs.py` for comprehensive logging
   - Run `network-capture.py` for traffic analysis
   - Execute `snapshot-resources.py` for point-in-time recovery
   - Preserve all audit logs
   - Tag all resources for forensic analysis

4. **Communication**
   - Update incident status every 2 hours
   - Notify stakeholders of confirmed breach
   - Coordinate with Legal on disclosure timeline
   - Prepare customer communication draft

### Phase 3: Containment (2-24 hours)

1. **Access Revocation**

   - Execute `rotate-all-credentials.json` runbook
   - Reset all MFA devices
   - Invalidate all active sessions
   - Force re-authentication for all users
   - Review and revoke API keys

2. **System Hardening**

   - Apply security patches
   - Update WAF rules to block attack patterns
   - Enable additional CloudTrail logging
   - Increase monitoring alert sensitivity
   - Deploy additional detective controls

3. **Infrastructure Changes**
   - Rotate all encryption keys
   - Create new database snapshots for recovery
   - Enable versioning on all S3 buckets
   - Implement bucket policies to prevent public access
   - Review and tighten IAM policies

### Phase 4: Eradication (24-72 hours)

1. **Threat Removal**

   - Remove backdoors or suspicious code
   - Patch exploited vulnerabilities
   - Remove unauthorized IAM roles/users
   - Delete compromised service accounts
   - Clean up suspicious Lambda functions

2. **System Restoration**

   - Rebuild affected systems from golden AMIs
   - Restore databases from clean backups
   - Redeploy applications from source control
   - Validate integrity of all restored systems
   - Run security validation tests

3. **Verification**
   - Scan systems for indicators of compromise (IOCs)
   - Review logs for any remaining unauthorized access
   - Validate backup integrity
   - Confirm all backdoors are removed
   - Test incident response procedures

### Phase 5: Recovery (72 hours - 2 weeks)

1. **System Bring-Up**

   - Gradually restore services in priority order
   - Monitor for anomalies during restoration
   - Validate system functionality
   - Test critical business processes
   - Monitor for resurgence of attack

2. **Communication**

   - Issue customer notifications if required
   - Regulatory filings if mandatory
   - Public statement if appropriate
   - Document lessons learned
   - Brief executive leadership

3. **Validation**
   - Confirm all affected customers notified
   - Verify breach notification compliance
   - Validate remediation effectiveness
   - Perform penetration testing
   - Review security baseline

## Containment Procedures

### Immediate Actions

```bash
# Stop data exfiltration
- Block suspicious destination IPs at WAF
- Revoke affected IAM credentials
- Disable affected agents
- Stop replication to untrusted locations
```

### Data Protection

```bash
- Encrypt sensitive data in transit
- Enable server-side encryption verification
- Restrict S3 bucket access to principals-only
- Enable MFA delete on critical buckets
- Review and restrict database user permissions
```

### Access Control

```bash
- Revoke all temporary credentials
- Force session re-authentication
- Disable API keys for affected services
- Implement short-lived credentials
- Enable additional MFA enforcement
```

## Eradication Steps

### 1. Threat Removal

- [ ] Identify and remove malware/backdoors
- [ ] Patch exploited vulnerabilities
- [ ] Review and remove unauthorized access
- [ ] Clean application code repositories
- [ ] Validate removal with security scan

### 2. System Hardening

- [ ] Update all security baselines
- [ ] Strengthen authentication mechanisms
- [ ] Implement network segmentation
- [ ] Enable DLP controls
- [ ] Deploy host-based protection

### 3. Code Review

- [ ] Audit recent code changes
- [ ] Review for injected malicious code
- [ ] Validate integrity of binaries
- [ ] Scan dependencies for vulnerabilities
- [ ] Implement code signing

## Recovery Procedures

### Data Recovery

1. Identify clean backup point
2. Create isolated recovery environment
3. Restore data from verified backups
4. Validate data integrity
5. Gradually bring systems online
6. Monitor for attack resurgence

### Service Restoration

1. Restore in priority order (critical → standard)
2. Validate functionality at each step
3. Monitor performance and logs
4. Implement gradual traffic migration
5. Maintain rollback capability

### Verification

1. Confirm all services operational
2. Validate data consistency
3. Review security controls active
4. Confirm monitoring and alerting
5. Test incident response procedures

## Post-Incident Review

### Forensic Analysis

- Root cause determination
- Attack vector identification
- Attacker capabilities assessment
- Exposure duration calculation
- Security gap analysis

### Compliance & Legal

- Regulatory notification requirements
- Customer notification obligations
- Documentation for audit
- Evidence preservation for legal
- Insurance claim support

### Improvement Actions

- Prevent similar breaches
- Improve detection capability
- Strengthen response procedures
- Update security controls
- Train personnel on findings

## Contacts & Escalation

### Immediate Contacts

- **Security Lead**: [On-call rotation in PagerDuty]
- **CISO**: [CISO contact information]
- **Legal**: [Legal department contact]
- **Incident Commander**: [Rotation schedule]

### Escalation Path

```
1. On-call Security Engineer (first responder)
2. Security Lead (tactical decisions)
3. CISO (strategic decisions, disclosure)
4. CEO/General Counsel (legal/PR decisions)
5. Regulatory bodies (if required)
```

### External Contacts

- **Regulatory Bodies**: [Contact information]
- **Customers**: [Notification procedures]
- **Law Enforcement**: [FBI/Secret Service contacts]
- **PR/Communications**: [PR firm contact]

## Tools & Resources

### Investigation Tools

- AWS CloudTrail (audit logs)
- Amazon GuardDuty (threat detection)
- CloudWatch Logs (application logs)
- VPC Flow Logs (network traffic)
- S3 Access Logs (object access)
- RDS Enhanced Monitoring

### Response Runbooks

- isolate-compromised-agent.json
- rotate-all-credentials.json
- enable-forensics-mode.json
- collect-evidence.json

### Forensics Scripts

- capture-logs.py
- snapshot-resources.py
- network-capture.py
- timeline-builder.py

## Metrics & KPIs

Track during incident:

- **Detection to Confirmation**: < 15 minutes
- **Confirmation to Isolation**: < 30 minutes
- **Isolation to Containment**: < 2 hours
- **Root Cause Analysis**: < 8 hours
- **Time to Recovery**: < 72 hours
- **Customer Notification**: < 72 hours (if required)

## Related Playbooks

- [Compromised Credentials Response](./compromised-credentials.md)
- [Unauthorized Access Response](./unauthorized-access.md)
- [DDoS Attack Response](./ddos-attack-response.md)

## Revision History

- v1.0 - Initial creation (2024-11-17)
