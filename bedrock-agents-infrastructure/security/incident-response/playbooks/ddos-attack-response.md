# DDoS Attack Response Playbook

## Overview
Response procedures for Distributed Denial of Service (DDoS) attacks targeting Bedrock agents infrastructure.

## Detection Criteria
- CloudWatch alarms for elevated traffic
- AWS Shield Standard alerts
- AWS Shield Advanced DDoS detected notification
- Abnormal spike in API requests
- Sudden increase in specific endpoints
- High error rates on load balancers
- Increased 4xx/5xx response codes
- Regional traffic concentration
- Bot traffic detected
- Connection rate limits exceeded

## Severity Classification

### Critical (P1)
- >50% traffic increase
- Services completely unavailable
- Sustained attack >1 hour
- Multiple attack vectors
- Active exploitation of vulnerabilities

### High (P2)
- 20-50% traffic increase
- Degraded service performance
- Regional unavailability
- Sustained attack 30 min - 1 hour
- API response times >5 seconds

### Medium (P3)
- 10-20% traffic increase
- Minor performance degradation
- Specific endpoints affected
- Attack duration <30 minutes
- Response times 1-5 seconds

### Low (P4)
- <10% traffic increase
- No user-visible impact
- Localized effect
- Easily mitigable
- No performance impact

## Response Steps

### Phase 1: Detection & Assessment (0-5 minutes)

1. **Verify Attack**
   - Confirm CloudWatch alarms triggered
   - Check AWS Shield Advanced (if enabled)
   - Validate traffic patterns
   - Check service health status
   - Review recent deployments

2. **Initial Triage**
   - Determine attack type (volumetric, protocol, application)
   - Identify targeted endpoints
   - Check geographic source distribution
   - Review legitimate vs. malicious traffic
   - Estimate attack magnitude

3. **Activate Response**
   - Notify on-call incident commander
   - Activate incident channel
   - Page DDoS response team
   - Start incident timer
   - Begin status updates

4. **Initial Mitigation**
   - Enable AWS Shield advanced protection
   - Activate CloudFront distribution
   - Enable WAF if available
   - Increase auto-scaling limits
   - Pre-emptively scale resources

### Phase 2: Mitigation (5-30 minutes)

1. **Traffic Filtering**
   - Enable AWS WAF rules
   - Block known malicious IP ranges
   - Implement rate limiting
   - Enable geo-blocking if applicable
   - Deploy bot management rules

2. **Auto-Scaling**
   - Increase ALB/NLB capacity
   - Scale compute resources
   - Expand database connections
   - Prepare warm standby capacity
   - Monitor scaling metrics

3. **Service Protection**
   - Enable DDoS protection on CloudFront
   - Activate Route 53 health checks
   - Increase API Gateway throttling
   - Enable connection-level protection
   - Monitor service availability

4. **Infrastructure Optimization**
   - Route traffic through CloudFront
   - Use edge locations for distribution
   - Activate shield advanced
   - Implement origin shields
   - Optimize caching

### Phase 3: Attack Analysis (Ongoing)

1. **Threat Intelligence**
   - Analyze traffic source IPs
   - Identify attack patterns
   - Detect attack vectors
   - Look for signatures
   - Compare with known attacks

2. **Traffic Forensics**
   - Capture traffic samples
   - Analyze packet patterns
   - Review request headers
   - Analyze payload content
   - Identify bot signatures

3. **Impact Assessment**
   - Monitor service metrics
   - Track user complaints
   - Measure performance degradation
   - Document affected services
   - Estimate business impact

## Containment Procedures

### Network-Level Protection
```bash
# 1. BGP Blackhole Routing (if available)
- Sink malicious traffic at ISP level
- Requires ISP coordination
- Effective for volumetric attacks
- Blocks all traffic from source

# 2. Rate Limiting
- Limit requests per IP
- Implement exponential backoff
- Use token bucket algorithm
- Differentiate bot vs. legitimate traffic
- Gradually ease restrictions

# 3. Geo-Blocking
- Block traffic from unexpected regions
- Whitelist known customer locations
- Review logs for legitimate access
- Implement conditional blocking
- Monitor false positives
```

### Application-Level Protection
```bash
# 1. Request Validation
- Verify HTTP headers
- Validate content-type
- Check User-Agent patterns
- Implement CAPTCHA challenges
- Verify session tokens

# 2. Rate Limiting
- Implement per-IP limits
- Per-user rate limits
- Per-endpoint rate limits
- Progressive degradation
- Clear user communication

# 3. Traffic Shaping
- Prioritize legitimate traffic
- Queue requests intelligently
- Implement fair queuing
- Manage connection resources
- Monitor queue depth
```

### WAF Rules Implementation
```bash
# AWS WAF Configuration
- AWS IP reputation list
- Geo-blocking rules
- Rate-based rules
- Bot control rules
- Custom rate limiting
- Whitelist trusted IPs
```

## Eradication Steps

### Attack Persistence
- [ ] Monitor for attack resurgence
- [ ] Track attack pattern changes
- [ ] Watch for new attack vectors
- [ ] Monitor threat intelligence feeds
- [ ] Maintain elevated protection 24-48 hours

### Vulnerability Patching
- [ ] Identify vulnerabilities exploited
- [ ] Deploy security patches
- [ ] Update WAF signatures
- [ ] Review code for weaknesses
- [ ] Implement compensating controls

### Traffic Filtering Refinement
- [ ] Analyze logs for false positives
- [ ] Refine rate limiting thresholds
- [ ] Optimize WAF rules
- [ ] Update IP blacklists
- [ ] Validate protection effectiveness

## Recovery Procedures

### Gradual De-escalation
1. Monitor for attack continuation
2. Slowly reduce DDoS protections
3. Watch for resurgence indicators
4. Maintain enhanced monitoring
5. Keep auto-scaling at elevated capacity

### Service Normalization
1. Return to standard configuration
2. Disable emergency protections
3. Reduce auto-scaled resources
4. Validate normal operation
5. Confirm performance metrics

### Post-Incident Verification
1. Confirm all services operational
2. Validate customer experience
3. Review business metrics
4. Analyze logs for indicators
5. Plan improvements

## Post-Incident Review

### Forensic Analysis
- Root cause of vulnerability
- Attack duration and timeline
- Peak traffic levels reached
- Services most affected
- Customer impact assessment

### Detection Improvements
- Tuning of CloudWatch alarms
- Threshold optimization
- Alerting mechanism review
- Time to detection analysis
- Early warning implementation

### Response Improvements
- Response team effectiveness
- Tool adequacy assessment
- Process gaps identified
- Training needs
- Documentation updates

## Prevention Measures

### Infrastructure Hardening
- Deploy AWS Shield Standard/Advanced
- Enable WAF on all public endpoints
- Implement CloudFront caching
- Use CDN for static content
- Optimize origin shields

### Monitoring & Alerting
- CloudWatch alarms for traffic spikes
- AWS Shield Advanced notifications
- VPC Flow Logs analysis
- Real-time threat detection
- Automated alert escalation

### Capacity Planning
- Baseline traffic analysis
- Peak traffic modeling
- Auto-scaling policies
- Resource provisioning
- Cost optimization

### Testing & Drills
- Regular incident response drills
- DDoS simulation exercises
- WAF rule testing
- Failover procedures
- Communication drills

## Tools & Resources

### Detection & Protection
- AWS Shield (Standard/Advanced)
- AWS WAF (Web Application Firewall)
- CloudFront Distribution
- Route 53 Health Checks
- ElasticLoadBalancing

### Monitoring
- CloudWatch Metrics
- VPC Flow Logs
- CloudTrail
- WAF Logging
- ALB/NLB Access Logs

### Response Runbooks
- isolate-compromised-agent.json
- enable-forensics-mode.json
- collect-evidence.json
- notify-stakeholders.json

### Forensics Tools
- capture-logs.py
- network-capture.py
- timeline-builder.py

## Metrics & KPIs

Track during incident:
- **Detection to Alert**: < 1 minute
- **Alert to Response**: < 5 minutes
- **Response to Mitigation**: < 15 minutes
- **Time to Service Recovery**: < 30 minutes
- **Peak Traffic Handled**: [Baseline + X%]
- **False Positive Rate**: < 0.1%

## Decision Tree

```
DDoS Detected?
├─ Confirm Alert?
│  ├─ No: Monitor and log
│  └─ Yes: Activate Response
├─ Attack Type?
│  ├─ Volumetric: Increase capacity, use CDN
│  ├─ Protocol: Enable WAF, rate limiting
│  └─ Application: Bot control, rate limiting
├─ Severity?
│  ├─ P1: Full escalation
│  ├─ P2: Limited escalation
│  └─ P3: Standard response
└─ Recovery?
   ├─ Monitored: Gradual de-escalation
   └─ Still Active: Maintain protections
```

## Related Playbooks
- [API Abuse Response](./api-abuse.md)
- [Unauthorized Access Response](./unauthorized-access.md)

## Contacts & Escalation

### Response Team
- **Incident Commander**: [On-call rotation]
- **Network Engineer**: [On-call rotation]
- **Cloud Security**: [On-call rotation]
- **CISO**: [For major incidents]

### External Contacts
- **AWS Support**: [Enterprise support contact]
- **ISP**: [DDoS mitigation coordination]

## Revision History
- v1.0 - Initial creation (2024-11-17)
