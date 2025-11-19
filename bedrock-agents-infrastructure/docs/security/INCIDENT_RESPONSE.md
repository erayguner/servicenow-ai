# Incident Response Plan

## Table of Contents

1. [Incident Response Framework](#incident-response-framework)
2. [Incident Classification](#incident-classification)
3. [Response Procedures](#response-procedures)
4. [Escalation Matrix](#escalation-matrix)
5. [Forensics Procedures](#forensics-procedures)
6. [Recovery Procedures](#recovery-procedures)
7. [Post-Incident Review](#post-incident-review)
8. [Communication Plans](#communication-plans)
9. [Contact Information](#contact-information)
10. [Testing and Drills](#testing-and-drills)

## Incident Response Framework

### Incident Response Team Structure

```
┌────────────────────────────────────┐
│   Incident Commander               │
│   - Overall coordination           │
│   - Decision authority             │
│   - Stakeholder communication      │
│   - Timeline management            │
└────────────────────────────────────┘
        │
┌───────┼──────────┬─────────────┐
│       │          │             │
▼       ▼          ▼             ▼
Tech   Security   Operations   Communications
Lead   Lead       Lead         Lead
│       │          │             │
├─ Logs ├─ Breach  ├─ Recovery   └─ Customer
├─ Metrics
├─ Traces
      │  Analysis │  - RTO      notifications
      │  - Eradication     └─ Internal
      │  - IAM            comms
      │    revocation
```

### Response Phases

```
Timeline:

DETECTION (0-15 min)
  ├─ Alert received
  ├─ Initial triage
  └─ Incident declared

ANALYSIS (15 min - 2 hours)
  ├─ Scope determination
  ├─ Severity assessment
  ├─ Root cause analysis
  └─ Evidence preservation

CONTAINMENT (2-8 hours)
  ├─ Isolate affected systems
  ├─ Stop ongoing attack
  ├─ Prevent further damage
  └─ Collect forensic evidence

ERADICATION (8-24 hours)
  ├─ Remove attacker access
  ├─ Patch vulnerabilities
  ├─ Update security controls
  └─ Verify all backdoors removed

RECOVERY (24-72 hours)
  ├─ Restore from clean backups
  ├─ Rebuild affected systems
  ├─ Validate functionality
  └─ Monitor for recurrence

POST-INCIDENT (days to weeks)
  ├─ Root cause analysis
  ├─ Control improvements
  ├─ Stakeholder briefing
  └─ Update procedures
```

## Incident Classification

### Severity Levels

#### Tier 1: CRITICAL
**Criteria:**
- Active security breach in progress
- Confirmed data exfiltration
- Complete service unavailability
- Major infrastructure compromise
- Regulatory reporting required (HIPAA, GDPR)

**Response Time:**
- Incident declared within 5 minutes
- First mitigation within 15 minutes
- Full incident team assembled within 30 minutes

**Example Scenarios:**
- Ransomware deployed on servers
- Database accessed by attacker
- AWS account credentials compromised
- Unauthorized data download detected

#### Tier 2: HIGH
**Criteria:**
- Confirmed unauthorized access
- Sensitive data accessed (not confirmed exfiltration)
- Service severely impacted (>50% functionality)
- Security control bypassed
- Potential compliance impact

**Response Time:**
- Incident declared within 15 minutes
- First response within 1 hour
- Incident team assembled within 2 hours

**Example Scenarios:**
- Weak API endpoint discovers sensitive data
- IAM user credentials leaked but not used
- DDoS attack degrading performance
- Failed login attempts spike

#### Tier 3: MEDIUM
**Criteria:**
- Suspected unauthorized access
- Security policy violation
- Moderate service impact (10-50%)
- Configuration anomaly detected
- Remediation needed within 24 hours

**Response Time:**
- Incident declared within 1 hour
- Investigation begins within 4 hours
- Resolution targeted for 24 hours

**Example Scenarios:**
- Unusual API usage pattern
- Failed MFA attempts
- Security group modification
- Elevated error rates

#### Tier 4: LOW
**Criteria:**
- Informational security event
- Minor policy violation
- No confirmed impact
- Best practice deviation
- Can be resolved in next business day

**Response Time:**
- Logged within business day
- Assessment within 5 business days
- Remediation within 30 days

**Example Scenarios:**
- Failed compliance check
- Outdated library detected
- Unused credentials identified
- Monitoring gap discovered

## Response Procedures

### Initial Detection and Triage

#### Step 1: Confirm Alert is Real (5 minutes)
```
Alert received (automated or manual):

1. Check alert source
   - GuardDuty finding validity
   - CloudWatch alarm accuracy
   - User report credibility
   - External source trustworthiness

2. Validate impact
   - Is service actually impacted?
   - Are users reporting issues?
   - Are metrics showing anomalies?
   - Is data access unexplained?

3. Determine severity
   - Could this affect production?
   - Could this involve data?
   - Is there clear unauthorized action?

4. Assemble initial team
   - On-call incident commander
   - On-call security lead
   - On-call ops lead
```

#### Step 2: Declare Incident (5-15 minutes)
```
Incident commander decides:

1. Is this an incident?
   - YES: Declare with Tier level
   - NO: Close alert, document reason

2. If incident:
   - Assign incident ID
   - Create incident channel
   - Notify all response team members
   - Begin incident timeline

3. Notify leadership
   - VP Security
   - VP Operations
   - VP Engineering
   - General Counsel (if data involved)
```

### Investigation Phase

#### Step 1: Preserve Evidence (15 minutes)
```
FIRST ACTION: Stop normal operations that might lose evidence

1. Preserve logs
   - Don't delete any logs
   - Capture CloudTrail logs for past 24 hours
   - Copy VPC Flow Logs
   - Export GuardDuty findings
   - Save application logs

2. Capture system state
   - Take memory dump (if running)
   - Snapshot affected systems
   - Export IAM credential report
   - Document network state
   - Screenshot dashboards

3. Secure evidence
   - Lock evidence directories
   - Ensure audit trail of access
   - No external access until reviewed
   - Calculate hash of evidence files
```

#### Step 2: Scope Determination (1-2 hours)
```
Answer: How bad is this?

Questions:
1. What systems are affected?
   - Compromised hosts
   - Accessed databases
   - Exfiltrated data
   - Modified configurations

2. What is the timeline?
   - When did attack start?
   - When was it detected?
   - What actions taken?
   - How long was access available?

3. Who is affected?
   - Internal staff
   - Customers
   - Partners
   - Data subjects (if PII)

4. What permissions did attacker have?
   - IAM role permissions
   - Data access capabilities
   - System modification abilities
   - Escalation potential

Activities:
- Review CloudTrail for suspicious activity
- Analyze VPC Flow Logs for unusual connections
- Check GuardDuty findings for corroboration
- Review access logs for affected resources
- Query CloudWatch metrics for anomalies
- Interview team members who noticed issues
```

#### Step 3: Root Cause Analysis (2-8 hours)
```
Answer: How did this happen?

Investigation areas:

1. How did attacker gain initial access?
   - Weak credentials
   - Phishing email
   - Vulnerable application
   - Supply chain compromise
   - Insider action

2. How did they escalate privileges?
   - Misconfigured IAM
   - Vulnerable service
   - Lateral movement
   - Default credentials
   - Session hijacking

3. Why wasn't it detected?
   - Monitoring gap
   - Alert threshold too high
   - Log not created
   - Alert not tuned properly
   - Response process slow

Activities:
- Deep-dive CloudTrail analysis
- Memory forensics if possible
- Network packet analysis
- Code review for vulnerabilities
- Configuration audit
- Access pattern analysis
```

### Containment Phase

#### Step 1: Immediate Actions (0-30 minutes)
```
Goal: Stop ongoing attack

1. Revoke compromised credentials
   - If AWS credentials: Deactivate access keys
   - If database password: Change password
   - If API key: Revoke key immediately
   - If SSH key: Remove from systems

2. Isolate affected systems
   - Remove from load balancer
   - Revoke network access (security groups)
   - Disconnect from internet (if needed)
   - Terminate malicious processes
   - Block attacker IP (WAF rule)

3. Enable monitoring
   - Increase logging verbosity
   - Enable detailed monitoring
   - Set up anomaly detection
   - Enable GuardDuty detailed findings
   - Monitor resource usage

4. Backup systems
   - Snapshot affected systems
   - Export databases
   - Archive logs and evidence
   - Lock backups against deletion
```

#### Step 2: Investigation Continuation (30 min - 8 hours)
```
Goal: Understand full scope

1. Identify all affected systems
   - Review IAM actions by compromised principal
   - Scan for attacker artifacts
   - Check process lists on all systems
   - Review cron jobs and scheduled tasks
   - Inspect installed packages

2. Identify all accessed data
   - Query database access logs
   - Review S3 GET requests
   - Check RDS audit logs
   - Monitor data transfer out (data exfiltration)
   - Identify PII or sensitive data accessed

3. Document timeline
   - Create minute-by-minute timeline
   - Mark key events
   - Show progression of attack
   - Note detection times
   - Track response actions

4. Gather forensic evidence
   - Preserve memory dumps
   - Archive disk contents
   - Collect network traffic
   - Document configurations
   - Preserve chat logs (if compromised)
```

#### Step 3: Eradication (8-24 hours)
```
Goal: Remove all attacker presence

1. Revoke all access
   - Delete all API keys
   - Force logout all sessions
   - Reset all passwords
   - Revoke certificates
   - Remove SSH keys
   - Assume role trust disables

2. Patch vulnerabilities
   - Deploy security patches
   - Update vulnerable libraries
   - Fix configuration issues
   - Apply WAF rules
   - Update network security groups

3. Remove attacker tools
   - Uninstall backdoors
   - Remove malware
   - Delete attacker scripts
   - Remove persistence mechanisms
   - Purge attacker data

4. Verify eradication
   - Scan for remaining artifacts
   - Review processes and services
   - Check file integrity
   - Analyze network traffic
   - Run security scanning tools
```

## Escalation Matrix

### Escalation Triggers

#### Escalate to Security Director
- **Trigger**: Tier 1 severity confirmed
- **Action**: Immediate notification, decision on external response
- **Timeline**: Within 30 minutes of incident declaration
- **Contact**: Senior Security Manager (name, phone)

#### Escalate to VP Security
- **Trigger**: Data breach suspected or confirmed
- **Action**: Brief on situation, impact, and legal implications
- **Timeline**: Within 1 hour
- **Contact**: VP of Security (name, phone)

#### Escalate to General Counsel
- **Trigger**: Regulatory reporting likely (HIPAA, GDPR, CCPA)
- **Action**: Discuss legal obligations, notification timing
- **Timeline**: Within 2 hours
- **Contact**: General Counsel (name, phone)

#### Escalate to CEO/Board
- **Trigger**: Public disclosure likely or major data breach
- **Action**: Full briefing, public response plan, investor communication
- **Timeline**: Within 4 hours
- **Contact**: CEO (name, phone)

### Escalation Criteria

```
Decision Tree:

Is Tier 1 (Critical)?
  YES → Escalate immediately to VP Security
  NO → Continue to next

Is data breach suspected?
  YES → Escalate to Legal
  NO → Continue to next

Will customer notification be needed?
  YES → Escalate to Communications
  NO → Continue to next

Is regulatory reporting required?
  YES → Escalate to Legal
  NO → Continue normal incident handling
```

## Forensics Procedures

### Evidence Collection

#### Immediate Actions
```
Within 15 minutes:

1. Isolate systems (don't shut down if active attack)
2. Capture memory dump (if forensics needed)
   aws ec2 create-image --instance-id i-1234567890abcdef0 \
     --name incident-forensics-image
3. Snapshot EBS volumes
4. Download CloudTrail logs (past 90 days)
5. Export CloudWatch logs
6. Capture network traffic
7. Document initial observations
```

#### Evidence Preservation
```
For each piece of evidence:

1. Calculate hash (SHA-256)
   shasum -a 256 evidence.log > evidence.log.sha256

2. Store in locked S3 bucket
   - Enable versioning
   - Enable MFA delete
   - Enable logging
   - Restrict access (security team only)
   - No lifecycle expiration

3. Document chain of custody
   - Who collected evidence
   - When was it collected
   - How was it collected
   - Who has accessed it
   - Where is it stored
   - Verify integrity (hash)

4. Create forensic timeline
   - Organize by timestamp
   - Mark significant events
   - Show attacker progression
   - Indicate detection points
   - Note response actions
```

### Analysis Procedures

#### Log Analysis
```
Logs to analyze:

1. CloudTrail
   - IAM credential usage
   - Privilege escalation attempts
   - Data access patterns
   - Policy changes
   - Resource modifications

2. VPC Flow Logs
   - Unusual connections
   - Unexpected outbound traffic
   - Large data transfers
   - Connection sources

3. Application Logs
   - Error patterns
   - Unusual parameters
   - Authentication failures
   - Data access requests

4. Security Logs
   - WAF blocks
   - GuardDuty findings
   - Security Hub alerts
   - Access denials

Tools: CloudWatch Insights, Athena, manual review
```

#### Malware Analysis
```
If malware suspected:

1. Isolate sample
   - Don't execute in normal environment
   - Use isolated analysis system
   - Air-gapped if possible

2. Analyze malware
   - Static analysis (file properties)
   - Dynamic analysis (runtime behavior)
   - Network connections
   - Registry/file modifications
   - Command and control communication

3. Identify indicators
   - File hashes (MD5, SHA-1, SHA-256)
   - File names and paths
   - Registry keys
   - Network IOCs
   - Process names and behaviors
```

## Recovery Procedures

### Phase 1: Prepare for Restoration (0-4 hours)

```
Before restoring anything:

1. Verify attacker is removed
   - No active access possible
   - All backdoors closed
   - Credentials revoked
   - Firewall rules blocking attacker

2. Identify clean restore point
   - Review backup timestamps
   - Choose backup before compromise
   - Verify backup integrity
   - Test backup restoration

3. Plan restoration
   - Which systems need restoration
   - Restoration order (dependencies)
   - Expected downtime
   - Validation procedures
   - Rollback plan

4. Prepare restoration team
   - Assign responsibilities
   - Provide runbooks
   - Test procedures
   - Ensure proper access
```

### Phase 2: Restore Systems (4-24 hours)

```
Restoration steps:

1. For each affected system:
   a) Restore from clean backup
   b) Verify system integrity
   c) Apply security patches
   d) Update configurations
   e) Start monitoring
   f) Validate functionality

2. Database restoration:
   a) Restore from backup before compromise
   b) Verify data integrity
   c) Run database consistency checks
   d) Update passwords
   e) Restore replication if applicable

3. Application restoration:
   a) Deploy clean code
   b) Verify no backdoors
   c) Update dependencies
   d) Configure security headers
   e) Test functionality
```

### Phase 3: Validation (24-48 hours)

```
After restoration:

1. Functional validation
   - Test all critical features
   - Verify data integrity
   - Check integrations
   - Confirm data completeness

2. Security validation
   - Scan for vulnerabilities
   - Verify security controls active
   - Check monitoring in place
   - Confirm firewall rules
   - Verify encryption working

3. Performance validation
   - Monitor system metrics
   - Check response times
   - Verify capacity
   - Monitor error rates
   - Check resource utilization

4. Monitoring and alerting
   - Verify all alerts active
   - Check thresholds appropriate
   - Confirm notifications working
   - Test runbooks
```

## Post-Incident Review

### Immediate Post-Incident (Day 1)

```
Within 24 hours:

1. Incident debrief meeting
   - Incident commander leads
   - Core team members only
   - Document what happened
   - What worked, what didn't
   - Immediate improvements

2. Senior management briefing
   - Executive summary
   - Impact assessment
   - Current status
   - Next steps
   - Communication plan

3. Secure evidence
   - Finalize forensic evidence
   - Lock down chain of custody
   - Prepare for potential legal review
```

### Formal Post-Incident Review (Week 1-2)

```
Timeline:
- Schedule: 3-7 days after incident
- Duration: 2-4 hours
- Attendees: Full incident team + stakeholders
- Facilitator: Incident commander or external person

Agenda:

1. Timeline review (30 min)
   - What actually happened
   - When did each action occur
   - What was the impact

2. What went well (30 min)
   - Effective detection
   - Rapid response
   - Good communication
   - Proper procedures

3. What could improve (45 min)
   - Gaps in detection
   - Slow response times
   - Communication issues
   - Procedure gaps
   - Tool limitations

4. Root cause analysis (30 min)
   - Why did vulnerability exist
   - Why wasn't it detected
   - Why wasn't it caught faster
   - How to prevent similar incidents

5. Action items (15 min)
   - Specific improvements
   - Owner responsibility
   - Target completion date
   - Success criteria
```

### Post-Incident Report

#### Report Structure
```
1. Executive Summary
   - Incident overview
   - Duration and impact
   - Root cause (brief)
   - Key findings
   - Recommendations

2. Incident Timeline
   - Detailed minute-by-minute progression
   - Key milestones marked
   - Detection to resolution timeline
   - Response actions and timing

3. Impact Assessment
   - Systems affected
   - Data accessed/compromised
   - Customer impact
   - Financial impact
   - Compliance impact

4. Root Cause Analysis
   - Technical root causes
   - Process failures
   - Detection gaps
   - Response delays

5. Lessons Learned
   - What went well
   - What could improve
   - Process improvements
   - Tool improvements
   - Training needs

6. Recommendations
   - Technical controls to implement
   - Process improvements
   - Monitoring enhancements
   - Training requirements
   - Timeline for implementation

7. Appendices
   - Detailed logs
   - Technical analysis
   - Forensic findings
   - Evidence inventory
   - Contact list used
```

## Communication Plans

### Internal Communication

#### During Incident
```
Frequency: Every 15-30 minutes (Tier 1), Every 2 hours (Tier 2)

Channels:
- Slack #incident channel
- Conference bridge (for calls)
- Email for documentation
- War room meetings (as needed)

Information to share:
- Current status
- Latest findings
- Scope of impact
- Actions underway
- Estimated timeline
```

#### External Communication
```
To customers:
- If data accessed: Notify within 72 hours (per regulations)
- If service impacted: Status page updates
- Template: Investigate findings → Impact assessment → Notification

To investors/board:
- If material impact: Notify ASAP
- If breach likely: Legal coordination
- Regular updates during response

To regulators (if required):
- Follow regulatory timelines
- GDPR: 72 hours to authorities
- HIPAA: 60 days to individuals
- Coordinate with legal team
```

### Message Templates

#### Customer Notification
```
Subject: [UPDATE] Incident affecting Bedrock Agents Service

We are writing to inform you of a security incident that
may have affected your data.

On [DATE], we detected unauthorized access to [SYSTEM].

Our investigation found that [BRIEF IMPACT].

We have taken the following actions:
- Contained the incident
- Revoked attacker access
- Restored clean systems
- Deployed additional security controls

What you should do:
- [Reset passwords if applicable]
- [Monitor accounts for suspicious activity]
- [Contact support with questions]

We deeply regret any inconvenience this has caused and remain
committed to protecting your data.

[Contact information]
```

#### Internal Status Update
```
INCIDENT STATUS UPDATE

ID: INC-2024-001
Severity: [TIER]
Status: [Detection/Investigation/Containment/Eradication/Recovery]

Summary:
[One sentence description]

Key Facts:
- Detection time: [TIME]
- Duration: [DURATION]
- Systems affected: [SYSTEMS]
- Data affected: [DATA]
- Root cause: [CAUSE]

Current Actions:
- [Action 1]
- [Action 2]
- [Action 3]

Timeline:
- [HH:MM] Event occurred
- [HH:MM] Detected
- [HH:MM] Investigation started
- [HH:MM] Contained
- [HH:MM] Eradicated

Next Steps:
- [Action]
- [Action]
- [Action]

Estimated Resolution: [DATE/TIME]

Questions? Contact incident commander: [NAME]
```

## Contact Information

### Incident Response Team

```
Role: Incident Commander (On-Call)
Name: [NAME]
Phone: [PHONE]
Email: [EMAIL]
Backup: [BACKUP NAME]

Role: Security Lead
Name: [NAME]
Phone: [PHONE]
Email: [EMAIL]

Role: Operations Lead
Name: [NAME]
Phone: [PHONE]
Email: [EMAIL]

Role: Communications Lead
Name: [NAME]
Phone: [PHONE]
Email: [EMAIL]
```

### External Contacts

```
AWS Support (Enterprise)
Phone: [AWS_PHONE]
Case Dashboard: [AWS_CONSOLE]
TAM: [TECHNICAL_ACCOUNT_MANAGER]

Legal Counsel
Phone: [LEGAL_PHONE]
Email: [LEGAL_EMAIL]

Cyber Insurance
Company: [INSURANCE_COMPANY]
Broker: [BROKER]
Policy: [POLICY_NUMBER]
Hotline: [HOTLINE]

Law Enforcement (if breach)
Local FBI: [FBI_OFFICE]
IC3: ic3.gov
Jurisdiction: [JURISDICTION]
```

## Testing and Drills

### Tabletop Exercises (Quarterly)

```
Schedule: Every 3 months
Duration: 2 hours
Attendees: Incident team + stakeholders

Scenario: Simulated incident
- Incident commander walks through scenario
- No actual system changes
- Team discusses response
- Identify gaps and improvements

Topics:
- Security breach
- Data exfiltration
- System compromise
- Ransomware attack
- DDoS attack
```

### Incident Response Drill (Semi-Annual)

```
Schedule: Every 6 months
Duration: 4-8 hours
Attendees: Full incident team

Scenario: Simulated incident
- Test actual procedures
- Use real tools
- Create simulated artifacts
- Execute forensics procedures
- Verify communication channels

Success criteria:
- Detection within 30 minutes
- Incident declared within 1 hour
- Investigation started within 2 hours
- Evidence preserved properly
- Communication effective
```

### Annual Comprehensive Test (Yearly)

```
Schedule: Once per year
Duration: 24-48 hours
Attendees: All security, ops, and dev staff

Scenario: Realistic multi-day incident
- Red team provides attack simulation
- Blue team executes incident response
- Full recovery testing
- Post-incident review included

Objectives:
- Test full incident response capability
- Identify training gaps
- Validate procedures and runbooks
- Test communication protocols
- Assess tool functionality
```

---

**Document Version**: 1.0
**Last Updated**: November 2024
**Next Review**: May 2025
