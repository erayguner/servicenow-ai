# Post-Incident Report Template

## Incident Summary Report

**Incident ID:** {INCIDENT_ID} **Report Date:** {REPORT_DATE} **Incident
Duration:** {START_DATE} to {END_DATE} ({DURATION_DAYS} days) **Incident
Commander:** {IC_NAME} **Report Prepared By:** {PREPARED_BY}, {PREPARED_DATE}

---

## EXECUTIVE SUMMARY

### Incident Overview

{EXECUTIVE_SUMMARY_PARAGRAPH}

### Key Metrics

- **Detection to Containment:** {TIME_TO_CONTAINMENT}
- **Downtime:** {TOTAL_DOWNTIME}
- **Systems Affected:** {AFFECTED_SYSTEMS_COUNT}
- **Data Affected:** {AFFECTED_RECORDS_COUNT} records
- **Business Impact:** ${FINANCIAL_IMPACT}
- **Customer Impact:** {AFFECTED_CUSTOMER_COUNT} customers

### Outcomes

- ✓ Incident contained successfully
- ✓ Root cause identified
- ✓ Systems restored
- ✓ Preventive measures implemented

---

## INCIDENT TIMELINE

### Phase 1: Detection (T+0 to T+{DETECTION_TIME})

| Time  | Event        | Details                                |
| ----- | ------------ | -------------------------------------- |
| {T+0} | Detection    | {DETECTION_METHOD}: {DETECTION_DETAIL} |
| {T+X} | Verification | {VERIFICATION_DETAIL}                  |
| {T+X} | Escalation   | Incident declared P{SEVERITY}          |
| {T+X} | War room     | Response team assembled                |

### Phase 2: Investigation (T+{START_TIME} to T+{END_TIME})

| Time  | Milestone             | Status     |
| ----- | --------------------- | ---------- |
| {T+X} | Forensics enabled     | ✓ Complete |
| {T+X} | Initial analysis      | ✓ Complete |
| {T+X} | Scope determined      | ✓ Complete |
| {T+X} | Root cause identified | ✓ Complete |

### Phase 3: Containment & Remediation (T+{START_TIME} to T+{END_TIME})

| Time  | Action              | Result                |
| ----- | ------------------- | --------------------- |
| {T+X} | Systems isolated    | ✓ Successful          |
| {T+X} | Credentials rotated | ✓ {COUNT} credentials |
| {T+X} | Patches applied     | ✓ {COUNT} systems     |
| {T+X} | Systems restored    | ✓ Full recovery       |

### Phase 4: Recovery (T+{START_TIME} to T+{END_TIME})

| Time  | Action                | Completion |
| ----- | --------------------- | ---------- |
| {T+X} | Service restoration   | ✓ {DATE}   |
| {T+X} | Validation testing    | ✓ {DATE}   |
| {T+X} | Customer notification | ✓ {DATE}   |
| {T+X} | All-clear declared    | ✓ {DATE}   |

---

## ROOT CAUSE ANALYSIS

### Primary Root Cause

{ROOT_CAUSE_DESCRIPTION}

### Causal Chain

```
Initial Vulnerability
        ↓
Exploit Opportunity
        ↓
Initial Access: {INITIAL_ACCESS}
        ↓
Lateral Movement: {LATERAL_MOVEMENT}
        ↓
Privilege Escalation: {PRIVILEGE_ESCALATION}
        ↓
Data Access/Exfiltration: {DATA_ACCESS}
```

### Contributing Factors

1. **Technical Factors:**

   - {TECHNICAL_FACTOR_1}
   - {TECHNICAL_FACTOR_2}
   - {TECHNICAL_FACTOR_3}

2. **Process Factors:**

   - {PROCESS_FACTOR_1}
   - {PROCESS_FACTOR_2}
   - {PROCESS_FACTOR_3}

3. **Organizational Factors:**
   - {ORG_FACTOR_1}
   - {ORG_FACTOR_2}
   - {ORG_FACTOR_3}

### Risk Assessment (Pre-Incident)

**Control Effectiveness:**

- Network segmentation: 60% (INADEQUATE)
- Access controls: 70% (NEEDS IMPROVEMENT)
- Monitoring: 50% (INADEQUATE)
- Incident response: 80% (EFFECTIVE)

---

## IMPACT ANALYSIS

### Business Impact

- **Services Affected:** {SERVICES_AFFECTED}
- **Availability Loss:** {DOWNTIME} hours
- **Revenue Impact:** ${REVENUE_IMPACT}
- **SLA Violations:** {SLA_VIOLATIONS} breaches
- **Customer Satisfaction:** {NPS_IMPACT}

### Data Impact

- **Records Affected:** {RECORD_COUNT}
- **Data Types:** {DATA_TYPES_LIST}
- **Classification Levels:** {CLASSIFICATION_LEVELS}
- **Individuals Affected:** {INDIVIDUAL_COUNT}

### Regulatory Impact

- **Breach Notification Required:** YES/NO
- **Regulatory Bodies Notified:** {REGULATORY_BODIES}
- **Compliance Status:** {COMPLIANCE_STATUS}
- **Potential Fines:** ${POTENTIAL_FINES}

### Reputation Impact

- **Media Coverage:** {MEDIA_MENTIONS}
- **Public Statements:** {STATEMENTS_MADE}
- **Customer Confidence:** {CONFIDENCE_IMPACT}
- **Mitigation:** {REPUTATION_MITIGATION}

---

## FORENSICS FINDINGS

### Evidence Collected

- CloudTrail logs: {EVENTS_COUNT} events
- VPC Flow Logs: {FLOW_ENTRIES} entries
- Application logs: {LOG_ENTRIES} entries
- Memory dumps: {DUMPS_COUNT} captures
- Disk snapshots: {SNAPSHOTS_COUNT} snapshots

### Forensic Analysis Results

**Attack Indicators:**

- {IOC_1}
- {IOC_2}
- {IOC_3}
- {IOC_4}

**Attacker Profile:**

- Sophistication level: {SOPHISTICATION}
- Motivation: {MOTIVATION}
- Attack duration: {ATTACK_DURATION}
- Methods used: {METHODS_USED}

**Evidence of Data Exfiltration:**

- [ ] Evidence found: YES/NO
- Data confirmed exfiltrated: {DATA_EXFILTRATED}
- Exfiltration method: {EXFIL_METHOD}
- Destination: {EXFIL_DESTINATION}

---

## RESPONSE EFFECTIVENESS

### Team Performance

**What Went Well:**

1. {SUCCESS_1} - Demonstrated by {EVIDENCE_1}
2. {SUCCESS_2} - Demonstrated by {EVIDENCE_2}
3. {SUCCESS_3} - Demonstrated by {EVIDENCE_3}

**Areas for Improvement:**

1. {IMPROVEMENT_1} - Impact: {IMPACT_1}
2. {IMPROVEMENT_2} - Impact: {IMPACT_2}
3. {IMPROVEMENT_3} - Impact: {IMPACT_3}

**Response Metrics:** | Metric | Target | Actual | Status |
|--------|--------|--------|--------| | Detection to Containment | < 30 min |
{ACTUAL} min | ✓ {STATUS} | | Root Cause Analysis | < 8 hours | {ACTUAL} hrs | ✓
{STATUS} | | Service Recovery | < 4 hours | {ACTUAL} hrs | ✓ {STATUS} | |
Customer Notification | < 72 hours | {ACTUAL} hrs | ✓ {STATUS} |

### Communication Effectiveness

- Internal updates: {INTERNAL_UPDATES} (Frequency: {FREQUENCY})
- Customer updates: {CUSTOMER_UPDATES} (Frequency: {FREQUENCY})
- Executive updates: {EXEC_UPDATES} (Frequency: {FREQUENCY})
- Feedback rating: {FEEDBACK_RATING}/10

---

## REMEDIATION ACTIONS

### Immediate Actions (Completed)

| Action     | Priority | Status | Completion Date |
| ---------- | -------- | ------ | --------------- |
| {ACTION_1} | P1       | ✓      | {DATE}          |
| {ACTION_2} | P1       | ✓      | {DATE}          |
| {ACTION_3} | P2       | ✓      | {DATE}          |
| {ACTION_4} | P2       | ✓      | {DATE}          |

### Short-term Actions (In Progress)

| Action     | Priority | Status | Due Date |
| ---------- | -------- | ------ | -------- |
| {ACTION_1} | P1       | 75%    | {DATE}   |
| {ACTION_2} | P1       | 60%    | {DATE}   |
| {ACTION_3} | P2       | 40%    | {DATE}   |
| {ACTION_4} | P2       | 25%    | {DATE}   |

### Long-term Actions (Planned)

| Action     | Priority | Target | Owner   |
| ---------- | -------- | ------ | ------- |
| {ACTION_1} | P2       | {DATE} | {OWNER} |
| {ACTION_2} | P2       | {DATE} | {OWNER} |
| {ACTION_3} | P3       | {DATE} | {OWNER} |
| {ACTION_4} | P3       | {DATE} | {OWNER} |

---

## LESSONS LEARNED

### What We Did Well

1. **Detection & Response**

   - Rapid detection enabled by {MECHANISM}
   - Quick response team activation (T+{TIME})
   - Effective communication and coordination

2. **Investigation**

   - Comprehensive forensics collection
   - Effective root cause analysis
   - Clear documentation

3. **Customer Communication**
   - Timely notifications
   - Transparent updates
   - Helpful resources provided

### What We Could Improve

1. **Detection Improvements**

   - Need earlier detection of {SYMPTOM}
   - Implement {DETECTION_IMPROVEMENT}
   - Timeline: {TIMELINE}

2. **Response Improvements**

   - Faster {RESPONSE_AREA} needed
   - Training needed on {TRAINING_TOPIC}
   - Timeline: {TIMELINE}

3. **Technical Improvements**
   - Implement {TECHNICAL_IMPROVEMENT}
   - Harden {HARDENING_AREA}
   - Timeline: {TIMELINE}

### Key Takeaways

1. {TAKEAWAY_1}
2. {TAKEAWAY_2}
3. {TAKEAWAY_3}
4. {TAKEAWAY_4}

---

## PREVENTIVE MEASURES

### Controls to Prevent Recurrence

| Control     | Area   | Implementation | Timeline | Owner   |
| ----------- | ------ | -------------- | -------- | ------- |
| {CONTROL_1} | {AREA} | {METHOD}       | {DATE}   | {OWNER} |
| {CONTROL_2} | {AREA} | {METHOD}       | {DATE}   | {OWNER} |
| {CONTROL_3} | {AREA} | {METHOD}       | {DATE}   | {OWNER} |
| {CONTROL_4} | {AREA} | {METHOD}       | {DATE}   | {OWNER} |

### Training & Awareness

- Security awareness training (Mandatory for all staff by {DATE})
- Incident response training (Quarterly drills)
- Development security training (All developers)
- Management briefings (Quarterly)

### Process Improvements

- Updated incident response playbook
- Enhanced escalation procedures
- Improved change management controls
- Quarterly tabletop exercises

---

## COST ANALYSIS

### Incident Costs

| Category          | Amount               | Notes                      |
| ----------------- | -------------------- | -------------------------- |
| Incident response | ${IR_COST}           | Team hours and tools       |
| Forensics         | ${FORENSICS_COST}    | External consultants       |
| Legal/Regulatory  | ${LEGAL_COST}        | Compliance and disclosure  |
| Notification      | ${NOTIFICATION_COST} | Credit monitoring, support |
| Remediation       | ${REMEDIATION_COST}  | Systems recovery           |
| **TOTAL**         | **${TOTAL_COST}**    |                            |

### Cost Avoidance Through Prevention

- Estimated losses prevented: ${PREVENTED_LOSS}
- Risk reduction: {RISK_REDUCTION}%

---

## RECOMMENDATIONS

### Immediate (30 days)

1. {RECOMMENDATION_1}
2. {RECOMMENDATION_2}
3. {RECOMMENDATION_3}

### Short-term (90 days)

1. {RECOMMENDATION_1}
2. {RECOMMENDATION_2}
3. {RECOMMENDATION_3}

### Long-term (12 months)

1. {RECOMMENDATION_1}
2. {RECOMMENDATION_2}
3. {RECOMMENDATION_3}

---

## APPENDICES

1. Detailed timeline
2. Forensic analysis report
3. Root cause analysis
4. Communication samples
5. Log analysis results
6. System architecture diagrams
7. Lessons learned workshop notes
8. Corrective action tracking

---

## APPROVALS

**Report Prepared By:** Name: {NAME} | Title: {TITLE} | Date: {DATE}

**Security Lead Review:** Name: {NAME} | Date: {DATE} | Signature: **\_\_\_**

**CISO Approval:** Name: {NAME} | Date: {DATE} | Signature: **\_\_\_**

**Executive Sponsor:** Name: {NAME} | Date: {DATE} | Signature: **\_\_\_**

---

**End of Report**

**Incident ID:** {INCIDENT_ID} **Version:** 1.0 **Last Updated:** {DATE}
**Classification:** Internal Use Only
