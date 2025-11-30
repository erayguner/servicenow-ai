# Compromised Credentials Response Playbook

## Overview

Response procedures for suspected or confirmed compromised credentials affecting
Bedrock agents infrastructure.

## Detection Criteria

- Credentials detected in public repositories (GitHub Secret Scanning)
- Leaked credentials in dark web/paste sites
- Unexpected API key usage from unknown locations
- Multiple failed authentication attempts followed by success
- Access from geographically impossible locations
- Unusual activity on service accounts
- Password spray attacks detected
- MFA bypass attempts

## Severity Classification

### Critical (P1)

- Root AWS account credentials exposed
- Database admin credentials compromised
- Production service account credentials leaked
- Active unauthorized use detected
- Multi-account access compromised

### High (P2)

- IAM user credentials with admin access
- API keys with broad permissions exposed
- Database user credentials compromised
- Application secrets exposed
- Potential active use

### Medium (P3)

- Limited-scope IAM credentials exposed
- API keys with restricted permissions
- No evidence of active use
- Automated secret rotation available

### Low (P4)

- Expired credentials exposed
- Read-only access credentials
- No evidence of compromise
- Automatic expiration in place

## Response Steps

### Phase 1: Immediate Response (0-1 hour)

1. **Alert Verification**

   - Confirm credential type and scope
   - Verify source of detection
   - Check if credential is currently active
   - Search for active use in logs

2. **Preliminary Containment**

   - Execute `rotate-all-credentials.json` for affected credential type
   - For AWS: Deactivate affected IAM access keys
   - For database: Change password immediately
   - For API keys: Revoke and regenerate
   - Block associated IP addresses at WAF

3. **Immediate Actions**

   - If currently in use: Force session termination
   - Revoke all sessions for compromised account
   - Disable MFA recovery codes
   - Reset authentication factors
   - Notify account owner

4. **Evidence Preservation**
   - Execute `capture-logs.py` for credential activity
   - Preserve CloudTrail logs for the account
   - Capture IAM access logs
   - Document the credential exposure source
   - Take screenshots of exposure

### Phase 2: Investigation (1-4 hours)

1. **Unauthorized Access Detection**

   - Query CloudTrail for all activity by credential
   - Review API Gateway access logs
   - Check CloudWatch logs for unusual patterns
   - Analyze VPC Flow Logs for anomalies
   - Run `timeline-builder.py` for detailed timeline

2. **Scope Analysis**

   - Determine what permissions credential had
   - Identify all resources accessible
   - Check for lateral movement
   - Review data access patterns
   - Identify potentially affected systems

3. **Activity Review**

   - When was credential first created?
   - When was it last used legitimately?
   - Any unusual access patterns?
   - Geographic location of usage
   - Time-of-day patterns

4. **Impact Assessment**
   - Data accessed with credential?
   - Systems modified or deleted?
   - Malware deployed?
   - Persistence mechanisms installed?
   - Backdoors created?

### Phase 3: Containment (1-24 hours)

1. **Credential Rotation**

   - Execute comprehensive credential rotation
   - Rotate database passwords
   - Regenerate API keys
   - Reset service account passwords
   - Update all dependent applications

2. **Access Audit**

   - Review IAM policies for least privilege
   - Audit service account permissions
   - Review API key scopes
   - Validate database user privileges
   - Implement role-based access controls

3. **Enhanced Monitoring**

   - Implement anomalous login detection
   - Add geolocation-based blocks
   - Enable CloudTrail for all API calls
   - Increase API key usage monitoring
   - Set up alerts for credential usage

4. **System Changes**
   - Update credentials in all applications
   - Redeploy with new secrets
   - Verify all services operational
   - Test credential functionality
   - Confirm no lingering access

### Phase 4: Eradication (4-72 hours)

1. **Backdoor Removal**

   - Search for persistence mechanisms
   - Remove unauthorized IAM roles
   - Delete suspicious security groups
   - Remove compromised keys from instances
   - Terminate unauthorized instances

2. **System Hardening**

   - Enable credential monitoring
   - Implement credential expiration
   - Require MFA for sensitive operations
   - Enable IP whitelisting where possible
   - Implement VPC endpoint access

3. **Threat Hunting**
   - Search for indicators of compromise
   - Review instance metadata service access
   - Check for privilege escalation attempts
   - Look for data exfiltration
   - Search for lateral movement

## Containment Procedures

### AWS IAM Credentials

```bash
# 1. Immediate deactivation
- Deactivate access key (Deactivate, don't delete)
- Document key details and creation date
- Note all associated roles and policies

# 2. Session termination
- Check for active STS tokens
- Check EC2 instance metadata access
- Revoke any temporary credentials
- Disable role assumption if possible

# 3. Monitoring setup
- Enable CloudTrail for account
- Set up alerts for key usage
- Monitor assume role activities
- Track API calls from account
```

### Database Credentials

```bash
# 1. Password change
- Change password immediately
- Update in Secrets Manager
- Rotate in all applications
- Verify access still working

# 2. Session termination
- Kill existing connections
- Revoke user if possible
- Reset connection limits
- Enable audit logging

# 3. Access review
- Check query history
- Review access logs
- Look for unauthorized access
- Validate backup integrity
```

### API Keys

```bash
# 1. Revocation
- Revoke leaked key immediately
- Generate new key
- Update in applications
- Verify services still working

# 2. Usage monitoring
- Check API logs for key usage
- Look for unusual patterns
- Monitor rate limiting
- Review error logs

# 3. Rotation
- Set expiration dates
- Implement rotation schedules
- Use short-lived tokens
- Enable audit logging
```

## Eradication Steps

### Credential Cleanup

- [ ] Delete old/unused credentials
- [ ] Remove expired credentials
- [ ] Deactivate backup credentials
- [ ] Clean up legacy accounts
- [ ] Validate all deletions logged

### Account Hardening

- [ ] Enable MFA on all accounts
- [ ] Reduce credential lifetime
- [ ] Implement credential rotation
- [ ] Enable anomaly detection
- [ ] Implement adaptive auth

### System Updates

- [ ] Patch all affected systems
- [ ] Update security groups
- [ ] Review VPC configuration
- [ ] Validate network policies
- [ ] Confirm monitoring active

## Recovery Procedures

### User Communication

1. Notify user of compromise
2. Explain what happened
3. Provide new credentials
4. Guide on updating applications
5. Recommend password reset across services

### System Restoration

1. Verify all services operational
2. Confirm new credentials working
3. Monitor for issues
4. Validate backups
5. Test failover procedures

### Verification

1. Confirm old credential no longer works
2. Verify no unauthorized access
3. Validate monitoring active
4. Test response procedures
5. Document lessons learned

## Post-Incident Review

### Investigation Findings

- How was credential exposed?
- Why was it in an insecure location?
- How long was it exposed?
- Was it actively used?
- What was accessed?

### Control Gaps

- Missing detection controls
- Inadequate monitoring
- Insufficient access restrictions
- Weak credential storage
- Lack of rotation procedures

### Improvements

- Implement secret scanning
- Automated credential rotation
- Enhanced monitoring/alerting
- Access restriction policies
- Detection mechanisms

## Preventive Controls

### Secret Management

- Use AWS Secrets Manager
- Rotate credentials automatically
- Encrypt secrets at rest
- Enable audit logging
- Implement least privilege

### Detection

- GitHub Secret Scanning
- Third-party credential monitoring
- CloudTrail analysis
- Anomalous access detection
- Geographic-based alerts

### User Training

- Secure credential handling
- Not hardcoding credentials
- Secret rotation procedures
- Incident reporting
- Phishing awareness

## Contacts & Escalation

### Immediate Contacts

- **Security Lead**: [On-call rotation]
- **Credential Owner**: [Notify immediately]
- **Engineering Lead**: [For deployment coordination]
- **CISO**: [For high-severity credentials]

### Response Team

```
1. Security Engineer (verification)
2. DevOps/Platform (credential rotation)
3. Engineering (application updates)
4. Leadership (notification)
```

## Tools & Resources

### Detection Tools

- GitHub Secret Scanning
- GitGuardian
- AWS Secrets Manager
- Third-party credential monitoring

### Response Runbooks

- rotate-all-credentials.json
- isolate-compromised-agent.json
- collect-evidence.json

### Forensics Tools

- capture-logs.py
- timeline-builder.py
- snapshot-resources.py

## Metrics & KPIs

Track during incident:

- **Detection to Awareness**: < 1 hour
- **Awareness to Revocation**: < 30 minutes
- **Revocation to Rotation**: < 2 hours
- **Root Cause Analysis**: < 4 hours
- **Full Remediation**: < 24 hours

## Related Playbooks

- [Data Breach Response](./data-breach-response.md)
- [Unauthorized Access Response](./unauthorized-access.md)
- [Malware Detection Response](./malware-detection.md)

## Revision History

- v1.0 - Initial creation (2024-11-17)
