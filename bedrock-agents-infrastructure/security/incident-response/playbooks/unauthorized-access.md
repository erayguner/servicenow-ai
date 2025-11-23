# Unauthorized Access Response Playbook

## Overview
Response procedures for unauthorized access to Bedrock agents infrastructure.

## Detection Criteria
- Unexpected console/SSH access attempts
- Access from unknown IP addresses
- Failed authentication attempts followed by success
- Access outside business hours
- Geographically impossible access
- Privilege escalation attempts
- Access to sensitive resources
- Service account with unusual access patterns
- Brute force attack detection
- Failed MFA attempts
- Account lockouts

## Severity Classification

### Critical (P1)
- Administrative/root access gained
- Production systems accessed
- Data exfiltration in progress
- Multiple systems compromised
- Active unauthorized access ongoing
- Privilege escalation to admin

### High (P2)
- User-level access to sensitive systems
- Attempted admin access
- Access to development/staging
- Potential data access
- Account takeover attempt

### Medium (P3)
- Access to non-sensitive resources
- Failed access attempts only
- Isolated incident
- Limited permissions
- No data access

### Low (P4)
- Repeated failed attempts (no success)
- System scanning only
- No active access
- Automated/scanner activity
- Whitelisted source

## Response Steps

### Phase 1: Immediate Response (0-30 minutes)

1. **Verify Unauthorized Access**
   - Confirm access occurred
   - Identify affected account/resource
   - Determine access method
   - Check access success
   - Review authentication logs

2. **Initial Containment**
   - Revoke session immediately
   - Reset user password
   - Execute `isolate-compromised-agent.json` if needed
   - Disable affected account temporarily
   - Block suspicious IP address

3. **Evidence Preservation**
   - Execute `capture-logs.py` immediately
   - Capture CloudTrail logs for account
   - Preserve access logs
   - Document alert source
   - Take screenshots

4. **Immediate Actions**
   - Notify account owner
   - Revoke all active sessions
   - Force re-authentication
   - Enable enhanced monitoring
   - Prepare for Phase 2

### Phase 2: Investigation (30 min - 4 hours)

1. **Unauthorized Access Analysis**
   - Query CloudTrail for all access by source
   - Review VPC Flow Logs
   - Analyze CloudWatch logs
   - Check application logs
   - Review session logs

2. **Scope Determination**
   - What resources were accessed?
   - What data was viewed/modified?
   - Which systems were affected?
   - Lateral movement attempted?
   - Persistence established?

3. **Timeline Construction**
   - Run `timeline-builder.py` for detailed timeline
   - When did access start?
   - What actions were performed?
   - When was access terminated?
   - Any suspicious activity post-access?

4. **Compromise Assessment**
   - Was system modified?
   - Malware/backdoor installed?
   - Credentials accessed?
   - Data exfiltrated?
   - Persistence mechanisms created?

### Phase 3: Containment (30 min - 24 hours)

1. **Access Revocation**
   - Reset password
   - Force re-authentication
   - Revoke API keys
   - Terminate all sessions
   - Disable temporary credentials
   - Force MFA re-enrollment

2. **Credential Management**
   - Execute `rotate-all-credentials.json` runbook
   - Change password immediately
   - Reset MFA tokens
   - Revoke access keys
   - Update service account passwords

3. **System Hardening**
   - Review IAM policies
   - Enforce MFA requirement
   - Implement IP whitelisting
   - Enable CloudTrail
   - Increase monitoring

4. **Investigation Continuation**
   - Execute `enable-forensics-mode.json`
   - Execute `memory-dump.py` if needed
   - Execute `snapshot-resources.py`
   - Preserve all evidence
   - Document findings

## Containment Procedures

### Account Lockdown
```bash
# 1. Immediate Actions
- Disable account (if compromised)
- Reset password to random value
- Force password change on next login
- Revoke all API keys
- Terminate all sessions

# 2. MFA Management
- Reset MFA devices
- Force MFA re-enrollment
- Require hardware MFA
- Review MFA bypass attempts
- Monitor for MFA failures

# 3. Access Review
- Review IAM roles
- Audit permissions
- Remove unnecessary access
- Enforce least privilege
- Document changes
```

### Session Management
```bash
# 1. Session Termination
- Kill all active sessions
- Clear cached credentials
- Revoke temporary tokens
- Revoke browser cookies
- Clear application sessions

# 2. Credential Invalidation
- Expire all passwords
- Revoke API keys
- Invalidate SSH keys
- Disable service accounts
- Reset recovery codes
```

### Access Monitoring
```bash
# 1. Enhanced Monitoring
- Enable account audit logging
- Monitor all API calls
- Track console access
- Monitor failed attempts
- Alert on suspicious activity

# 2. Behavioral Monitoring
- Monitor login patterns
- Track privilege usage
- Monitor file access
- Monitor database access
- Track unusual activities
```

## Eradication Steps

### Threat Removal
- [ ] Remove unauthorized accounts
- [ ] Delete malware/backdoors
- [ ] Remove persistence mechanisms
- [ ] Clean system if needed
- [ ] Rebuild if compromised

### Access Control Review
- [ ] Audit all IAM policies
- [ ] Review service accounts
- [ ] Remove unnecessary permissions
- [ ] Implement MFA enforcement
- [ ] Enforce IP restrictions

### System Hardening
- [ ] Patch vulnerabilities
- [ ] Update security groups
- [ ] Review VPC configuration
- [ ] Strengthen authentication
- [ ] Enable detective controls

### Validation
- [ ] Confirm account locked down
- [ ] Verify monitoring active
- [ ] Test response procedures
- [ ] Validate remediation
- [ ] Document findings

## Recovery Procedures

### User Communication
1. Notify user of incident
2. Explain what happened
3. Provide new credentials
4. Guide on re-securing systems
5. Recommend actions (password change, etc.)

### System Validation
1. Confirm access revoked
2. Verify no persistence
3. Validate monitoring active
4. Test service functionality
5. Confirm security controls

### Access Restoration
1. Review user permissions
2. Gradually restore access
3. Monitor for anomalies
4. Validate user activities
5. Maintain enhanced monitoring

## Post-Incident Review

### Investigation Findings
- Attack vector used
- Duration of unauthorized access
- Systems/data accessed
- Activities performed
- Damage assessment

### Control Gaps
- Missing access controls
- Inadequate monitoring
- Weak authentication
- Insufficient logging
- Detection delays

### Improvement Actions
- MFA enforcement
- Access restriction policies
- Enhanced monitoring
- Better alerting
- User training

## Prevention Measures

### Authentication
- Enforce MFA on all accounts
- Implement passwordless auth
- Use hardware security keys
- Implement adaptive auth
- Regular password rotation

### Access Controls
- Enforce least privilege
- Regular access reviews
- IP whitelisting
- Geolocation restrictions
- Time-based access

### Monitoring
- Comprehensive audit logging
- Real-time alerting
- Behavioral analysis
- Failed attempt tracking
- Unusual pattern detection

### User Training
- Phishing awareness
- Credential security
- MFA usage
- Incident reporting
- Social engineering awareness

## Tools & Resources

### Access Control
- IAM Access Analyzer
- AWS IAM policies
- MFA enforcement tools
- VPC security groups
- Network ACLs

### Detection & Monitoring
- CloudTrail
- CloudWatch Logs
- VPC Flow Logs
- GuardDuty
- Security Hub

### Response Runbooks
- isolate-compromised-agent.json
- rotate-all-credentials.json
- enable-forensics-mode.json
- collect-evidence.json
- notify-stakeholders.json

### Forensics Tools
- capture-logs.py
- timeline-builder.py
- snapshot-resources.py
- memory-dump.py

## Metrics & KPIs

Track during incident:
- **Detection to Confirmation**: < 15 minutes
- **Confirmation to Containment**: < 30 minutes
- **Containment to Remediation**: < 4 hours
- **Root Cause Analysis**: < 8 hours
- **Time to Recovery**: < 24 hours
- **False Positive Rate**: < 5%

## Decision Tree

```
Unauthorized Access Detected?
├─ Verify Access
│  ├─ Confirmed: Proceed
│  └─ False Positive: Monitor
├─ Severity
│  ├─ P1: Full activation
│  ├─ P2: Limited activation
│  └─ P3/P4: Standard response
├─ Containment
│  ├─ Account: Reset credentials
│  ├─ System: Isolate and rebuild
│  └─ Data: Preserve and review
└─ Investigation
   ├─ Compromised: Full forensics
   └─ Not Compromised: Document
```

## Related Playbooks
- [Compromised Credentials Response](./compromised-credentials.md)
- [Data Breach Response](./data-breach-response.md)
- [Malware Detection Response](./malware-detection.md)

## Contacts & Escalation

### Response Team
- **Security Lead**: [On-call rotation]
- **System Administrator**: [On-call rotation]
- **Network Engineer**: [On-call rotation]
- **CISO**: [For major incidents]

### Escalation Path
```
1. Security Alert (automated)
2. On-call Security Engineer
3. Security Lead (tactical)
4. CISO (strategic)
5. Executive Team (major breach)
```

## Revision History
- v1.0 - Initial creation (2024-11-17)
