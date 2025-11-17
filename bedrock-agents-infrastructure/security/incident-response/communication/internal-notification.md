# Internal Security Incident Notification Template

## Subject: [SEVERITY] Security Incident Notification - Incident ID: {INCIDENT_ID}

---

## INCIDENT ALERT

**Incident ID:** {INCIDENT_ID}
**Severity Level:** {SEVERITY_LEVEL} (P1/P2/P3/P4)
**Detection Time:** {DETECTION_TIME}
**Notification Time:** {NOTIFICATION_TIME}
**Incident Commander:** {INCIDENT_COMMANDER}

---

## EXECUTIVE SUMMARY

**Incident Type:** {INCIDENT_TYPE}

A security incident has been detected and confirmed within the Bedrock agents infrastructure.

**Status:** {STATUS}
**Business Impact:** {BUSINESS_IMPACT}
**Customer Impact:** {CUSTOMER_IMPACT}

### Key Facts
- **Affected Systems:** {AFFECTED_SYSTEMS}
- **Detection Method:** {DETECTION_METHOD}
- **Estimated Duration:** {ESTIMATED_DURATION}
- **Data Potentially Affected:** {DATA_AFFECTED}
- **Active Threats:** {ACTIVE_THREATS}

---

## IMMEDIATE ACTIONS TAKEN

1. **Containment:**
   - [ ] Affected systems isolated
   - [ ] Suspicious credentials revoked
   - [ ] Network access restricted
   - [ ] Traffic blocked at WAF

2. **Forensics:**
   - [ ] Forensics mode enabled
   - [ ] Logs captured
   - [ ] Snapshots created
   - [ ] Evidence preserved

3. **Communication:**
   - [ ] Incident war room created (Slack: {WAR_ROOM_CHANNEL})
   - [ ] Stakeholders notified
   - [ ] War room briefing scheduled
   - [ ] Status updates scheduled

---

## INCIDENT DETAILS

### Timeline
**{TIME_1}** - Initial detection via {DETECTION_SOURCE}
**{TIME_2}** - Verification and confirmation
**{TIME_3}** - Containment measures initiated
**{TIME_4}** - Forensics collection started
**{TIME_5}** - Stakeholder notification

### Affected Resources
- **Accounts/Systems:** {RESOURCES_LIST}
- **Data Classifications:** {DATA_CLASSIFICATIONS}
- **Geographic Scope:** {GEOGRAPHIC_SCOPE}
- **User Impact:** {USER_COUNT} users potentially affected

### Initial Assessment
{INITIAL_ASSESSMENT_DETAILS}

---

## RESPONSE COORDINATION

### War Room Details
- **Location:** Slack #{WAR_ROOM_CHANNEL}
- **Conference Bridge:** {CONFERENCE_BRIDGE}
- **Incident Page:** {INCIDENT_PAGE_URL}

### Incident Command Structure
- **Incident Commander:** {IC_NAME} ({IC_CONTACT})
- **Technical Lead:** {TECH_LEAD_NAME} ({TECH_LEAD_CONTACT})
- **Communications Lead:** {COMM_LEAD_NAME} ({COMM_LEAD_CONTACT})

### Next Steps
1. {NEXT_STEP_1}
2. {NEXT_STEP_2}
3. {NEXT_STEP_3}
4. {NEXT_STEP_4}
5. {NEXT_STEP_5}

---

## STATUS UPDATES

| Time | Status | Details |
|------|--------|---------|
| {TIME} | {STATUS} | {DETAILS} |
| {TIME} | {STATUS} | {DETAILS} |
| {TIME} | {STATUS} | {DETAILS} |

**Next Update:** {NEXT_UPDATE_TIME}

---

## REQUIRED ACTIONS

### For Security Team
- [ ] Conduct detailed forensic analysis
- [ ] Determine root cause
- [ ] Identify extent of compromise
- [ ] Recommend remediation actions
- [ ] Participate in war room

### For Engineering Teams
- [ ] Join war room
- [ ] Validate containment
- [ ] Prepare recovery procedures
- [ ] Be ready to execute remediation
- [ ] Monitor systems for anomalies

### For Operations
- [ ] Monitor resource utilization
- [ ] Maintain infrastructure
- [ ] Support forensics team
- [ ] Provide access as needed
- [ ] Document all actions

### For Leadership
- [ ] Monitor incident progress
- [ ] Prepare for potential disclosure
- [ ] Brief legal/regulatory if needed
- [ ] Prepare customer communication
- [ ] Monitor business impact

---

## RESOURCES & LINKS

- **Incident Tracking:** {TICKET_URL}
- **War Room:** {WAR_ROOM_URL}
- **Documentation:** {DOCUMENTATION_URL}
- **Runbooks:** {RUNBOOKS_URL}
- **Playbooks:** {PLAYBOOKS_URL}

---

## CONFIDENTIALITY & DISTRIBUTION

**CONFIDENTIAL - Law Firm Privileged & Confidential**

This notification contains attorney-client privileged information and should not be distributed outside of the response team without authorization.

**Distribution:**
- Incident Response Team
- Executive Leadership (if P1)
- Legal Department (if P1)
- Public Relations (if P1)

---

## ESCALATION PATH

```
Security Alert (Automated)
        ↓
On-Call Security Engineer (Immediate)
        ↓
Security Lead (5 min decision)
        ↓
CISO (15 min strategic decision)
        ↓
CEO/General Counsel (Legal/PR decision)
```

---

## FREQUENTLY ASKED QUESTIONS

**Q: How did this happen?**
A: Investigation ongoing. Initial assessment indicates {INITIAL_CAUSE}

**Q: Is my data at risk?**
A: Possibly. Details being determined. {DATA_RISK_DETAILS}

**Q: What's being done?**
A: Comprehensive response underway. See "Immediate Actions" section above.

**Q: When will this be resolved?**
A: Estimated {ESTIMATED_RESOLUTION_TIME}

**Q: Do I need to change my password?**
A: {PASSWORD_GUIDANCE}

---

## CONTACT INFORMATION

- **Security Incident Response:** {SECURITY_EMAIL} or {SECURITY_PHONE}
- **War Room Channel:** {SLACK_CHANNEL}
- **Incident Page:** {INCIDENT_PAGE}

---

**This is an automated notification from the Incident Response System.**
**Acknowledgment:** Please reply to confirm receipt of this notification.

