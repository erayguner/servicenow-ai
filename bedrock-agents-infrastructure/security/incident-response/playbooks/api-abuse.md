# API Abuse Response Playbook

## Overview

Response procedures for API abuse and misuse of Bedrock agents infrastructure
APIs.

## Detection Criteria

- Excessive API calls from single source
- Quota/rate limit violations
- API calls outside business hours
- Unusual API usage patterns
- Spike in API errors
- Failed authentication attempts
- Brute force attacks on endpoints
- SQL injection/XSS attempts in API
- Unusual geolocation for API access
- Credential stuffing attempts
- Unexpected endpoint access
- Large data exfiltration via API

## Severity Classification

### Critical (P1)

- Data exfiltration in progress
- Active system compromise via API
- Multiple API keys compromised
- Service completely unavailable
- Sustained attack with high impact

### High (P2)

- Significant degradation of service
- Unauthorized data access via API
- Malicious payload injection
- Multiple source IPs attacking
- Credential theft attempts

### Medium (P3)

- Moderate API rate violations
- Single source abuse
- Limited data access
- Automated scanning/enumeration
- No production impact

### Low (P4)

- Minor rate limit violations
- Test/non-malicious activity
- Single failed request
- Legitimate user error
- No security impact

## Response Steps

### Phase 1: Detection & Assessment (0-5 minutes)

1. **Alert Verification**

   - Confirm API abuse detection
   - Identify affected endpoint
   - Determine attack source
   - Review request patterns
   - Check for legitimate explanations

2. **Impact Assessment**

   - Monitor API availability
   - Check error rates
   - Review affected services
   - Analyze customer impact
   - Estimate blast radius

3. **Threat Characterization**

   - Identify attack type (DDoS, enumeration, exploitation)
   - Determine target endpoints
   - Analyze request payload
   - Check for malicious patterns
   - Estimate attacker sophistication

4. **Initial Mitigation**
   - Block abusive IP address at WAF
   - Implement rate limiting
   - Enable API throttling
   - Trigger auto-scaling if needed
   - Increase monitoring

### Phase 2: Investigation (5-30 minutes)

1. **API Usage Analysis**

   - Query API Gateway logs
   - Analyze CloudWatch metrics
   - Review authentication logs
   - Check API keys used
   - Determine API endpoints targeted

2. **Attack Pattern Analysis**

   - Identify request patterns
   - Analyze payload content
   - Check for malicious payloads
   - Review HTTP headers
   - Identify attack signatures

3. **Source Identification**

   - Trace source IP address
   - Check geolocation
   - Identify ASN/ISP
   - Check reputation
   - Look for proxy/VPN usage

4. **Data Breach Assessment**
   - Determine data accessed
   - Identify leaked data
   - Scope breach impact
   - Run `timeline-builder.py`
   - Execute `capture-logs.py`

### Phase 3: Containment (5-60 minutes)

1. **API Protection**

   - Block offending IP addresses
   - Revoke API keys if compromised
   - Implement rate limiting
   - Enable request throttling
   - Activate WAF rules

2. **API Key Management**

   - Identify potentially exposed keys
   - Revoke compromised keys
   - Generate new keys
   - Distribute new keys
   - Rotate application credentials

3. **Access Control**

   - Restrict API key permissions
   - Enforce API authentication
   - Require API request signing
   - Implement IP whitelisting
   - Enable request validation

4. **Monitoring Enhancement**
   - Enable API logging
   - Increase monitoring sensitivity
   - Implement anomaly detection
   - Set up real-time alerts
   - Monitor for exploitation attempts

## Containment Procedures

### API Gateway Protection

```bash
# 1. Rate Limiting
- Implement per-IP rate limits
- Set per-API-key limits
- Implement per-endpoint limits
- Use token bucket algorithm
- Gradually increase limits

# 2. Request Validation
- Validate request format
- Check payload size
- Validate authentication
- Verify API key permissions
- Check request signatures

# 3. WAF Rules
- Block known attack patterns
- Implement IP reputation blocking
- Enable bot protection
- Block suspicious User-Agents
- Implement geo-blocking if applicable
```

### Credential Management

```bash
# 1. API Key Rotation
- Revoke potentially compromised keys
- Generate new API keys
- Distribute new keys securely
- Update all applications
- Monitor old keys for usage

# 2. Access Control
- Restrict key permissions
- Enforce API scope limits
- Implement least privilege
- Monitor key usage
- Set expiration dates

# 3. Key Monitoring
- Monitor failed authentication
- Track key usage patterns
- Alert on unusual activity
- Monitor for key leaks
- Track API key distribution
```

### Traffic Filtering

```bash
# 1. IP Blocking
- Block known malicious IPs
- Implement rate-based blocking
- Block by geolocation if needed
- Create IP reputation lists
- Monitor blocked traffic

# 2. Request Filtering
- Block malicious payloads
- Filter SQL injection attempts
- Block XSS attempts
- Validate request headers
- Sanitize input

# 3. Behavioral Analysis
- Monitor request patterns
- Detect anomalies
- Track API key usage
- Monitor error rates
- Alert on suspicious activity
```

## Eradication Steps

### Abuse Prevention

- [ ] Implement API rate limiting
- [ ] Enforce request validation
- [ ] Enable API authentication
- [ ] Restrict key permissions
- [ ] Implement monitoring

### Vulnerability Patching

- [ ] Identify exploited vulnerabilities
- [ ] Apply security patches
- [ ] Update API handlers
- [ ] Review code for weaknesses
- [ ] Implement input validation

### Control Enhancement

- [ ] Improve API key management
- [ ] Implement usage monitoring
- [ ] Add anomaly detection
- [ ] Enable security logging
- [ ] Review and harden endpoints

## Recovery Procedures

### API Restoration

1. Gradually lift rate limits
2. Remove IP blocks (if false positives)
3. Monitor for attack resurgence
4. Maintain enhanced monitoring
5. Validate normal operation

### Service Validation

1. Confirm API availability
2. Verify endpoint functionality
3. Test all critical paths
4. Monitor performance metrics
5. Confirm customer access

### Post-Incident Verification

1. Review logs for indicators
2. Analyze for data exfiltration
3. Validate security controls
4. Test incident procedures
5. Document lessons learned

## Post-Incident Review

### Attack Analysis

- Attack type and method
- Duration of abuse
- API endpoints targeted
- Data accessed/exfiltrated
- Business impact

### Vulnerability Assessment

- Root cause of abuse
- Missing security controls
- Design flaws
- Implementation weaknesses
- Detection gaps

### Improvement Plan

- API rate limiting improvements
- Authentication enhancements
- Monitoring improvements
- Security control additions
- Vulnerability remediation

## Prevention Measures

### API Security

- Implement API authentication
- Enforce rate limiting
- Implement request validation
- Use API versioning
- Implement API key rotation

### Monitoring & Detection

- API Gateway logging
- CloudWatch metrics
- Real-time alerting
- Behavioral analysis
- Anomaly detection

### Access Control

- Implement least privilege
- Restrict API key permissions
- Enforce API quotas
- Implement IP whitelisting
- Geolocation restrictions

### User Education

- API security best practices
- API key handling
- Rate limit awareness
- Incident reporting
- API documentation

## Tools & Resources

### API Protection

- AWS API Gateway
- AWS WAF
- AWS API Gateway logging
- CloudWatch metrics
- VPC endpoint policies

### Monitoring

- CloudWatch Logs
- API Gateway metrics
- Access logs
- CloudTrail
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
- network-capture.py
- snapshot-resources.py

## Metrics & KPIs

Track during incident:

- **Detection to Blocking**: < 5 minutes
- **Blocking to Analysis**: < 15 minutes
- **Analysis to Remediation**: < 1 hour
- **Key Rotation Time**: < 30 minutes
- **False Positive Rate**: < 1%
- **Service Recovery Time**: < 30 minutes

## Decision Tree

```
API Abuse Detected?
├─ Verify Detection
│  ├─ Confirmed: Proceed
│  └─ False Positive: Monitor
├─ Severity
│  ├─ P1: Full activation
│  ├─ P2: Limited activation
│  └─ P3/P4: Standard response
├─ Attack Type
│  ├─ DDoS: Rate limiting, scaling
│  ├─ Enumeration: WAF, blocking
│  └─ Exploitation: Patch, validate
└─ Recovery
   ├─ Credentials: Rotate keys
   └─ System: Patch & validate
```

## Related Playbooks

- [DDoS Attack Response](./ddos-attack-response.md)
- [Unauthorized Access Response](./unauthorized-access.md)
- [Data Breach Response](./data-breach-response.md)

## Contacts & Escalation

### Response Team

- **API Owner**: [Engineering lead]
- **Security Lead**: [On-call rotation]
- **DevOps Engineer**: [On-call rotation]
- **CISO**: [For major incidents]

### Support Resources

- **AWS API Gateway Support**: [Enterprise support]
- **API Documentation**: [Internal wiki]
- **Security Team**: [Slack channel #incident-response]

## Revision History

- v1.0 - Initial creation (2024-11-17)
