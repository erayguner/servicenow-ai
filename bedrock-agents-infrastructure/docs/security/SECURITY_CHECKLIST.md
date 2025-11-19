# Security Checklist

## Table of Contents

1. [Pre-Deployment Checklist](#pre-deployment-checklist)
2. [Post-Deployment Validation](#post-deployment-validation)
3. [Monthly Security Review](#monthly-security-review)
4. [Quarterly Audit Items](#quarterly-audit-items)
5. [Annual Certification Tasks](#annual-certification-tasks)
6. [Emergency Procedures](#emergency-procedures)
7. [Compliance Checklists](#compliance-checklists)

## Pre-Deployment Checklist

### Infrastructure as Code Review

- [ ] Terraform files reviewed by security team
- [ ] No hardcoded secrets or API keys
- [ ] All resources have encryption enabled
- [ ] Network ACLs and security groups properly configured
- [ ] IAM roles follow least privilege principle
- [ ] S3 buckets have public access blocked
- [ ] KMS key encryption enabled for sensitive data
- [ ] Backup and disaster recovery configured
- [ ] Logging enabled on all services
- [ ] VPC flow logs enabled

### Network Security

- [ ] VPC configured with public/private subnets
- [ ] NAT gateway in place for private subnet internet access
- [ ] Security groups whitelist only necessary ports
  - [ ] HTTPS (443) for external communication
  - [ ] SSH (22) restricted to bastion/VPN
  - [ ] Database ports restricted to app subnets
- [ ] Network ACLs configured
- [ ] VPC endpoints for AWS services configured
- [ ] WAF rules configured on ALB
- [ ] DDoS protection enabled (Shield Standard)

### Authentication & Authorization

- [ ] IAM roles created for all services
- [ ] Service roles have minimal required permissions
- [ ] Permission boundaries defined
- [ ] Cross-account trust relationships reviewed
- [ ] Root account not used for deployments
- [ ] MFA enforced for human users
- [ ] Service control policies enabled
- [ ] API keys rotated (if any created)
- [ ] Assume role trust relationships audited

### Data Protection

- [ ] Encryption at rest enabled on all databases
- [ ] Encryption at rest enabled on all storage
- [ ] TLS 1.3 configured on load balancers
- [ ] Certificates valid and from trusted CA
- [ ] KMS keys created and key policies configured
- [ ] Database passwords stored in Secrets Manager
- [ ] API keys stored in Secrets Manager
- [ ] SSL/TLS configuration hardened
- [ ] Certificate renewal automated

### Application Security

- [ ] Code review completed by security team
- [ ] Dependency vulnerability scan passed
- [ ] No hardcoded credentials in code
- [ ] Input validation implemented
- [ ] Output encoding implemented
- [ ] CORS configured for specific origins only
- [ ] CSRF protection implemented
- [ ] SQL injection protection verified
- [ ] XSS protection implemented
- [ ] Security headers configured

### Logging & Monitoring

- [ ] CloudTrail enabled and logs to S3
- [ ] CloudWatch log groups created
- [ ] Log retention policies configured
- [ ] CloudWatch alarms configured
- [ ] GuardDuty enabled
- [ ] Security Hub enabled
- [ ] VPC Flow Logs enabled
- [ ] RDS query logs enabled
- [ ] WAF logging enabled
- [ ] Alerts configured for critical events

### Compliance & Policy

- [ ] Security policies documented
- [ ] Procedures documented and reviewed
- [ ] Change management process followed
- [ ] Incident response plan reviewed
- [ ] Disaster recovery plan tested
- [ ] Business continuity plan reviewed
- [ ] Data classification policy applied
- [ ] Access review procedures documented
- [ ] Training requirements identified
- [ ] Compliance assessment completed

## Post-Deployment Validation

### Day 1: Immediate Validation

- [ ] Services are running and healthy
- [ ] All health checks passing
- [ ] SSL/TLS certificates valid
- [ ] Database connections working
- [ ] Logging functioning
- [ ] Monitoring dashboards displaying data
- [ ] Alarms properly firing for test events
- [ ] No unauthorized API calls
- [ ] VPC Flow Logs showing normal traffic
- [ ] CloudTrail logging all actions

### Week 1: Functional Validation

- [ ] All application features working
- [ ] Database backups successful
- [ ] Backup restoration tested
- [ ] Failover tested (if applicable)
- [ ] Disaster recovery validated
- [ ] Performance baseline established
- [ ] Error handling working correctly
- [ ] Rate limiting functional
- [ ] API authentication working
- [ ] Authorization enforcement validated

### Week 2: Security Validation

- [ ] Penetration test completed (if required)
- [ ] Vulnerability scan passed
- [ ] Security configuration audit passed
- [ ] Access controls validated
- [ ] Encryption working correctly
- [ ] Audit logs complete and searchable
- [ ] No security findings from automated scans
- [ ] Security group rules validated
- [ ] IAM policies validated
- [ ] Certificate chain validated

### Week 3: Compliance Validation

- [ ] Compliance assessment completed
- [ ] Security requirements met
- [ ] Audit-ready documentation prepared
- [ ] Security baseline documented
- [ ] Risk assessment completed
- [ ] Incident response plan activated (test)
- [ ] Communication plan tested
- [ ] Customer notification ready
- [ ] Regulatory requirements met
- [ ] Evidence collection procedures working

## Monthly Security Review

### Week 1: Access Review

- [ ] Review all IAM users and roles
- [ ] Verify MFA enabled for all users
- [ ] Check for unused access keys
- [ ] Review privilege levels
- [ ] Validate least privilege implementation
- [ ] Remove unnecessary permissions
- [ ] Update documentation
- [ ] Check for compliance violations
- [ ] Verify service role permissions
- [ ] Review cross-account access

### Week 2: Alert Review

- [ ] Review all security alerts from past month
- [ ] Investigate unresolved findings
- [ ] Close false positives with documentation
- [ ] Adjust alert thresholds if needed
- [ ] Review GuardDuty findings
- [ ] Review Security Hub findings
- [ ] Update runbooks based on findings
- [ ] Share lessons learned
- [ ] Train team on new patterns
- [ ] Document trends

### Week 3: Configuration Review

- [ ] Review S3 bucket configurations
- [ ] Review RDS database settings
- [ ] Review security group rules
- [ ] Review KMS key permissions
- [ ] Check certificate expiration dates
- [ ] Review backup configurations
- [ ] Verify encryption settings
- [ ] Check logging configurations
- [ ] Review firewall rules
- [ ] Validate disaster recovery setup

### Week 4: Compliance Review

- [ ] Verify CloudTrail logging active
- [ ] Check log retention policies
- [ ] Review audit logs for completeness
- [ ] Verify evidence is preserved
- [ ] Check for new compliance requirements
- [ ] Review customer commitments
- [ ] Update compliance matrix
- [ ] Prepare compliance report
- [ ] Document any deviations
- [ ] Plan remediation if needed

## Quarterly Audit Items

### Q1: Comprehensive Access Audit

- [ ] Complete access review (all users and roles)
- [ ] Identify unused access
- [ ] Create remediation plan
- [ ] Execute access cleanup
- [ ] Update role documentation
- [ ] Validate least privilege
- [ ] Review organizational structure changes
- [ ] Update access control matrix
- [ ] Manager sign-off on access
- [ ] Document final state

### Q1: Policy Review

- [ ] Review security policies for updates
- [ ] Update procedures based on lessons learned
- [ ] Verify policies reflect current practices
- [ ] Employee training on policies
- [ ] Review policy exceptions
- [ ] Update exception tracking
- [ ] Assess policy effectiveness
- [ ] Identify improvement opportunities
- [ ] Plan policy updates for next quarter
- [ ] Get management approval

### Q2: Vulnerability Assessment

- [ ] Conduct code vulnerability scan
- [ ] Scan dependencies for CVEs
- [ ] Perform SAST on source code
- [ ] Perform DAST on running systems
- [ ] Check infrastructure for misconfigurations
- [ ] Assess cloud security posture
- [ ] Review compliance scanning results
- [ ] Prioritize findings by severity
- [ ] Create remediation plan
- [ ] Track remediation progress

### Q2: Backup & Recovery Testing

- [ ] Test RDS backup restoration
- [ ] Test S3 data recovery
- [ ] Test DynamoDB point-in-time recovery
- [ ] Test application deployment from backup
- [ ] Verify backup integrity
- [ ] Test failover to DR environment
- [ ] Measure RTO and RPO
- [ ] Document results
- [ ] Identify improvement opportunities
- [ ] Update DR procedures if needed

### Q3: Incident Response Drill

- [ ] Conduct tabletop exercise
- [ ] Test incident response procedures
- [ ] Verify contact information is current
- [ ] Test communication channels
- [ ] Review runbooks for accuracy
- [ ] Identify gaps in procedures
- [ ] Train team on new procedures
- [ ] Document lessons learned
- [ ] Update incident response plan
- [ ] Schedule next drill

### Q3: Threat Assessment Update

- [ ] Review threat landscape changes
- [ ] Assess new threats relevant to organization
- [ ] Update threat model
- [ ] Identify new controls needed
- [ ] Prioritize control implementation
- [ ] Assess existing mitigations effectiveness
- [ ] Identify residual risks
- [ ] Plan risk reduction activities
- [ ] Get management approval
- [ ] Communicate to teams

### Q4: Annual Planning

- [ ] Review year in security metrics
- [ ] Identify trends and patterns
- [ ] Assess security posture improvement
- [ ] Plan budget for next year
- [ ] Identify hiring needs
- [ ] Plan training and certifications
- [ ] Identify technology investments
- [ ] Develop security roadmap
- [ ] Present to management
- [ ] Get board approval

### Q4: Compliance Assessment

- [ ] Verify compliance with SOC 2 requirements
- [ ] Verify compliance with ISO 27001 controls
- [ ] Verify compliance with regulatory requirements
- [ ] Review audit findings and remediation
- [ ] Update compliance documentation
- [ ] Prepare evidence for audit
- [ ] Schedule external audits
- [ ] Plan certification renewals
- [ ] Budget for audit costs
- [ ] Document compliance status

## Annual Certification Tasks

### Security Certification Preparation

- [ ] Initiate SOC 2 Type II audit (if scheduled)
- [ ] Prepare ISO 27001 certification (if scheduled)
- [ ] Compile evidence for audit
- [ ] Schedule auditor on-site visits
- [ ] Assign audit liaisons
- [ ] Prepare facility for audit
- [ ] Brief team on audit process
- [ ] Create audit response procedures
- [ ] Prepare executive summary
- [ ] Schedule audit kick-off meeting

### Annual Security Assessment

- [ ] Comprehensive security assessment performed
- [ ] All 114 ISO controls evaluated
- [ ] Design effectiveness verified
- [ ] Operating effectiveness tested
- [ ] Risk assessment conducted
- [ ] Key findings documented
- [ ] Management responses prepared
- [ ] Remediation plans created
- [ ] Timeline for corrections established
- [ ] Executive summary prepared

### Annual Compliance Review

- [ ] Compliance review meeting with executives
- [ ] Compliance status presented
- [ ] Certifications displayed
- [ ] Audit findings discussed
- [ ] Remediation progress reviewed
- [ ] Budget approved for improvements
- [ ] Risks acknowledged and accepted
- [ ] Policies approved
- [ ] Procedures approved
- [ ] Goals for next year established

### Annual Training & Certification

- [ ] Security training conducted for all staff
- [ ] Role-specific training provided
- [ ] Awareness training on new threats
- [ ] Incident response training
- [ ] Secure coding training (developers)
- [ ] Security certifications planned
- [ ] Professional development budget allocated
- [ ] Training effectiveness measured
- [ ] Training records maintained
- [ ] Competency verified

### Annual Vendor Assessment

- [ ] Assess cloud provider security posture
- [ ] Review service level agreements
- [ ] Verify security control implementations
- [ ] Review audit reports
- [ ] Assess new services for security
- [ ] Update vendor risk matrix
- [ ] Verify insurance coverage
- [ ] Review contracts for updates
- [ ] Plan vendor security reviews
- [ ] Document risk acceptance

## Emergency Procedures

### Security Incident Response

- [ ] Incident declared and ID assigned
- [ ] Response team assembled
- [ ] Incident commander appointed
- [ ] Initial notification to management
- [ ] Investigation initiated
- [ ] Evidence preservation started
- [ ] Forensics procedures begun
- [ ] Containment measures implemented
- [ ] Communications plan activated
- [ ] See [INCIDENT_RESPONSE.md](INCIDENT_RESPONSE.md) for full procedures

### Data Breach Response

- [ ] Breach confirmed and scope determined
- [ ] Legal counsel notified
- [ ] Affected individuals identified
- [ ] Evidence preserved (6 months minimum)
- [ ] Regulatory notifications prepared
- [ ] Customer notifications drafted
- [ ] Public statement prepared (if needed)
- [ ] Investigation completed
- [ ] Root cause documented
- [ ] Remediation plan created

### Ransomware Response

- [ ] Systems isolated immediately
- [ ] Backups preserved offline
- [ ] Ransom note analyzed
- [ ] Attacker communication reviewed
- [ ] Law enforcement contacted (FBI)
- [ ] Incident response team engaged
- [ ] Evidence preserved for forensics
- [ ] Systems restored from clean backups
- [ ] All passwords and keys rotated
- [ ] Enhanced monitoring enabled

### Credential Compromise

- [ ] Compromised credential revoked immediately
- [ ] Access logs reviewed for unauthorized use
- [ ] Timeline of misuse determined
- [ ] Affected resources identified
- [ ] New credentials issued
- [ ] Users notified of compromise
- [ ] Password reset enforced
- [ ] MFA re-enrolled
- [ ] System access verified secure
- [ ] Monitoring for related activity enabled

## Compliance Checklists

### SOC 2 Compliance Checklist

- [ ] CC6.1 - Logical access controls implemented
- [ ] CC6.2 - Prior to issuing system credentials
- [ ] CC7.2 - System monitoring configured
- [ ] CC8.1 - Vulnerability assessments performed
- [ ] CC9.2 - Change management procedures followed
- [ ] CC9.1 - System development standards defined
- [ ] C1.2 - Availability monitoring enabled
- [ ] A1.1 - Service availability objectives met
- [ ] A1.2 - Service availability monitoring
- [ ] P2.2 - Personal information protected

### ISO 27001 Checklist

#### A.5 Organizational Controls

- [ ] A.5.1.1 - Policies established
- [ ] A.5.1.2 - Information security roles
- [ ] A.5.2.1 - Segregation of duties
- [ ] A.5.2.2 - Access management
- [ ] A.5.2.3 - Contractor access control
- [ ] A.5.2.4 - Removal of access rights

#### A.6 People Controls

- [ ] A.6.1.1 - Screening procedures
- [ ] A.6.2.1 - Security training
- [ ] A.6.2.2 - Disciplinary process
- [ ] A.6.2.3 - Termination procedures
- [ ] A.6.3.1 - Confidentiality agreements

#### A.7 Operational Controls

- [ ] A.7.1.1 - Responsibility assignment
- [ ] A.7.1.2 - Incident reporting
- [ ] A.7.2.1 - Change management
- [ ] A.7.2.2 - Capacity management
- [ ] A.7.2.3 - Separation of test/prod

#### A.8 Technical Controls

- [ ] A.8.1.1 - User endpoint devices
- [ ] A.8.1.3 - Mobile device management
- [ ] A.8.1.4 - Asset disposal
- [ ] A.8.2.1 - User access management
- [ ] A.8.2.2 - Privileged access rights
- [ ] A.8.2.3 - User password management
- [ ] A.8.2.4 - Review of user access rights
- [ ] A.8.3.1 - Password quality
- [ ] A.8.3.2 - Event logging

### GDPR Compliance Checklist

- [ ] Lawful basis for processing identified
- [ ] Privacy notice prepared
- [ ] Data processing agreements in place
- [ ] Data subject rights procedures implemented
- [ ] Consent management (if applicable)
- [ ] Data retention schedule defined
- [ ] Data deletion procedures implemented
- [ ] Privacy by design practices followed
- [ ] Data protection impact assessment completed
- [ ] Breach notification procedures ready
- [ ] Data protection officer assigned (if required)
- [ ] International transfer mechanisms established
- [ ] Sub-processor assessments completed
- [ ] Privacy training conducted

### HIPAA Compliance Checklist

- [ ] Security Rule risk analysis
- [ ] Risk management plan implemented
- [ ] Workforce security procedures
- [ ] Information access management
- [ ] Security awareness training
- [ ] Security incident procedures
- [ ] Contingency planning and testing
- [ ] Business associate agreements
- [ ] Administrative safeguards
- [ ] Physical safeguards
- [ ] Technical safeguards
- [ ] Audit controls and logging
- [ ] Breach notification plan
- [ ] Sanctions policies

---

**Document Version**: 1.0
**Last Updated**: November 2024
**Next Review**: May 2025
