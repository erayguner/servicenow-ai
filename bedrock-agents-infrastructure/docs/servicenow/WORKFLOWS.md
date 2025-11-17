# ServiceNow Bedrock Workflows Guide

## Table of Contents

1. [Incident Resolution Workflow](#incident-resolution-workflow)
2. [Change Management Workflow](#change-management-workflow)
3. [Knowledge Base Synchronization Workflow](#knowledge-base-synchronization-workflow)
4. [Error Handling and Recovery](#error-handling-and-recovery)
5. [Custom Workflow Implementation](#custom-workflow-implementation)

## Incident Resolution Workflow

### Workflow Phases

The incident resolution workflow consists of the following phases:

#### Phase 1: Detection and Ingestion

**Trigger**: New incident created or existing incident modified in ServiceNow

**Process**:
```
1. ServiceNow Business Rule detects incident creation/modification
2. HTTP POST sent to API Gateway with incident data
3. Lambda function receives webhook
4. Validates incident data
5. Creates session record in DynamoDB
6. Invokes Incident Resolution Agent
```

**Input Data**:
```json
{
  "incident_id": "sys_id",
  "incident_number": "INC0001234",
  "short_description": "Unable to access email",
  "description": "User reports unable to access email on mobile device",
  "created_by": "user_id",
  "created_on": "2024-11-17T10:30:00Z",
  "caller_id": "sys_id",
  "caller_name": "John Smith",
  "impact": "1",
  "urgency": "1"
}
```

#### Phase 2: Analysis

**Objective**: Analyze incident to understand symptoms and identify root cause

**Agent Actions**:
```
1. Extract key information from incident description
   - What is the problem?
   - When did it start?
   - Who is affected?
   - What systems are involved?

2. Search Knowledge Base for relevant articles
   - Use incident symptoms as search terms
   - Review matching articles for solutions
   - Check article recency and ratings

3. Query incident history
   - Find similar incidents
   - Review resolutions of similar incidents
   - Identify patterns

4. Analyze impact and urgency
   - How many users are affected?
   - What is the business impact?
   - What is the appropriate priority level?
```

**Processing Logic**:
```javascript
if (symptoms match known pattern) {
  confidence = high;
  probable_cause = pattern_cause;
  recommended_solution = pattern_solution;
} else if (KB articles found) {
  confidence = medium;
  probable_cause = kb_suggested_cause;
  recommended_solution = kb_solution;
} else {
  confidence = low;
  probable_cause = general_analysis;
  recommended_solution = diagnostic_steps;
  escalation_recommended = true;
}
```

#### Phase 3: Categorization and Assignment

**Objective**: Assign incident to appropriate team with correct categorization

**Actions**:
```
1. Determine incident category
   - Service category (Email, Network, Hardware, etc.)
   - Subcategory (specific area)
   - Configuration item
   - Affected service

2. Assess severity and priority
   - Impact: How many users affected (1-3)
   - Urgency: How quickly resolution needed (1-3)
   - Priority: Calculated from Impact × Urgency (1-9)
   - Severity: Business-critical impact assessment

3. Identify assignment group
   - Use assignment rules engine
   - Consider current queue length
   - Factor in skill requirements
   - Check team availability

4. Create work notes with analysis
   - Summarize findings
   - Link relevant KB articles
   - Highlight potential risks
   - Suggest next troubleshooting steps
```

**Assignment Rules Example**:
```
Rule: If category = "Email" then assign to "Email Support Team"
Rule: If category = "Network" and priority = 1 then assign to "Network NOC"
Rule: If KB article found and solution clear then assign to "Tier-1 Support"
Rule: If multiple KB searches with no result then assign to "Tier-2 Support"
```

#### Phase 4: Solution Recommendation

**Objective**: Provide detailed troubleshooting or solution steps

**Output Format**:
```
SOLUTION STEPS FOR INCIDENT {incident_number}

Problem: {problem_summary}
Root Cause: {root_cause_analysis}

IMMEDIATE WORKAROUND (if applicable):
1. [Step 1 - Quick relief]
2. [Step 2 - Quick relief]
Result: User can continue work with workaround

PERMANENT SOLUTION:
Prerequisites:
- [Prerequisite 1]
- [Prerequisite 2]

Steps:
1. [Step 1 with detailed instructions]
   Command: [if applicable]
   Expected result: [what to see]

2. [Step 2]
   Command: [if applicable]
   Expected result: [what to see]

Verification:
- [Check 1 - how to verify success]
- [Check 2]

Prevention:
- [Preventive measure 1]
- [Preventive measure 2]

Estimated Time: [duration]
Confidence Level: [0-100%]

References:
- KB Article: [link]
- Related Incidents: [incidents]
- Documentation: [links]
```

**Example Response**:
```
SOLUTION FOR INC0001234 - Email Access Issue

Problem: User unable to access email on mobile device
Root Cause: Incorrect OAuth configuration after recent security update

IMMEDIATE WORKAROUND:
1. Access email through web interface (webmail.company.com)
Result: User can access email via web until mobile is fixed

PERMANENT SOLUTION:
Prerequisites:
- Device must have internet connectivity
- User needs to know their email password

Steps:
1. On the mobile device, go to Settings > Accounts
   Expected result: List of configured accounts shown

2. Select your email account and tap "Manage"
   Expected result: Account management interface opens

3. Tap "Delete account"
   Expected result: Confirmation prompt appears (tap "Yes" to confirm)

4. Go back to Settings > Accounts > Add account
   Expected result: Account type selection screen shows

5. Select "Company Email"
   Expected result: Login screen appears

6. Enter your email and password, tap "Next"
   Expected result: Configuration begins automatically

7. Wait 2-3 minutes for configuration to complete
   Expected result: Account syncs successfully

Verification:
- Compose a test email to verify sending works
- Check inbox to verify receiving works
- Confirm calendar and contacts are accessible

Prevention:
- Enable two-factor authentication with security key instead of SMS
- Keep device software updated
- Review OAuth app permissions monthly

Estimated Time: 10 minutes
Confidence Level: 95%
```

#### Phase 5: Implementation and Monitoring

**Objective**: Track incident progress toward resolution

**Monitoring Loop**:
```
Every 5 minutes (while In Progress):
1. Check incident status for updates
2. Review resolver group activity
3. Monitor for escalations
4. Check for related incidents
5. If no progress after timeout: escalate

Status Updates:
- If status still "New" after 30 mins → escalate
- If status still "Assigned" after 2 hours → escalate
- If status still "In Progress" after 4 hours → escalate
- If multiple escalations → route to management
```

**Alert Conditions**:
```
High Priority + No Progress = Immediate escalation
Blocked on information = Contact caller
Blocked on resources = Escalate to supervisor
Cannot implement solution = Escalate to senior team
```

#### Phase 6: Resolution and Closure

**Objective**: Close incident with proper documentation

**Closure Process**:
```
When incident marked "Resolved":
1. Verify resolution with requester
2. Document solution in work notes
3. Update incident category based on actual cause
4. Record resolution time
5. Rate solution effectiveness
6. Determine if KB article should be created
7. Close incident with resolution summary
8. Collect user feedback
9. Archive for analysis
```

**Closure Checklist**:
```
☐ Solution verified by end user
☐ All steps documented in work notes
☐ Root cause clearly identified
☐ Prevention measures noted
☐ Related incidents linked
☐ KB article created (if applicable)
☐ Feedback requested from caller
☐ Resolution category updated
☐ Resolution time recorded
☐ Incident approved for closure
```

**Feedback Survey**:
```
User receives:
1. Was your issue resolved? (Yes/No)
2. How satisfied are you with the resolution? (1-5)
3. How helpful was the support? (1-5)
4. Additional comments?

Feedback Integration:
- If satisfaction < 3 → Review incident and provide additional support
- If satisfaction = 5 → Track resolver/team as high performer
- Analyze patterns for continuous improvement
```

### Complete Incident Workflow Diagram

```
┌─────────────────────┐
│ New/Updated         │
│ Incident            │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Detect via          │
│ Business Rule       │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Invoke Agent        │
│ (Bedrock)           │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────────────────────┐
│ Analysis Phase                      │
│ - Extract symptoms                  │
│ - Search KB & history               │
│ - Identify root cause               │
└──────────┬──────────────────────────┘
           │
           ▼
┌──────────────────────────────────┐
│ Categorization Phase             │
│ - Assign category/subcategory    │
│ - Set priority/severity          │
│ - Identify assignment group      │
└──────────┬───────────────────────┘
           │
           ▼
┌──────────────────────────────────┐
│ Add Work Notes with              │
│ Analysis & Recommendations       │
└──────────┬───────────────────────┘
           │
           ▼
┌──────────────────────────────────┐
│ Update Incident & Assign         │
└──────────┬───────────────────────┘
           │
           ▼
      ┌────┴─────┐
      │           │
   Auto-Resolve? │ No
   Yes │          │
      ▼           ▼
┌──────────┐  ┌────────────────┐
│ Resolve  │  │ Monitor Status │ ← Recurring checks
│ Incident │  │ & Escalate if  │
└────┬─────┘  │ needed         │
     │        └────────┬───────┘
     │                 │
     │         ┌───────┴─────┐
     │         │             │
     │    Resolved        Not Resolved
     │         │             │
     │         ▼             ▼
     │      Collect      Re-escalate
     │      Feedback     or Re-assign
     │         │             │
     └────┬────┴─────────────┘
          │
          ▼
     ┌────────────┐
     │ Closed     │
     │ Generate   │
     │ KB Article │
     └────────────┘
```

## Change Management Workflow

### Workflow Phases

#### Phase 1: Submission and Initial Review

**Trigger**: New change request submitted in ServiceNow

**Process**:
```
1. Change request submitted by change manager/requester
2. Change data validated for completeness
3. Initial triage by Change Coordination Agent
4. Preliminary risk assessment
5. Determination of approval requirements
6. Notification of stakeholders

Validation Checks:
- Short description present and descriptive
- Detailed description provided
- Business justification clear
- Affected systems identified
- Implementation plan documented
- Rollback plan documented
- Implementation window selected
- Risk assessment completed
```

#### Phase 2: Risk Assessment

**Objective**: Evaluate change risk and determine governance requirements

**Risk Calculation Formula**:
```
Risk Score = (Technical Risk × 0.4) + (Business Risk × 0.4) + (Operational Risk × 0.2)

Where:
- Technical Risk (1-10): Complexity, testing coverage, rollback feasibility
- Business Risk (1-10): User impact count, revenue impact, SLA impact
- Operational Risk (1-10): Resource availability, skill gaps, schedule pressure

Risk Level:
- Score 1-30: LOW → Standard approval only
- Score 31-60: MEDIUM → CAB review recommended
- Score 61-90: HIGH → CAB review required
- Score 91-100: CRITICAL → Executive approval required
```

**Assessment Process**:
```
1. Extract change scope and impact
   - How many systems affected?
   - What's the blast radius?
   - Are there dependencies?

2. Review change type and history
   - Is this a standard change (pre-approved)?
   - Similar changes in the past?
   - Success rate of similar changes?

3. Evaluate implementation plan
   - Timeline realistic?
   - Resources available?
   - Prerequisites met?
   - All steps documented?

4. Review rollback plan
   - Can we roll back? (yes/no/partial)
   - Rollback time estimate?
   - Data consistency concerns?
   - Estimated data loss on rollback?

5. Identify dependencies and conflicts
   - Other changes in same window?
   - Resource conflicts?
   - Data dependencies?
   - Service dependencies?
```

#### Phase 3: CAB Determination and Coordination

**Decision Logic**:
```
if (risk_score >= 60) {
  cab_required = true;
  cab_urgency = risk_score > 85 ? "expedited" : "standard";
  meeting_date = next_cab_meeting;
} else if (potential_user_impact > 500) {
  cab_required = true;
} else if (affected_critical_systems) {
  cab_required = true;
} else {
  cab_required = false;
  approval_path = "standard_approval";
}
```

**CAB Coordination Steps**:
```
When CAB Required:
1. Extract CAB members for affected systems
2. Check their availability
3. Schedule CAB meeting (within 48 hours)
4. Prepare CAB summary document
5. Send meeting invite with documentation
6. Monitor CAB approval/rejection
7. If approved: schedule implementation
8. If rejected: notify requester with feedback
9. If conditional: update plan and resubmit

CAB Summary Includes:
- Executive summary (non-technical)
- Business justification
- Risk assessment with mitigations
- Technical impact analysis
- Testing results
- Rollback procedure
- Implementation timeline
- Success criteria
- Contact info for questions
```

#### Phase 4: Approval

**Approval Paths**:
```
Standard Path (Risk < 60):
1. Change manager approves
2. CAB optional
3. Implement

CAB Path (Risk 60-85):
1. CAB review and approval
2. Implement

Critical Path (Risk 86+):
1. CAB review and approval
2. Executive/Director approval
3. Implement

Emergency Path (Emergency change):
1. Director approval required
2. Minimal CAB review
3. Post-implementation review within 24 hours
```

#### Phase 5: Scheduling

**Process**:
```
1. Identify maintenance windows
   - Preferred: Sunday 2 AM - 6 AM
   - Backup: Saturday 2 AM - 6 AM
   - During business hours if low-risk

2. Check for conflicts
   - Other scheduled changes
   - Resource availability
   - User maintenance activities

3. Resolve conflicts
   - Reschedule this change
   - Reschedule conflicting changes
   - Suggest alternative time slot

4. Confirm implementation window
   - Send notification to change manager
   - Update change request with schedule
   - Notify affected teams and users

5. Prepare prerequisites
   - Gather required resources
   - Prepare communication templates
   - Validate rollback procedures
```

#### Phase 6: Pre-Implementation

**Preparation Checklist**:
```
72 Hours Before Implementation:
☐ Implementation team confirmed
☐ All resources allocated
☐ Testing completed and verified
☐ Rollback procedure tested
☐ Communication templates ready
☐ Backups created
☐ Documentation reviewed

24 Hours Before Implementation:
☐ Team briefing completed
☐ Final readiness check done
☐ User communication sent
☐ Change window locked (no more conflicts)
☐ Emergency contacts confirmed
☐ War room access verified
☐ All tools and access verified

1 Hour Before Implementation:
☐ War room opened
☐ Team standup completed
☐ Baseline metrics captured
☐ Communication channels tested
☐ Rollback procedures briefed
☐ Success criteria reviewed
☐ Implementation started
```

#### Phase 7: Implementation

**Execution Process**:
```
1. Pre-implementation verification
   - System baseline captured
   - All prerequisites confirmed
   - Rollback team ready

2. Implementation steps
   - Execute change steps in order
   - Monitor for issues
   - Document any deviations
   - Capture timestamps

3. Real-time monitoring
   - Check affected systems
   - Monitor error rates and performance
   - Review log files
   - Stay alert for anomalies

4. Success verification
   - Test all success criteria
   - Verify no side effects
   - Confirm service stability
   - Get stakeholder confirmation

5. Immediate post-implementation
   - Document actual implementation time
   - Record any issues encountered
   - Update change request status
   - Notify stakeholders of success
```

**Implementation Decision Tree**:
```
Implementation starts
        │
        ▼
   All steps successful?
        │
    ├─ YES → Verify success criteria
    │            │
    │            ▼
    │       Success criteria met?
    │            │
    │        ├─ YES → Mark "Successful"
    │        │            └─ Close change
    │        │
    │        └─ NO → Investigate failure
    │                     │
    │                     └─ Rollback needed?
    │                              │
    │                      ├─ YES → Execute rollback
    │                      │
    │                      └─ NO → Fix in place
    │
    └─ NO → Issue detected
               │
               ▼
          Can continue?
               │
           ├─ YES → Fix and retry step
           │
           └─ NO → Execute rollback
```

#### Phase 8: Post-Implementation

**Process**:
```
Immediately (30 minutes):
- Monitor for critical issues
- Check error logs
- Verify service availability
- Confirm user access

Short-term (4 hours):
- Extended monitoring
- Check secondary systems
- Review automated health checks
- Compare against baseline metrics

Medium-term (24 hours):
- Performance analysis
- Error rate analysis
- User feedback collection
- Stability assessment

Long-term (1 week):
- Success metrics analysis
- Lessons learned documentation
- Update runbooks if needed
- Plan follow-up tasks if needed
```

**Post-Implementation Review**:
```
Performed 3-5 days after implementation:

1. Success Assessment
   - Were success criteria met?
   - Did the change deliver expected benefits?
   - Any unexpected side effects?

2. Impact Analysis
   - Performance impact measurements
   - User satisfaction impact
   - Service quality impact
   - Cost impact (if applicable)

3. Issues and Learnings
   - What went well?
   - What could be improved?
   - Any unexpected issues?
   - How to prevent future issues?

4. Documentation
   - Update runbooks with actual steps
   - Document any deviations
   - Update troubleshooting guides
   - Share lessons with broader team

5. Process Improvement
   - Update change templates if needed
   - Refine risk assessment criteria
   - Improve testing procedures
   - Train team on improvements
```

## Knowledge Base Synchronization Workflow

### Automatic Trigger Workflow

```
Incident Resolved
    │
    ├─ Analyze resolution content
    │  └─ Is KB-worthy? (technical solution provided)
    │
    ├─ YES
    │  ├─ Search KB for related articles
    │  ├─ Check for duplicates
    │  ├─ Generate article draft
    │  ├─ Format and structure
    │  ├─ Add metadata/keywords
    │  ├─ Review for accuracy
    │  └─ Publish to KB
    │
    └─ NO
       └─ Skip KB generation
```

### Scheduled Maintenance Workflow

**Daily Workflow (2 AM):**
```
1. Analyze KB search logs
   - What did users search for?
   - What queries had no results?
   - What had low satisfaction ratings?

2. Generate knowledge gap report
   - Articles needed (high-demand searches)
   - Articles to improve (low satisfaction)
   - Obsolete articles to retire

3. Create KB improvement tasks
   - Assignment to content owners
   - Priority based on impact
   - Due dates for completion
```

**Weekly Workflow (Sunday 3 AM):**
```
1. Analyze article effectiveness
   - View counts by article
   - User satisfaction ratings
   - Resolution time impact
   - Search visibility

2. Identify duplicate or related articles
   - Content similarity analysis
   - Suggestion for consolidation
   - Create merge tasks

3. Update stale articles
   - Review and update older articles
   - Add new insights from recent incidents
   - Refresh screenshots/diagrams if needed

4. Generate KB health report
   - Total article count
   - Coverage by topic/system
   - Orphaned articles
   - Opportunities for new content
```

**Monthly Workflow (1st of month):**
```
1. Comprehensive KB audit
   - Review all articles for accuracy
   - Check for outdated information
   - Verify links still valid
   - Review against current system versions

2. Content refresh
   - Update articles for new product versions
   - Incorporate recent learnings
   - Improve clarity where needed

3. Strategic review
   - Identify coverage gaps by system
   - Plan content for upcoming projects
   - Assess KB readiness for user self-service
   - Calculate ROI of KB investment

4. Training and improvement
   - Train authors on best practices
   - Share top-performing articles as examples
   - Provide feedback on low-performing articles
   - Recognize high-quality contributions
```

## Error Handling and Recovery

### Error Detection

```
Agents monitor for:
1. ServiceNow API errors
   - 401/403: Authentication/Authorization
   - 404: Record not found
   - 429: Rate limited
   - 500+: Server errors

2. Bedrock errors
   - Model unavailable
   - Token limit exceeded
   - Invalid input format
   - Timeout

3. Application errors
   - Invalid data format
   - Missing required fields
   - Database connection failure
   - Timeout errors

4. Business logic errors
   - No matching assignment group
   - Insufficient data for decision
   - Conflicting constraints
   - Circular dependencies
```

### Recovery Strategies

```
For Transient Errors (API rate limit, temporary outage):
1. Implement exponential backoff
   - Wait 30 seconds, then retry
   - Wait 60 seconds, then retry
   - Wait 120 seconds, then retry
   - Wait 300 seconds, then retry
   - Fail after 4 retries

For Permanent Errors (Bad request, authentication):
1. Log error with full context
2. Notify error handling team
3. Return user-friendly error message
4. Escalate to human if customer-facing
5. Fail fast without retry

For Timeout Errors:
1. If < 3 retries: Retry with same parameters
2. If >= 3 retries: Return partial results with warning
3. Queue for retry in background
4. Notify user of delayed results

For Confidence-Based Escalation:
1. If confidence < 40%: Always escalate to human
2. If confidence 40-60%: Escalate for critical systems
3. If confidence 60-80%: Proceed with warning
4. If confidence 80%+: Proceed normally
```

## Custom Workflow Implementation

### Creating a New Workflow

**Step 1: Define Workflow Requirements**
```
1. Identify trigger event(s)
2. Define process phases
3. Specify decision points
4. Determine outputs
5. Plan error handling
6. Identify metrics to track
```

**Step 2: Create Workflow Configuration**
```json
{
  "workflow_name": "Custom Workflow",
  "trigger": "incident_created",
  "phases": [
    {"name": "Detection", "timeout": 300},
    {"name": "Analysis", "timeout": 600},
    {"name": "Action", "timeout": 900}
  ],
  "decision_points": [
    {"condition": "priority = 1", "then": "escalate"}
  ],
  "error_handling": "exponential_backoff",
  "notifications": true
}
```

**Step 3: Implement Phase Logic**
```javascript
async function executePhase(phaseName, context) {
  const phase = workflow.phases.find(p => p.name === phaseName);

  try {
    const result = await phase.execute(context, {
      timeout: phase.timeout
    });

    return {
      phase: phaseName,
      status: 'completed',
      result: result
    };
  } catch (error) {
    return await handlePhaseError(error, phase, context);
  }
}
```

**Step 4: Test Workflow**
```
1. Unit test each phase independently
2. Integration test phase sequence
3. Test error handling paths
4. Load test with multiple concurrent workflows
5. Test timeout handling
6. Validate outputs and side effects
```

**Step 5: Deploy and Monitor**
```
1. Deploy to staging environment
2. Run smoke tests
3. Monitor error rates and latency
4. Gradually increase production traffic (blue-green)
5. Monitor metrics and user feedback
6. Adjust as needed based on real-world usage
```

For more detailed information, refer to:
- [AGENT_GUIDE.md](AGENT_GUIDE.md) - Agent capabilities and prompting
- [API_REFERENCE.md](API_REFERENCE.md) - API methods used in workflows
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common workflow issues
