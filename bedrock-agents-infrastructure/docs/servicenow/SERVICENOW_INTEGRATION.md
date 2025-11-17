# ServiceNow + Amazon Bedrock Integration

## Overview

This document provides a comprehensive guide to the ServiceNow and Amazon Bedrock integration, enabling intelligent automation, AI-powered agents, and advanced orchestration for enterprise IT service management workflows.

The integration leverages AWS Lambda, Amazon Bedrock Foundation Models, and ServiceNow REST APIs to create a powerful ecosystem of intelligent agents that handle incident management, change requests, knowledge base synchronization, and complex IT operations workflows.

## Architecture Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        ServiceNow Instance                              │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                                                                  │  │
│  │  Incident Management  │  Change Mgmt  │  Knowledge Base         │  │
│  │     Records          │   Requests     │  Articles              │  │
│  │                                                                  │  │
│  └──────────────┬───────────────────────────────────┬──────────────┘  │
└─────────────────┼───────────────────────────────────┼──────────────────┘
                  │                                   │
                  │  HTTP/REST APIs                   │
                  │  (Incident, Change, KB APIs)      │
                  ▼                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                   AWS Lambda Service Layer                              │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                                                                  │  │
│  │  API Gateway → Lambda Functions ← API Gateway                   │  │
│  │                                                                  │  │
│  │  • ServiceNow Request Handler   • Bedrock Integration Layer     │  │
│  │  • Agent Coordinator            • Response Formatter            │  │
│  │  • Error Handler                • Webhook Manager               │  │
│  │                                                                  │  │
│  └──────────────┬───────────────────────────────────┬──────────────┘  │
└─────────────────┼───────────────────────────────────┼──────────────────┘
                  │                                   │
                  │  Agent Invocation                 │  API Calls
                  │  (JSON Protocol)                  │  (REST)
                  ▼                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    Amazon Bedrock Agents                                │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                                                                  │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │  │
│  │  │  Incident    │  │  Change      │  │  Knowledge   │           │  │
│  │  │  Resolution  │  │  Coordinator │  │  Synchronizer│           │  │
│  │  │  Agent       │  │  Agent       │  │  Agent       │           │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘           │  │
│  │                                                                  │  │
│  │  Foundation Models:                                             │  │
│  │  • Claude 3.5 Sonnet (Primary reasoning)                        │  │
│  │  • Claude 3 Haiku (Fast processing)                             │  │
│  │  • Claude 3 Opus (Complex analysis)                             │  │
│  │                                                                  │  │
│  └──────────────┬───────────────────────────────────┬──────────────┘  │
└─────────────────┼───────────────────────────────────┼──────────────────┘
                  │                                   │
                  │  Knowledge Base Access            │  Tool Invocation
                  ▼                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│              Supporting AWS Services                                    │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                                                                  │  │
│  │  • Knowledge Base (Enterprise docs/troubleshooting guides)       │  │
│  │  • Secrets Manager (API credentials, tokens)                    │  │
│  │  • DynamoDB (Session state, agent memory)                       │  │
│  │  • CloudWatch (Logging, monitoring, metrics)                    │  │
│  │  • SNS/SQS (Event notifications, queue management)              │  │
│  │  • IAM (Service authentication, role-based access)              │  │
│  │  • VPC Endpoints (Secure connectivity to ServiceNow)            │  │
│  │                                                                  │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

## Core Integration Components

### 1. ServiceNow Connector Layer

The connector layer handles all communication with ServiceNow and includes:

- **RESTful API Integration**: Direct REST API calls to ServiceNow's incident, change, and knowledge base tables
- **Authentication**: OAuth 2.0 and Basic Auth support with secure credential management via AWS Secrets Manager
- **Request Validation**: Ensures compliance with ServiceNow data models and constraints
- **Error Handling**: Graceful handling of API errors with retry logic and circuit breaking
- **Rate Limiting**: Respects ServiceNow API rate limits and implements exponential backoff

### 2. Agent Orchestration Framework

Three primary agents handle different aspects of IT service management:

#### Incident Resolution Agent
- **Purpose**: Autonomously analyze and resolve IT incidents
- **Capabilities**:
  - Automatic incident categorization and severity assessment
  - Root cause analysis using knowledge bases and incident history
  - Intelligent ticket assignment to appropriate teams
  - Resolution recommendations based on past incidents
  - Automatic status updates and notifications
- **Integration Points**: Incident Management module, Knowledge Base
- **Decision Models**: Reasoning engine for incident analysis

#### Change Coordination Agent
- **Purpose**: Manage and coordinate change requests with minimal human intervention
- **Capabilities**:
  - Change request analysis and risk assessment
  - Impact analysis on business systems
  - CAB (Change Advisory Board) recommendation automation
  - Schedule optimization and conflict detection
  - Change implementation tracking and rollback planning
- **Integration Points**: Change Management module, Incident Management, Configuration Items
- **Decision Models**: Risk scoring and impact analysis algorithms

#### Knowledge Synchronizer Agent
- **Purpose**: Maintain and synchronize knowledge base articles with operational data
- **Capabilities**:
  - Automatic KB article generation from incident resolutions
  - Content deduplication and optimization
  - Relevance scoring for search and discovery
  - Multi-language translation and localization
  - Automatic KB search for incident resolution assistance
- **Integration Points**: Knowledge Base module, Incident Management
- **Decision Models**: Content relevance and quality scoring

### 3. Action Handlers and Tools

Each agent has access to specific tools for executing ServiceNow operations:

```
Agent → Tool Registry → ServiceNow API
  ├── ServiceNowClient (connection management)
  ├── IncidentTools (create, update, search incidents)
  ├── ChangeTools (manage change requests)
  ├── KnowledgeTools (KB article CRUD)
  ├── UserTools (lookup users, teams, roles)
  ├── ConfigurationTools (retrieve CMDB data)
  └── ReportingTools (generate insights and metrics)
```

## Agent Descriptions and Capabilities

### Incident Resolution Agent

**Primary Role**: Autonomous incident triage, analysis, and resolution

**Key Capabilities**:

1. **Intelligent Categorization**
   - Analyzes incident description, symptoms, and error logs
   - Matches against historical incident patterns
   - Assigns appropriate category and subcategory
   - Determines urgency and impact levels

2. **Root Cause Analysis (RCA)**
   - Searches knowledge base for related articles
   - Reviews historical incidents with similar symptoms
   - Uses inference engine to determine probable causes
   - Provides confidence scores for each potential cause

3. **Resolution Recommendation**
   - Proposes step-by-step troubleshooting procedures
   - Suggests workarounds and permanent fixes
   - Provides estimated resolution time based on similar incidents
   - Offers escalation path if needed

4. **Automatic Actions**
   - Updates incident status and adds work notes
   - Assigns tickets to optimal resolver group
   - Sends automated notifications to relevant stakeholders
   - Closes resolved incidents with root cause documentation

**Integration Triggers**:
- New incident created in ServiceNow
- Incident status changes (new → assigned → in progress)
- Manual escalation requested by user
- Scheduled batch processing of unresolved incidents

### Change Coordination Agent

**Primary Role**: Intelligent change request management and orchestration

**Key Capabilities**:

1. **Change Request Analysis**
   - Reviews change description, justification, and scope
   - Identifies affected systems and configurations
   - Determines change type (standard, normal, emergency)
   - Assesses resource requirements

2. **Risk Assessment**
   - Calculates risk score based on change type, scope, and history
   - Identifies potential impacts on services and users
   - Recommends testing requirements
   - Suggests rollback procedures

3. **CAB Automation**
   - Determines if CAB approval is required
   - Automatically schedules CAB review if needed
   - Provides stakeholder recommendations
   - Processes CAB decisions and communicates outcomes

4. **Implementation Orchestration**
   - Schedules change within maintenance windows
   - Coordinates with related changes to avoid conflicts
   - Monitors implementation progress
   - Handles rollback execution if needed

**Integration Triggers**:
- New change request submitted
- Change request status updates
- CAB meeting scheduled
- Change implementation phase initiated

### Knowledge Synchronizer Agent

**Primary Role**: Maintain dynamic, intelligent knowledge base

**Key Capabilities**:

1. **KB Article Generation**
   - Creates articles from closed incident resolutions
   - Includes root cause, solution, and prevention steps
   - Formats content for readability and search optimization
   - Applies appropriate metadata and tags

2. **Content Quality Management**
   - Identifies duplicate or outdated articles
   - Recommends article consolidation
   - Suggests improvements to existing content
   - Maintains article freshness and relevance

3. **Intelligent Search Enhancement**
   - Improves article discoverability with better indexing
   - Suggests related articles based on incident context
   - Provides multi-language search support
   - Generates article summaries and quick references

4. **Analytics and Insights**
   - Tracks KB article effectiveness (resolution rate improvement)
   - Identifies knowledge gaps (frequently searched, not found)
   - Provides usage trends and insights
   - Recommends new articles based on incident patterns

**Integration Triggers**:
- Incident resolution completed
- KB article search performed without results
- Scheduled KB maintenance and optimization
- Content quality review cycle

## Workflow Architecture

### Primary Workflows

#### 1. Incident Resolution Workflow

```
New Incident Created
    ↓
[Incident Resolution Agent Triggered]
    ├── Extract incident data (description, symptoms, environment)
    ├── Search KB for similar issues
    ├── Retrieve related incident history
    ├── Analyze root causes
    └─→ [Categorization & Severity Assignment]
         ├── Auto-assign to resolver group
         ├── Update incident category/subcategory
         ├── Set priority based on impact
         └─→ [Resolution Recommendation]
              ├── Propose troubleshooting steps
              ├── Add diagnostic commands
              ├── Calculate estimated resolution time
              ├── Update incident work notes
              └─→ [Monitor & Close]
                   ├── Track progress
                   ├── Provide status updates
                   ├── Close on resolution
                   └── Generate KB article from solution
```

#### 2. Change Request Workflow

```
Change Request Submitted
    ↓
[Change Coordination Agent Triggered]
    ├── Validate change request data
    ├── Analyze scope and impact
    ├── Identify affected CIs
    └─→ [Risk Assessment]
         ├── Calculate risk score
         ├── Determine testing requirements
         ├── Identify rollback procedures
         └─→ [CAB Determination]
              ├── Check if CAB approval needed
              ├── Schedule CAB meeting if required
              ├── Notify stakeholders
              └─→ [Implementation Planning]
                   ├── Schedule within maintenance window
                   ├── Coordinate with other changes
                   ├── Prepare runbooks
                   └─→ [Execution & Monitoring]
                        ├── Monitor implementation
                        ├── Execute rollback if needed
                        ├── Communicate outcomes
                        └── Close change request
```

#### 3. Knowledge Base Synchronization Workflow

```
Incident Resolution Completed / Manual Trigger
    ↓
[Knowledge Synchronizer Agent Triggered]
    ├── Retrieve incident resolution details
    ├── Check for existing related KB articles
    ├── Analyze resolution for KB-worthy content
    └─→ [Content Generation]
         ├── Generate structured article
         ├── Format for readability
         ├── Apply metadata and tags
         └─→ [Deduplication & Quality Check]
              ├── Compare with existing articles
              ├── Suggest consolidations
              ├── Review for accuracy
              └─→ [Publishing]
                   ├── Add to KB
                   ├── Index for search
                   ├── Distribute notifications
                   └── Track effectiveness

Scheduled Maintenance / Manual Request
    ↓
[Knowledge Synchronizer Agent Triggered]
    ├── Analyze KB health metrics
    ├── Identify gaps and outdated content
    ├── Review search analytics
    └─→ [Content Optimization]
         ├── Consolidate duplicates
         ├── Update stale articles
         ├── Improve search indexing
         └── Recommend new articles
```

## Authentication and Security

### ServiceNow Authentication Methods

#### OAuth 2.0 (Recommended)
```
1. ServiceNow admin registers AWS Lambda function as OAuth client
2. Client ID and Client Secret stored in AWS Secrets Manager
3. Lambda obtains access token using client credentials grant
4. Access token used for authenticated API calls
5. Tokens automatically refreshed before expiration
```

**Configuration Steps**:
- Navigate to ServiceNow: System OAuth > Application Registry
- Create new application with "OAuth 2.0 Authorization Code" grant type
- Provide Lambda's callback URL (API Gateway endpoint)
- Store Client ID and Secret in Secrets Manager
- Configure Lambda execution role to access secrets

#### Basic Authentication (Alternative)
```
1. Create dedicated ServiceNow user account
2. Generate API token or use password (not recommended)
3. Store credentials in AWS Secrets Manager
4. Lambda includes base64-encoded credentials in Authorization header
```

**Configuration Steps**:
- Create service account in ServiceNow with minimal required roles
- Generate API token: User Profile > Reset API Token
- Store in Secrets Manager as JSON: {"username": "...", "password": "..."}
- Configure Lambda to base64-encode credentials

### Security Best Practices

1. **Credential Management**
   - Never hardcode credentials in code or Lambda environment variables
   - Use AWS Secrets Manager with automatic rotation
   - Implement least-privilege IAM roles for Lambda functions
   - Audit credential access via CloudTrail

2. **API Security**
   - Use VPC endpoints for private connectivity to ServiceNow
   - Implement request signing with AWS Signature Version 4
   - Enable HTTPS/TLS for all API communications
   - Validate SSL certificates

3. **Data Protection**
   - Encrypt sensitive data at rest in DynamoDB and S3
   - Use KMS keys for encryption management
   - Implement field-level encryption for PII
   - Mask sensitive data in logs

4. **Access Control**
   - Implement IAM roles with least-privilege permissions
   - Use resource-based policies to restrict Lambda invocation
   - Enable API Gateway authentication and authorization
   - Implement rate limiting and DDoS protection

## API Configuration and Endpoints

### ServiceNow API Base Configuration

```
Base URL: https://{instance}.service-now.com/api/now/

Query Parameters:
  - sysparm_limit: Maximum records to return (default 10, max 10000)
  - sysparm_offset: Record offset for pagination (default 0)
  - sysparm_fields: Comma-separated list of fields to return
  - sysparm_exclude_reference_link: Exclude reference links (true/false)
  - sysparm_suppress_pagination_header: Suppress pagination header (true/false)
  - sysparm_query_no_domain: Query without domain scoping (true/false)

Response Headers:
  - X-Total-Count: Total records matching query
  - Link: Pagination links (first, last, next, previous)
  - RateLimit-Limit: API rate limit
  - RateLimit-Remaining: Remaining API calls
  - RateLimit-Reset: When rate limit resets
```

### Core Endpoints

#### Incident Management

```
GET /table/incident
  Description: Retrieve incidents
  Query Example: ?sysparm_limit=100&sysparm_fields=number,short_description,state
  Response: List of incident records

POST /table/incident
  Description: Create new incident
  Request Body: {"short_description": "...", "description": "..."}
  Response: Created incident with sys_id

PATCH /table/incident/{sys_id}
  Description: Update incident
  Request Body: {"state": "in_progress", "assigned_to": "..."}
  Response: Updated incident

GET /table/incident/{sys_id}
  Description: Get specific incident
  Response: Complete incident record

DELETE /table/incident/{sys_id}
  Description: Delete incident (typically not used, prefer state changes)
  Response: Success confirmation
```

#### Change Request Management

```
GET /table/change_request
  Description: Retrieve change requests
  Query Example: ?sysparm_limit=50&sysparm_fields=number,type,risk,state

POST /table/change_request
  Description: Create new change request
  Request Body: {"type": "standard", "short_description": "...", "description": "..."}

PATCH /table/change_request/{sys_id}
  Description: Update change request status and details
  Request Body: {"state": "implement", "implementation_comments": "..."}

GET /table/change_request/{sys_id}/change_tasks
  Description: Get change tasks for specific change
  Response: List of associated tasks

POST /table/change_task
  Description: Create change task (subtask)
  Request Body: {"change_request": "{sys_id}", "title": "...", "description": "..."}
```

#### Knowledge Base Operations

```
GET /table/kb_knowledge
  Description: Retrieve KB articles
  Query Example: ?sysparm_limit=20&sysparm_fields=number,short_description,text

POST /table/kb_knowledge
  Description: Create new KB article
  Request Body: {
    "short_description": "...",
    "text": "...",
    "category": "...",
    "kb_category": "..."
  }

PATCH /table/kb_knowledge/{sys_id}
  Description: Update KB article
  Request Body: {"text": "...", "status": "published"}

GET /table/kb_knowledge?sysparm_query=CONTAINS(text,'{search_term}')
  Description: Search KB articles
  Response: Matching articles ranked by relevance
```

#### Additional Resources

```
GET /table/sys_user
  Description: User lookup (name, email, role)

GET /table/cmdb_ci
  Description: Configuration item lookup

GET /table/sys_user_group
  Description: Team/group lookup

GET /table/assignment_rule
  Description: Assignment rule configuration

GET /table/user_criteria
  Description: User assignment criteria

POST /table/sys_user_has_role
  Description: Grant role to user
```

### Advanced Query Options

#### Filtering Examples

```
GET /table/incident?sysparm_query=ORDERBYstate^ORDERBYnumber
  Returns: Incidents ordered by state, then number

GET /table/incident?sysparm_query=state=1^ORDERBYDESCcreated_on
  Returns: New incidents, most recently created first

GET /table/incident?sysparm_query=assignmentNOT EMPTY^state=2
  Returns: Assigned incidents in progress

GET /table/incident?sysparm_query=priorityLIKE1^ORpriority LIKE 2
  Returns: High and medium priority incidents

GET /table/incident?sysparm_query=created_on>=javascript:gs.dateAdd(new GlideDateTime(),'days',-7)
  Returns: Incidents created in last 7 days
```

#### Field Manipulation

```
GET /table/incident?sysparm_fields=number,short_description,caller_id.name,assigned_to.email
  Returns: Selected fields including referenced field values

GET /table/incident?sysparm_exclude_reference_link=true
  Returns: Records without reference links (reduces payload)

GET /table/incident?sysparm_display_value=all
  Returns: Display values instead of system IDs
```

## Integration Patterns

### Pattern 1: Event-Driven Automation

ServiceNow events trigger Lambda functions which invoke agents:

```
Incident Created → ServiceNow Business Rule → HTTP POST to API Gateway
    ↓
API Gateway → Lambda Function → Invoke Bedrock Agent
    ↓
Agent analyzes incident → Updates incident in ServiceNow
```

### Pattern 2: Batch Processing

Scheduled Lambda execution processes queued items:

```
CloudWatch Events (Scheduled) → Lambda Function
    ↓
Retrieve pending items from ServiceNow
    ↓
Invoke Bedrock Agent for each item
    ↓
Update ServiceNow with results
    ↓
Store session state in DynamoDB
```

### Pattern 3: Interactive Chat/Chatbot

Users interact with agents through ServiceNow chat interface:

```
ServiceNow Chat Widget → API Gateway → Lambda Function
    ↓
Maintain conversation context in DynamoDB
    ↓
Invoke Bedrock Agent with conversation history
    ↓
Return agent response to chat widget
```

## Monitoring and Observability

### CloudWatch Metrics

```
Custom Metrics:
  - AgentInvocationCount: Number of times agents are invoked
  - AverageAgentLatency: Average response time
  - AgentErrorRate: Percentage of failed invocations
  - ServiceNowAPICallCount: Total API calls to ServiceNow
  - ServiceNowAPIErrorRate: API error rate
  - IncidentResolutionTime: Average time to resolve incidents
  - ChangeSuccessRate: Percentage of successful changes

Standard Lambda Metrics:
  - Duration: Lambda execution time
  - Errors: Failed invocations
  - Throttles: Throttled invocations
  - ConcurrentExecutions: Concurrent function executions
```

### CloudWatch Logs

```
Log Groups:
  /aws/lambda/servicenow-incident-agent
  /aws/lambda/servicenow-change-agent
  /aws/lambda/servicenow-kb-agent
  /aws/bedrock/agent-executions

Log Levels:
  DEBUG: Detailed execution flow, API calls, responses
  INFO: Agent invocations, major decision points
  WARN: Non-critical issues, fallbacks used
  ERROR: Failures, exceptions, retries
```

### Dashboards

Create CloudWatch dashboards to visualize:
- Agent invocation trends
- Error rates and types
- API latency and error distribution
- Success metrics by agent type
- Knowledge base coverage and growth
- Change success and rollback rates

## Performance Considerations

### Lambda Configuration

```
Memory: 512 MB to 3008 MB
  - Incident Agent: 1024 MB (moderate processing)
  - Change Agent: 1024 MB (moderate processing)
  - KB Agent: 512 MB (lightweight)
  - Coordinator: 512 MB (orchestration)

Timeout: 300 seconds (5 minutes) for most operations
  - Long-running processes: 900 seconds
  - Batch operations: 600 seconds

Concurrency: On-demand

Environment Variables:
  SERVICENOW_INSTANCE: https://your-instance.service-now.com
  SERVICENOW_TABLE_INCIDENT: incident
  SERVICENOW_TABLE_CHANGE: change_request
  SERVICENOW_TABLE_KB: kb_knowledge
  BEDROCK_REGION: us-east-1
  BEDROCK_MODEL_ID: anthropic.claude-3-5-sonnet-20241022-v2:0
```

### Caching Strategies

```
ServiceNow Data Cache (DynamoDB):
  - Cache incident categorization rules (1 hour TTL)
  - Cache user/group information (24 hour TTL)
  - Cache KB article metadata (1 hour TTL)
  - Cache assignment rules (24 hour TTL)

Bedrock Response Caching:
  - Cache resolution recommendations for similar incidents
  - Cache change risk assessments
  - Cache KB article generation templates

Optimization Benefits:
  - 40-60% reduction in API calls
  - 30-50% faster agent response times
  - Reduced costs (fewer Bedrock invocations)
```

## Error Handling and Resilience

### Retry Logic

```
Transient Errors (retry with exponential backoff):
  - HTTP 429 (Rate Limited): Wait 30s, 60s, 120s, 300s
  - HTTP 502/503 (Temporary unavailable): Same backoff
  - Timeout errors: Retry up to 3 times

Permanent Errors (fail fast):
  - HTTP 401/403 (Authentication/Authorization)
  - HTTP 400 (Bad Request)
  - HTTP 404 (Not Found)
  - Invalid data format
```

### Circuit Breaker Pattern

```
States:
  - CLOSED: Normal operation, requests proceed
  - OPEN: Too many failures, fast-fail without calling service
  - HALF_OPEN: Test single request to check service recovery

Configuration:
  - Failure threshold: 50% of requests
  - Success threshold: 2 consecutive successes in HALF_OPEN
  - Timeout: 60 seconds before attempting HALF_OPEN
```

### Graceful Degradation

```
If ServiceNow API unavailable:
  - Use cached data for read operations
  - Queue write operations for retry
  - Notify users of delays
  - Suggest manual alternatives

If Bedrock unavailable:
  - Fall back to rule-based recommendations
  - Use historical data for suggestions
  - Return partial results with known solutions
  - Escalate to human agents
```

## Data Privacy and Compliance

### Data Classification

```
Public: Incident numbers, general status
Internal: Descriptions, resolution steps, KB articles
Confidential: User emails, system configurations
Restricted: Customer data, financial information
```

### GDPR/CCPA Compliance

```
Data Retention:
  - Incident data: 7 years (legal hold)
  - Change data: 7 years
  - Session logs: 90 days
  - PII: Minimum required for service

Data Deletion:
  - Automatic deletion after retention period
  - User-initiated deletion request handling
  - Audit trail of deletions
```

## Conclusion

The ServiceNow and Amazon Bedrock integration provides a powerful foundation for intelligent IT service management automation. By combining ServiceNow's industry-leading ITSM platform with AWS's advanced AI capabilities, organizations can achieve:

- Faster incident resolution
- Improved change success rates
- Enhanced knowledge sharing
- Reduced operational costs
- Better user experience
- Data-driven decision making

This documentation serves as the foundation for implementing and maintaining this integration. Refer to the deployment guide for step-by-step setup instructions and the troubleshooting guide for common issues and solutions.
