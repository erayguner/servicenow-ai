# ServiceNow Bedrock Agents - Comprehensive Guide

## Table of Contents

1. [Incident Resolution Agent](#incident-resolution-agent)
2. [Change Coordination Agent](#change-coordination-agent)
3. [Knowledge Synchronizer Agent](#knowledge-synchronizer-agent)
4. [Prompt Engineering](#prompt-engineering)
5. [Best Practices](#best-practices)
6. [Performance Tuning](#performance-tuning)

## Incident Resolution Agent

### Overview

The Incident Resolution Agent autonomously analyzes IT incidents, determines
root causes, recommends solutions, and manages incident lifecycle in ServiceNow.

### Use Cases

1. **Automated Incident Triage**

   - New incidents automatically categorized and severity assessed
   - Appropriate resolver group assigned
   - Priority determined based on impact and urgency

2. **Knowledge Base Lookup**

   - Search KB articles matching incident symptoms
   - Provide solutions from known issues
   - Link incident to relevant documentation

3. **Root Cause Analysis**

   - Analyze incident description and error messages
   - Review historical incidents with similar patterns
   - Determine probable causes with confidence scores

4. **Resolution Automation**

   - Implement automated fixes when possible
   - Provide step-by-step troubleshooting procedures
   - Recommend escalation when needed

5. **Continuous Improvement**
   - Track resolution effectiveness
   - Update KB articles based on resolutions
   - Improve categorization accuracy over time

### Agent Configuration

```json
{
  "agent_name": "ServiceNow Incident Resolution Agent",
  "agent_description": "AI agent specialized in IT incident management",
  "model": "anthropic.claude-3-5-sonnet-20241022-v2:0",

  "instructions": {
    "primary_goal": "Efficiently resolve IT incidents by analyzing symptoms, searching knowledge bases, and recommending solutions",

    "capabilities": [
      "Analyze incident descriptions for patterns and root causes",
      "Search ServiceNow Knowledge Base for relevant articles",
      "Retrieve incident history for pattern matching",
      "Assess incident severity and urgency",
      "Recommend assignment and escalation paths",
      "Generate solution steps and workarounds",
      "Update incident records with findings"
    ],

    "constraints": [
      "Always verify information with reliable sources",
      "Don't close incidents without confirming resolution",
      "Escalate critical incidents to senior staff",
      "Maintain professional communication in all updates",
      "Protect sensitive customer information",
      "Document all analysis and recommendations"
    ],

    "tools": [
      {
        "name": "SearchIncidents",
        "description": "Search for incidents matching criteria"
      },
      {
        "name": "GetIncident",
        "description": "Retrieve specific incident details"
      },
      {
        "name": "UpdateIncident",
        "description": "Update incident fields and work notes"
      },
      {
        "name": "SearchKnowledgeBase",
        "description": "Search KB articles for solutions"
      },
      {
        "name": "GetKnowledgeArticle",
        "description": "Retrieve full KB article"
      },
      {
        "name": "AssignIncident",
        "description": "Assign incident to group or user"
      },
      {
        "name": "GetUser",
        "description": "Look up user information"
      },
      {
        "name": "CreateComment",
        "description": "Add work notes to incident"
      }
    ]
  },

  "session_configuration": {
    "memory_duration": "3600s",
    "context_window": "4096 tokens",
    "conversation_history": true
  }
}
```

### Prompt Templates

#### Initial Incident Analysis

```
You are analyzing a new IT incident in ServiceNow. Here's the incident information:

Incident Number: {incident_number}
Short Description: {short_description}
Full Description: {description}
Caller: {caller_name} ({caller_email})
Submitted Time: {created_time}
Priority: {priority}

Your task:
1. Analyze the description to identify key symptoms and error messages
2. Determine the most likely category and subcategory
3. Assess the impact (how many users/systems affected) and urgency (how quickly resolution is needed)
4. Search the knowledge base for similar incidents or known solutions
5. Provide an initial assessment with confidence level
6. Recommend next steps (assignment, escalation, workaround, etc.)

Format your response as:
- Key Symptoms: [list identified symptoms]
- Probable Root Causes: [causes with confidence %]
- Recommended Category: [category]
- Severity/Priority: [severity assessment]
- Relevant KB Articles: [article links]
- Recommended Solution: [if applicable]
- Recommended Assignment: [group/user]
- Next Steps: [step-by-step actions]
- Confidence Level: [0-100%]
```

#### Root Cause Analysis

```
Perform a detailed root cause analysis for this incident:

Incident: {incident_number}
Current Status: {current_status}
Error Messages: {error_logs}
Affected Systems: {affected_systems}
Recent Changes: {recent_changes}

Using the incident details and historical data, determine:
1. What is the actual failure point in the system?
2. What caused the failure? (direct cause)
3. Why did that cause occur? (underlying cause)
4. What conditions allowed this to happen? (root cause)
5. What can prevent recurrence? (preventive measures)

Format response as 5-Why Analysis showing the chain of causation.
```

#### Solution Recommendation

```
Based on your analysis of incident {incident_number}, provide detailed solution steps:

Current Symptoms: {symptoms}
Probable Cause: {root_cause}
Environment: {environment_details}

Provide:
1. Immediate workaround (if needed for quick relief)
2. Permanent solution steps (in order)
3. Prerequisites and preparation needed
4. Estimated time to complete
5. Rollback procedure if needed
6. Verification steps
7. Related preventive measures

Format as ordered steps with clear prerequisites and success criteria.
```

### Example Interaction

```
User: New incident created - "Database connection timeout errors"

Agent Response:
Analyzing incident INC0045231...

KEY FINDINGS:
- Symptoms: Database connections timing out, affecting 15 users
- Probable Cause: Database pool exhaustion (85% confidence)
- Relevant KB: Article KB0012345 - "Database Connection Pool Management"

RECOMMENDED ACTIONS:
1. Immediate: Increase connection pool size on DB02
2. Short-term: Restart affected services
3. Long-term: Review connection pool configuration
4. Prevention: Implement connection monitoring alerts

ASSIGNMENT: Database Team (db-support-group)
ESTIMATED RESOLUTION: 30 minutes
CONFIDENCE: High (85%)

Next: Assigning incident and notifying team...
```

## Change Coordination Agent

### Overview

The Change Coordination Agent manages the complete change request lifecycle,
from submission through implementation, including risk assessment, CAB
coordination, and rollback management.

### Use Cases

1. **Change Request Analysis**

   - Validate change request completeness
   - Extract key information (scope, impact, timeline)
   - Identify affected systems and configurations

2. **Risk Assessment**

   - Calculate risk score based on change type and scope
   - Identify potential impacts on services and users
   - Determine testing and CAB requirements

3. **CAB Coordination**

   - Automatically determine if CAB approval is required
   - Schedule CAB meetings and notifications
   - Summarize change for CAB review
   - Process CAB decisions

4. **Conflict Detection**

   - Check for conflicting changes in same time window
   - Identify resource conflicts
   - Recommend optimal scheduling

5. **Implementation Management**
   - Monitor change implementation progress
   - Handle escalations during implementation
   - Execute rollback if needed
   - Document outcomes

### Agent Configuration

```json
{
  "agent_name": "ServiceNow Change Coordination Agent",
  "agent_description": "Intelligent change request management and orchestration",
  "model": "anthropic.claude-3-5-sonnet-20241022-v2:0",

  "instructions": {
    "primary_goal": "Ensure successful, safe change implementation through intelligent analysis, coordination, and risk management",

    "capabilities": [
      "Analyze change request scope and impact",
      "Calculate change risk scores",
      "Determine testing and approval requirements",
      "Schedule changes in maintenance windows",
      "Coordinate with CAB and stakeholders",
      "Monitor implementation execution",
      "Handle rollback scenarios",
      "Track change success metrics"
    ],

    "constraints": [
      "Never approve high-risk changes without CAB review",
      "Maintain change blackout windows (no changes during critical hours)",
      "Ensure proper testing documentation before implementation",
      "Document rollback procedures before change execution",
      "Notify all stakeholders of schedule changes",
      "Preserve audit trail for compliance"
    ],

    "tools": [
      {
        "name": "GetChangeRequest",
        "description": "Retrieve change request details"
      },
      {
        "name": "UpdateChangeRequest",
        "description": "Update change request status and fields"
      },
      {
        "name": "SearchConfigItems",
        "description": "Find affected configuration items"
      },
      {
        "name": "ScheduleCABMeeting",
        "description": "Schedule CAB review meeting"
      },
      {
        "name": "NotifyStakeholders",
        "description": "Send notifications to change stakeholders"
      },
      {
        "name": "CreateChangeTask",
        "description": "Create subtasks for change implementation"
      },
      {
        "name": "SearchConflictingChanges",
        "description": "Find changes in same time window"
      },
      {
        "name": "ExecuteRollback",
        "description": "Execute change rollback"
      }
    ]
  }
}
```

### Prompt Templates

#### Change Risk Assessment

```
Perform a comprehensive risk assessment for this change request:

Change Number: {change_number}
Type: {change_type} (standard/normal/emergency)
Description: {description}
Scope: {scope}
Affected Systems: {affected_systems}
Affected Users: {affected_user_count}
Implementation Date: {implementation_date}
Recent Similar Changes: {similar_changes}

Assess risk across these dimensions:
1. Technical Risk (1-10): Complexity, testing level, rollback feasibility
2. Business Risk (1-10): User impact, revenue impact, customer impact
3. Operational Risk (1-10): Resource availability, skill level, experience
4. Schedule Risk (1-10): Timeline pressure, dependencies, window constraints

Calculate overall risk score (1-100) and recommend:
- CAB approval required (yes/no)
- Testing level (unit/system/UAT/all)
- Rollback plan required (yes/no)
- Change window size
- Notification requirements
```

#### CAB Preparation

```
Prepare change {change_number} for CAB review:

Change Details:
- Title: {title}
- Business Justification: {justification}
- Scope: {scope}
- Affected Systems: {affected_systems}
- Timeline: {timeline}
- Risks: {identified_risks}
- Mitigation: {mitigation_plans}
- Rollback Plan: {rollback_plan}

Create a comprehensive CAB summary including:
1. Executive Summary (1 paragraph)
2. Business Impact (positive and negative)
3. Technical Impact (systems and services affected)
4. Risk Assessment (with mitigations)
5. Testing Evidence (results, coverage %)
6. Rollback Procedure (detailed steps)
7. Success Criteria (how to verify success)
8. Communication Plan (notifications)
9. Estimated Duration (preparation + implementation + verification)
10. Questions for CAB (what approval/information needed)

Format for presentation to non-technical stakeholders.
```

#### Implementation Monitoring

```
Monitor the implementation of change {change_number}:

Current Status: {current_status}
Implementation Start: {start_time}
Planned Duration: {planned_duration}
Elapsed Time: {elapsed_time}
Progress: {completion_percentage}

Issues Reported:
{issues_list}

Your role:
1. Assess whether implementation is on track
2. Identify any problems or delays
3. Evaluate if rollback is necessary
4. Provide real-time recommendations
5. Notify stakeholders of status

Provide:
- Status Assessment: On Schedule / At Risk / Off Schedule
- Key Metrics: Progress %, Error Rate, User Impact
- Recommendations: Continue / Adjust / Rollback
- Next Actions: Specific steps to ensure success
- Stakeholder Communications: What to communicate and to whom
```

### Example Interaction

```
User: New change request for database upgrade

Agent Response:
Analyzing change CHG0098765...

CHANGE SUMMARY:
- Type: Normal (non-emergency)
- Scope: Production database server upgrade (DB02)
- Impact: 500+ users in Finance department
- Timeline: Scheduled for Sunday 2 AM-4 AM

RISK ASSESSMENT:
Technical Risk: 6/10 (tested, but complex upgrade)
Business Risk: 8/10 (affects financial processing)
Operational Risk: 5/10 (experienced team)
Overall Risk Score: 70/100 (MEDIUM-HIGH)

RECOMMENDATIONS:
✓ CAB Approval Required: YES
✓ Testing Level: Full system and UAT
✓ Rollback Plan: Required and documented
✓ Change Window: Approved
✓ Notifications: All Finance leaders + users

CAB MEETING SCHEDULED:
- Date: Friday, 2 PM
- Attendees: Finance Director, Database Manager, CTO
- Agenda: Risk review, testing results, rollback procedures

NEXT STEPS:
1. Confirm rollback procedure completeness
2. Brief Finance leadership on potential impact
3. Prepare communication for affected users
4. Schedule CAB meeting
5. Final approval from CAB before implementation
```

## Knowledge Synchronizer Agent

### Overview

The Knowledge Synchronizer Agent maintains the ServiceNow Knowledge Base by
creating articles from incident resolutions, consolidating duplicates,
optimizing content, and ensuring information currency.

### Use Cases

1. **Automatic KB Article Generation**

   - Create KB articles from closed incident resolutions
   - Include root cause, solution steps, and prevention
   - Apply appropriate metadata and categorization

2. **Content Quality Management**

   - Identify duplicate or outdated articles
   - Consolidate related content
   - Improve article structure and readability
   - Update stale articles with new information

3. **Intelligent Search Enhancement**

   - Improve article discoverability
   - Add keyword tags and synonyms
   - Implement multi-language support
   - Generate article summaries

4. **Knowledge Gap Identification**

   - Analyze search queries without results
   - Identify frequently searched topics not in KB
   - Recommend new article creation
   - Track coverage by system and topic

5. **Analytics and Insights**
   - Track KB article effectiveness
   - Measure impact on incident resolution time
   - Identify high-value articles
   - Monitor knowledge base health

### Agent Configuration

```json
{
  "agent_name": "ServiceNow Knowledge Synchronizer Agent",
  "agent_description": "Intelligent knowledge base management and optimization",
  "model": "anthropic.claude-3-5-sonnet-20241022-v2:0",

  "instructions": {
    "primary_goal": "Create, maintain, and optimize a comprehensive, high-quality knowledge base that accelerates incident resolution and improves user self-service",

    "capabilities": [
      "Generate KB articles from incident resolutions",
      "Identify and consolidate duplicate articles",
      "Optimize article content for search and usability",
      "Track article effectiveness metrics",
      "Identify knowledge gaps",
      "Manage article lifecycle (creation, update, retirement)",
      "Support multi-language translations",
      "Analyze user search patterns"
    ],

    "constraints": [
      "Ensure article accuracy before publication",
      "Maintain consistent formatting and structure",
      "Protect proprietary/sensitive information",
      "Cite sources and acknowledge SMEs",
      "Review articles for clarity and completeness",
      "Keep articles current with system changes"
    ],

    "tools": [
      {
        "name": "GetIncident",
        "description": "Retrieve incident details for KB generation"
      },
      {
        "name": "SearchKnowledgeBase",
        "description": "Search for duplicate or related articles"
      },
      {
        "name": "CreateKBArticle",
        "description": "Create new knowledge base article"
      },
      {
        "name": "UpdateKBArticle",
        "description": "Update existing KB article"
      },
      {
        "name": "GetKBArticleViews",
        "description": "Get article view/usefulness metrics"
      },
      {
        "name": "GetSearchAnalytics",
        "description": "Analyze user search patterns"
      },
      {
        "name": "CreateArticleMergeTask",
        "description": "Create task to merge duplicate articles"
      },
      {
        "name": "GetArticleComments",
        "description": "Get user feedback on articles"
      }
    ]
  }
}
```

### Prompt Templates

#### KB Article Generation from Incident

```
Create a knowledge base article from this resolved incident:

Incident Number: {incident_number}
Title: {short_description}
Root Cause: {root_cause}
Symptoms: {symptoms}
Solution: {solution_steps}
Prevention: {prevention_measures}
Resolver: {resolver_name}
Resolution Time: {resolution_time}
Similar Incidents: {similar_incident_count}

Generate a comprehensive KB article including:

1. TITLE: Concise, searchable title (e.g., "Resolve Database Connection Timeout Errors")

2. SUMMARY: One-paragraph overview of the issue and solution

3. SYMPTOMS: List of symptoms users experience
   - Symptom 1
   - Symptom 2
   - etc.

4. ROOT CAUSE: Explanation of why this problem occurs

5. SOLUTION: Step-by-step resolution procedure
   - Step 1: [prerequisites]
   - Step 2: [action]
   - Step 3: [verification]
   - etc.

6. PREVENTION: How to prevent this issue
   - Preventive measure 1
   - Preventive measure 2
   - etc.

7. RELATED ARTICLES: References to related KB articles

8. AFFECTED SYSTEMS: List of systems/components

9. KEYWORDS/TAGS: Search keywords and categories

10. LAST UPDATED: [today's date]

Ensure the article is:
- Clear and accessible to non-technical users
- Properly formatted with headers and lists
- Complete with all necessary information
- Free of jargon or with jargon explained
- Optimized for search and discoverability
```

#### Duplicate Article Detection and Consolidation

```
Analyze these articles for duplication:

Article 1: {article1_title}
Content: {article1_content}
Views: {article1_views}

Article 2: {article2_title}
Content: {article2_content}
Views: {article2_views}

Assess:
1. Are these articles covering the same topic? (yes/no/partially)
2. What is the overlap percentage (0-100%)?
3. Which article is more comprehensive/useful?
4. Should they be consolidated? (yes/no/revise separately)

If consolidation recommended:
- Merged Title: [new title]
- Merged Content: [consolidated content]
- Retirement Status: Which article to retire
- Redirect: Create redirect from old to new URL

Provide specific recommendations for improvement.
```

#### Knowledge Gap Analysis

```
Analyze search logs to identify knowledge gaps:

Top Searches Without Results:
1. {search_query_1} (frequency: {count})
2. {search_query_2} (frequency: {count})
3. {search_query_3} (frequency: {count})

Low-Satisfaction Articles:
1. {article_title} (satisfaction: {score}%)
2. {article_title} (satisfaction: {score}%)

Common Escalations by Topic:
1. {topic} ({count} incidents)
2. {topic} ({count} incidents)

Recommendations:
1. HIGH PRIORITY - Create articles for:
   [Specific article recommendations with outline]

2. MEDIUM PRIORITY - Update articles for:
   [Specific improvement recommendations]

3. METRICS:
   - Current KB coverage: {coverage_percent}%
   - Articles needed: {number}
   - Estimated impact: {impact_description}
   - ROI: {roi_estimate}
```

### Example Interaction

```
User: Incident INC0089234 resolved - "Email sync failures in Outlook"

Agent Response:
Analyzing incident for KB article creation...

INCIDENT ANALYSIS:
- Issue: Outlook email sync failures after Office 365 migration
- Root Cause: Incorrect OAuth configuration on client machines
- Resolution: Update registry key and reconfigure Outlook
- Similar Incidents: Found 12 similar incidents in past 6 months

ARTICLE CREATION:
Title: "Fix Outlook Email Sync Failures After Office 365 Migration"

✓ Article generated with:
  - Clear symptoms and root cause
  - Step-by-step solution (8 steps)
  - Prevention measures
  - Affected system: Email & Collaboration
  - Keywords: Outlook, Office365, sync, email, migration

DUPLICATE CHECK:
- Found existing article KB0056789 "Office 365 Migration Troubleshooting"
- 40% content overlap detected
- Recommendation: Merge as subsection in KB0056789

ACTION TAKEN:
1. Created new article KB0090234
2. Cross-linked with KB0056789
3. Added to FAQ section
4. Scheduled article review in 30 days
5. Set up effectiveness tracking

IMPACT ESTIMATE:
- Based on similar incidents: Potential to resolve 15+ similar incidents
- Estimated time savings: 2-3 hours per incident
- Estimated annual impact: 30-45 hours reduced resolution time
```

## Prompt Engineering

### Best Practices

1. **Be Specific**

   ```
   ✓ Good: "Search for incidents in the last 7 days with status 'Open' or 'In Progress' and priority 1 or 2"
   ✗ Bad: "Find recent incidents"
   ```

2. **Provide Context**

   ```
   ✓ Good: "This is for a financial services company, so include compliance considerations"
   ✗ Bad: "Analyze the problem"
   ```

3. **Use Clear Structure**

   ```
   ✓ Good:
     Task: [Clear objective]
     Context: [Background information]
     Constraints: [Limitations]
     Output Format: [Expected format]

   ✗ Bad: "Do something useful"
   ```

4. **Include Examples**
   ```
   ✓ Good: "Provide recommendations like '1) Restart service 2) Clear cache 3) Check logs'"
   ✗ Bad: "Give recommendations"
   ```

### Advanced Techniques

1. **Chain-of-Thought Prompting**

   ```
   "Think step-by-step through this problem. First identify the symptoms, then consider
   root causes, then propose solutions, and finally recommend prevention measures."
   ```

2. **Role-Based Prompting**

   ```
   "You are a senior incident manager with 10 years of IT experience. Analyze this
   incident and provide your professional assessment."
   ```

3. **Few-Shot Prompting**
   ```
   "Here are examples of well-categorized incidents:
    Example 1: [incident + category]
    Example 2: [incident + category]
    Now categorize this incident: [new incident]"
   ```

## Best Practices

### For Incident Resolution Agent

1. **Always search KB first** before proposing custom solutions
2. **Provide confidence levels** for all recommendations
3. **Document rationale** for all assignments and severity levels
4. **Create work notes** explaining analysis to support team
5. **Track metrics** (time to triage, resolution rate, accuracy)

### For Change Coordination Agent

1. **Enforce change windows** - never approve out-of-window changes
2. **Require testing evidence** for all production changes
3. **Maintain rollback plans** in ready state before implementation
4. **Communicate early** to all affected stakeholders
5. **Track change success** metrics for process improvement

### For Knowledge Synchronizer Agent

1. **Verify accuracy** before KB publication
2. **Review for clarity** to ensure non-technical users understand
3. **Link related articles** for better navigation
4. **Update regularly** (review and refresh quarterly)
5. **Monitor effectiveness** and refine based on metrics

## Performance Tuning

### Optimization Strategies

1. **Caching**

   - Cache incident category rules (1-hour TTL)
   - Cache user/group information (24-hour TTL)
   - Cache KB search results (1-hour TTL)
   - Result: 40-60% API call reduction

2. **Batch Processing**

   - Group similar incidents for analysis
   - Process changes in daily batches
   - Generate KB articles in weekly batches
   - Result: 30% improved throughput

3. **Parallel Execution**

   - Run KB search while categorizing incident
   - Analyze multiple aspects simultaneously
   - Execute independent tasks in parallel
   - Result: 25% faster response times

4. **Model Selection**
   - Claude 3.5 Sonnet: Complex analysis (incident RCA, risk assessment)
   - Claude 3 Haiku: Simple categorization, KB lookup
   - Claude 3 Opus: Critical decisions, CAB analysis
   - Result: Optimized cost and latency

### Monitoring Performance

```bash
# Key metrics to track
- Average agent response time
- Cost per invocation
- Error rate
- Incidents resolved without escalation
- Change success rate
- KB article effectiveness (view count, helpfulness rating)

# Alerts to configure
- Response time > 30 seconds
- Error rate > 2%
- Cost per invocation > $0.50
- Change rollback rate > 5%
```

## Advanced Agent Patterns

### Multi-Agent Collaboration

```
Scenario: Complex incident requiring multiple agent perspectives

Flow:
1. Incident Resolution Agent analyzes and categorizes incident
2. Passes context to Incident Agent for deeper RCA
3. If change-related: notifies Change Coordination Agent
4. Knowledge Synchronizer creates KB article from resolution
5. All agents update their respective records
```

### Agent-to-Human Handoff

```
When Agent Should Escalate to Human:
1. Confidence level falls below threshold (60%)
2. Change requires CAB approval with unclear recommendation
3. Incident has potential compliance implications
4. Multiple conflicting KB articles found
5. User explicitly requests human assistance

Handoff Process:
1. Agent documents findings and recommendations
2. Agent creates ticket for appropriate team
3. Agent provides context to incoming agent/human
4. Agent monitors resolution and learns for future
```

For more details on workflows, see [WORKFLOWS.md](WORKFLOWS.md). For API
details, see [API_REFERENCE.md](API_REFERENCE.md). For troubleshooting, see
[TROUBLESHOOTING.md](TROUBLESHOOTING.md).
