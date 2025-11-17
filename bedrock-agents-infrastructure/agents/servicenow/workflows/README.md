# ServiceNow Step Functions Workflows

Comprehensive AWS Step Functions workflows for automating ServiceNow IT Service Management operations with Amazon Bedrock agents.

## Overview

This directory contains 6 production-ready Step Functions workflows that integrate ServiceNow with AWS Bedrock agents for intelligent automation of ITSM processes.

### Directory Structure

```
workflows/
├── incident-response-workflow.json        # Automated incident handling
├── ticket-triage-workflow.json             # Intelligent ticket routing
├── change-approval-workflow.json           # Risk-based change approval
├── problem-investigation-workflow.json     # Root cause analysis & KB creation
├── knowledge-creation-workflow.json        # Auto KB article generation
├── sla-monitoring-workflow.json            # SLA breach prevention
└── README.md                               # This file
```

## Workflows

### 1. Incident Response Workflow

**File**: `incident-response-workflow.json`

**Purpose**: Automated incident handling with severity analysis and intelligent escalation

**Features**:
- Receives incidents from ServiceNow webhooks
- Invokes Bedrock Incident Manager agent for analysis
- Analyzes incident severity (Critical, High, Medium, Low)
- Auto-escalates critical incidents with parallel actions
- Updates ServiceNow and notifies stakeholders
- Monitors critical incidents until resolution

**Key States**:
- `ReceiveIncidentWebhook` - Receive and store incident
- `InvokeIncidentManagerAgent` - AI-powered incident analysis
- `AnalyzeSeverity` - Route based on impact level
- `CriticalIncidentPath` - Parallel escalation and monitoring
- `MonitorCriticalIncident` - 5-minute recurring checks

**Input Schema**:
```json
{
  "incident": {
    "sys_id": "INC0123456",
    "short_description": "Database connection timeout",
    "description": "Application unable to connect to database",
    "caller_id": { "display_value": "user@company.com" },
    "impact": "1",
    "urgency": "2"
  },
  "incidentManagerAgentId": "agent-id",
  "incidentManagerAgentAliasId": "alias-id",
  "criticalAlertTopic": "arn:aws:sns:...",
  "incidentNotificationTopic": "arn:aws:sns:...",
  "errorTopic": "arn:aws:sns:..."
}
```

**DynamoDB Tables Used**:
- `servicenow-incidents` - Incident state tracking

**SNS Topics**:
- Critical alert topic (immediate escalation)
- Incident notification topic (status updates)
- Error topic (failure notifications)

**Lambda Functions Called**:
- `servicenow-escalate-incident` - Escalate to critical team
- `servicenow-auto-assign` - Auto-assign to group
- `servicenow-auto-resolve-check` - Check if auto-resolvable
- `servicenow-resolve-incident` - Auto-resolve incident
- `servicenow-queue-incident` - Queue for manual review
- `servicenow-get-incident-status` - Check current status
- `servicenow-update-incident` - Update in ServiceNow

---

### 2. Ticket Triage Workflow

**File**: `ticket-triage-workflow.json`

**Purpose**: Intelligent ticket categorization, prioritization, and routing

**Features**:
- Receives new support tickets
- Invokes Bedrock Ticket Analyzer agent
- Categorizes and prioritizes tickets
- Searches knowledge base for solutions
- Auto-resolves when KB solution found
- Routes unresolved tickets to appropriate teams
- Assigns to technicians with best fit

**Key States**:
- `ReceiveNewTicket` - Store ticket in DynamoDB
- `InvokeTicketAnalyzerAgent` - AI analysis of ticket
- `SearchKnowledgeBase` - Parallel KB and FAQ search
- `EvaluateAutoResolution` - Determine if auto-resolvable
- `AutoResolveTicket` - Parallel resolution and notification
- `RoutTicketForAssignment` - Intelligent routing logic

**Input Schema**:
```json
{
  "ticket": {
    "sys_id": "REQ0987654",
    "category": "Hardware",
    "subcategory": "Laptop",
    "short_description": "Laptop screen flickering",
    "description": "Display shows intermittent flicker",
    "caller_id": { "display_value": "user@company.com" },
    "priority": "3"
  },
  "ticketAnalyzerAgentId": "agent-id",
  "ticketAnalyzerAgentAliasId": "alias-id",
  "knowledgeBaseId": "kb-id",
  "ticketNotificationTopic": "arn:aws:sns:...",
  "assignmentNotificationTopic": "arn:aws:sns:...",
  "errorTopic": "arn:aws:sns:..."
}
```

**DynamoDB Tables Used**:
- `servicenow-tickets` - Ticket state tracking

**Bedrock Features**:
- Knowledge base integration via `bedrock:retrieveAndGenerateQuery`
- Agent invocation for categorization

**Lambda Functions Called**:
- `servicenow-categorize-ticket` - AI-based categorization
- `servicenow-search-knowledge-base` - KB article search
- `servicenow-evaluate-resolution` - Resolution feasibility check
- `servicenow-resolve-ticket` - Auto-resolve with KB reference
- `servicenow-route-ticket` - Determine assignment group
- `servicenow-assign-ticket` - Assign to technician

---

### 3. Change Approval Workflow

**File**: `change-approval-workflow.json`

**Purpose**: Risk-based change approval with dynamic routing and implementation tracking

**Features**:
- Receives change requests from ServiceNow
- Bedrock agent performs comprehensive risk assessment
- Dynamic approval routing based on risk level:
  - Critical: Executive approval required
  - High: Change Advisory Board (CAB) approval
  - Medium: Standard approval process
  - Low: Auto-approval
- SQS task tokens for human approval wait states
- Schedules implementation and monitors completion
- Auto-escalation after 72 hours without implementation

**Key States**:
- `ReceiveChangeRequest` - Store change request
- `PerformRiskAssessment` - Bedrock risk analysis
- `DetermineDynamicApprovalPath` - Route based on risk
- `CriticalChangeApprovalPath` - Executive approval (parallel)
- `HighRiskApprovalPath` - CAB approval (parallel)
- `StandardApprovalPath` - Standard approval (SQS token)
- `LowRiskChangeApprovalPath` - Auto-approve
- `ScheduleImplementation` - Parallel ticketing & notification
- `MonitorImplementation` - 72-hour window with checks

**Input Schema**:
```json
{
  "change": {
    "sys_id": "CHG0555555",
    "type": "Standard",
    "priority": "2",
    "description": "Update production database driver",
    "affected_services": ["Production Database", "Web App"],
    "planned_start_date": "2024-02-15",
    "planned_end_date": "2024-02-15"
  },
  "riskAssessmentAgentId": "agent-id",
  "riskAssessmentAgentAliasId": "alias-id",
  "approvalQueueUrl": "https://sqs.region.amazonaws.com/...",
  "executiveApprovalTopic": "arn:aws:sns:...",
  "cabApprovalTopic": "arn:aws:sns:...",
  "implementationTeamTopic": "arn:aws:sns:...",
  "implementationCheckInterval": 1800
}
```

**DynamoDB Tables Used**:
- `servicenow-changes` - Change request tracking

**Approval Mechanisms**:
- SNS for initial notifications
- SQS task tokens for synchronous approval waiting
- 72-hour implementation monitoring window

**Lambda Functions Called**:
- `servicenow-auto-approve-change` - Auto-approve low-risk
- `servicenow-create-implementation-ticket` - Create tracking ticket
- `servicenow-check-change-status` - Poll implementation status
- `servicenow-reject-change` - Handle denied approvals
- `servicenow-escalate-change` - Handle timeout escalations

---

### 4. Problem Investigation Workflow

**File**: `problem-investigation-workflow.json`

**Purpose**: Root cause analysis and KB article generation from problem records

**Features**:
- Receives problem records with linked incidents
- Fetches all related incidents for pattern analysis
- Bedrock agent analyzes incident patterns and root causes
- Parallel analysis:
  - Call tree analysis
  - Affected Configuration Items (CIs) identification
  - Historical problem search
- Creates KB article with documented solution
- Links incidents to KB article
- Creates permanent fix request for implementation

**Key States**:
- `ReceiveProblemRequest` - Store problem
- `FetchRelatedIncidents` - Gather linked incidents
- `AnalyzeIncidentPatterns` - Bedrock pattern analysis
- `ExtractRootCauses` - Parallel root cause analysis
- `DetermineFinalRootCause` - Consolidate findings
- `GenerateKBArticleDraft` - AI KB article creation
- `CreateKBArticle` - Store article and get ID
- `LinkIncidentsToKBArticle` - Associate incidents
- `CreatePermanentFix` - Create change request for fix

**Input Schema**:
```json
{
  "problem": {
    "sys_id": "PRB0444444",
    "short_description": "Intermittent API gateway timeouts",
    "description": "API requests fail with 504 Gateway Timeout",
    "affected_services": ["API Gateway", "Microservices"]
  },
  "linkedIncidentIds": ["INC1", "INC2", "INC3"],
  "problemResolverAgentId": "agent-id",
  "problemResolverAgentAliasId": "alias-id",
  "knowledgeCuratorAgentId": "agent-id",
  "knowledgeCuratorAgentAliasId": "alias-id",
  "kbManagementTopic": "arn:aws:sns:...",
  "changeManagementTopic": "arn:aws:sns:...",
  "incidentOwnersTopic": "arn:aws:sns:..."
}
```

**DynamoDB Tables Used**:
- `servicenow-problems` - Problem tracking

**Bedrock Integration**:
- Problem Resolver agent for analysis
- Knowledge Curator agent for KB article creation

**Lambda Functions Called**:
- `servicenow-fetch-related-incidents` - Get incident data
- `servicenow-analyze-call-tree` - Incident relationship analysis
- `servicenow-identify-affected-cis` - CI impact analysis
- `servicenow-search-historical-problems` - Find similar problems
- `servicenow-determine-root-cause` - RCA consolidation
- `servicenow-create-kb-article` - Create KB draft
- `servicenow-link-incidents-to-kb` - Create associations
- `servicenow-create-permanent-fix` - Create change request

---

### 5. Knowledge Creation Workflow

**File**: `knowledge-creation-workflow.json`

**Purpose**: Automated knowledge base article creation from resolved incidents

**Features**:
- Continuous monitoring of resolved incidents (hourly)
- Bedrock Knowledge Curator agent extracts solution steps
- Quality validation of extracted content
- Content enhancement for articles below quality threshold
- Creates KB articles in draft status
- Links original incident to KB article
- Sends for expert review before publishing
- Tracks creation metrics and quality scores

**Key States**:
- `MonitorResolvedIncidents` - Wait 1 hour
- `QueryRecentlyResolvedIncidents` - Fetch last hour's resolutions
- `ProcessIncidentsForKB` - Map over incidents (max 3 concurrent)
- `ExtractSolutionSteps` - AI extraction from incident
- `ValidateSolutionQuality` - Quality scoring
- `EnhanceContent` - Improve if quality < 0.75
- `CreateKBArticleFromIncident` - Store article
- `LinkIncidentToKB` - Create relationship
- `NotifyKBTeamForReview` - Request expert review
- `RecordKBCreation` - Log metrics
- `SummarizeCreationResults` - Create execution summary

**Input Schema**:
```json
{
  "knowledgeCuratorAgentId": "agent-id",
  "knowledgeCuratorAgentAliasId": "alias-id",
  "kbReviewTopic": "arn:aws:sns:...",
  "managementTopic": "arn:aws:sns:..."
}
```

**DynamoDB Tables Used**:
- `servicenow-kb-creation-log` - Track created articles
- `servicenow-kb-workflow-executions` - Execution history

**Map State**:
- Processes up to 10 recent incidents
- Max 3 concurrent executions per cycle
- Individual error handling per incident

**Output Metrics**:
- Total incidents processed
- Articles created
- Articles skipped
- Average quality score
- Execution timestamp

---

### 6. SLA Monitoring Workflow

**File**: `sla-monitoring-workflow.json`

**Purpose**: Real-time SLA breach prevention and compliance tracking

**Features**:
- Continuous monitoring every 10 minutes
- Identifies tickets at risk (80%+ of SLA timer)
- Segments tickets by breach severity
- **Critical Breach Path** (Parallel):
  - Immediate escalation to manager
  - Send critical alert SNS
  - Update urgency to P1
- **Critical Risk Path** (Parallel, max 3 concurrent):
  - Assign to senior technician
  - Send warning notification
- **High Risk Path** (Parallel, max 2 concurrent):
  - Send reminder notification
- Parallel metrics publishing:
  - CloudWatch custom metrics
  - S3 report storage
  - Executive notifications
- DynamoDB SLA compliance tracking

**Key States**:
- `MonitorSLATimers` - Wait 10 minutes
- `FetchTicketsAtRisk` - Query tickets at 80%+ SLA
- `AnalyzeRiskLevels` - Categorize by threshold
- `SegmentTicketsBySeverity` - Group by risk segment
- `ProcessSegmentedTickets` - Parallel processing
  - Process Critical Breaches (Map, max 5 concurrent)
  - Process Critical Risk (Map, max 3 concurrent)
  - Process High Risk (Map, max 2 concurrent)
  - Record SLA status in DynamoDB
- `GenerateSLAReport` - Create executive report
- `PublishSLAMetrics` - Parallel publishing
  - CloudWatch metrics
  - S3 report storage
  - Executive notifications (if breaches)
- `UpdateComplianceTracker` - Record daily compliance

**Input Schema**:
```json
{
  "slaBreachAlertTopic": "arn:aws:sns:...",
  "slaWarningTopic": "arn:aws:sns:...",
  "executiveTopic": "arn:aws:sns:...",
  "reportsBucket": "my-reports-bucket",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

**DynamoDB Tables Used**:
- `servicenow-sla-monitoring` - Monitoring cycle records
- `servicenow-sla-compliance` - Daily compliance tracking

**CloudWatch Metrics Published**:
- `ServiceNow/SLA:TicketsAtRisk` (Count)
- `ServiceNow/SLA:BreachedSLAs` (Count)
- `ServiceNow/SLA:SLACompliancePercentage` (Percent)

**S3 Reports**:
- Path: `sla-reports/{DATE}/sla-report.json`
- Contents: Risk analysis, segmentation, compliance metrics

**Executive Notifications**:
- Triggered when breaches detected
- Includes at-risk count and compliance percentage

---

## Common Configuration

### Required IAM Permissions

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeAgent",
        "bedrock:RetrieveAndGenerateQuery"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "lambda:InvokeFunction"
      ],
      "Resource": "arn:aws:lambda:*:*:function:servicenow-*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:GetItem",
        "dynamodb:Query"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/servicenow-*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "sns:Publish"
      ],
      "Resource": "arn:aws:sns:*:*:*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "sqs:SendMessage",
        "sqs:ReceiveMessage"
      ],
      "Resource": "arn:aws:sqs:*:*:*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::*/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "cloudwatch:PutMetricData"
      ],
      "Resource": "*"
    }
  ]
}
```

### DynamoDB Tables

Create these tables for state management:

```bash
# Incident Response
aws dynamodb create-table \
  --table-name servicenow-incidents \
  --attribute-definitions AttributeName=IncidentId,AttributeType=S \
  --key-schema AttributeName=IncidentId,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST

# Ticket Triage
aws dynamodb create-table \
  --table-name servicenow-tickets \
  --attribute-definitions AttributeName=TicketId,AttributeType=S \
  --key-schema AttributeName=TicketId,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST

# Change Approval
aws dynamodb create-table \
  --table-name servicenow-changes \
  --attribute-definitions AttributeName=ChangeId,AttributeType=S \
  --key-schema AttributeName=ChangeId,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST

# Problem Investigation
aws dynamodb create-table \
  --table-name servicenow-problems \
  --attribute-definitions AttributeName=ProblemId,AttributeType=S \
  --key-schema AttributeName=ProblemId,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST

# KB Creation
aws dynamodb create-table \
  --table-name servicenow-kb-creation-log \
  --attribute-definitions AttributeName=KBArticleId,AttributeType=S \
  --key-schema AttributeName=KBArticleId,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST

aws dynamodb create-table \
  --table-name servicenow-kb-workflow-executions \
  --attribute-definitions AttributeName=ExecutionId,AttributeType=S \
  --key-schema AttributeName=ExecutionId,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST

# SLA Monitoring
aws dynamodb create-table \
  --table-name servicenow-sla-monitoring \
  --attribute-definitions AttributeName=MonitoringCycleId,AttributeType=S \
  --key-schema AttributeName=MonitoringCycleId,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST

aws dynamodb create-table \
  --table-name servicenow-sla-compliance \
  --attribute-definitions AttributeName=Date,AttributeType=S \
  --key-schema AttributeName=Date,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

### Environment Variables

Export these for deployment:

```bash
export AWS_REGION=us-east-1
export AWS_ACCOUNT_ID=123456789012
export INCIDENT_MANAGER_AGENT_ID=agent-xxx
export INCIDENT_MANAGER_AGENT_ALIAS=XXXXXX
export TICKET_ANALYZER_AGENT_ID=agent-yyy
export TICKET_ANALYZER_AGENT_ALIAS=YYYYY
export PROBLEM_RESOLVER_AGENT_ID=agent-zzz
export KNOWLEDGE_CURATOR_AGENT_ID=agent-www
export CRITICAL_ALERT_TOPIC=arn:aws:sns:...
export INCIDENT_NOTIFICATION_TOPIC=arn:aws:sns:...
```

## Lambda Function Integration

Each workflow calls specific Lambda functions. Ensure these are deployed:

### Common Functions (All Workflows)
- `servicenow-update-incident`
- `servicenow-update-ticket-urgency`
- Error handling functions

### Incident Response
- `servicenow-escalate-incident`
- `servicenow-auto-assign`
- `servicenow-auto-resolve-check`
- `servicenow-resolve-incident`
- `servicenow-queue-incident`
- `servicenow-get-incident-status`

### Ticket Triage
- `servicenow-categorize-ticket`
- `servicenow-search-knowledge-base`
- `servicenow-evaluate-resolution`
- `servicenow-resolve-ticket`
- `servicenow-route-ticket`
- `servicenow-assign-ticket`

### Change Approval
- `servicenow-auto-approve-change`
- `servicenow-create-implementation-ticket`
- `servicenow-check-change-status`
- `servicenow-reject-change`
- `servicenow-escalate-change`

### Problem Investigation
- `servicenow-fetch-related-incidents`
- `servicenow-analyze-call-tree`
- `servicenow-identify-affected-cis`
- `servicenow-search-historical-problems`
- `servicenow-determine-root-cause`
- `servicenow-create-kb-article`
- `servicenow-link-incidents-to-kb`
- `servicenow-link-problem-to-incidents`
- `servicenow-create-permanent-fix`

### Knowledge Creation
- `servicenow-query-resolved-incidents`
- `servicenow-validate-kb-quality`
- `servicenow-create-kb-from-incident`
- `servicenow-link-incident-to-kb`
- `servicenow-summarize-kb-creation`

### SLA Monitoring
- `servicenow-fetch-sla-at-risk`
- `servicenow-analyze-sla-risk`
- `servicenow-segment-tickets-sla`
- `servicenow-escalate-ticket-sla`
- `servicenow-assign-to-senior`
- `servicenow-generate-sla-report`

## Deployment

### Using AWS CLI

```bash
# Create state machine for incident response
aws stepfunctions create-state-machine \
  --name "servicenow-incident-response" \
  --definition file://incident-response-workflow.json \
  --role-arn arn:aws:iam::123456789012:role/StepFunctionsRole

# Create state machine for ticket triage
aws stepfunctions create-state-machine \
  --name "servicenow-ticket-triage" \
  --definition file://ticket-triage-workflow.json \
  --role-arn arn:aws:iam::123456789012:role/StepFunctionsRole

# Create state machine for change approval
aws stepfunctions create-state-machine \
  --name "servicenow-change-approval" \
  --definition file://change-approval-workflow.json \
  --role-arn arn:aws:iam::123456789012:role/StepFunctionsRole

# Create state machine for problem investigation
aws stepfunctions create-state-machine \
  --name "servicenow-problem-investigation" \
  --definition file://problem-investigation-workflow.json \
  --role-arn arn:aws:iam::123456789012:role/StepFunctionsRole

# Create state machine for knowledge creation
aws stepfunctions create-state-machine \
  --name "servicenow-knowledge-creation" \
  --definition file://knowledge-creation-workflow.json \
  --role-arn arn:aws:iam::123456789012:role/StepFunctionsRole

# Create state machine for SLA monitoring
aws stepfunctions create-state-machine \
  --name "servicenow-sla-monitoring" \
  --definition file://sla-monitoring-workflow.json \
  --role-arn arn:aws:iam::123456789012:role/StepFunctionsRole
```

### Using Terraform

```hcl
module "servicenow_workflows" {
  source = "./terraform/modules/servicenow-workflows"

  incident_response_definition  = file("${path.module}/workflows/incident-response-workflow.json")
  ticket_triage_definition      = file("${path.module}/workflows/ticket-triage-workflow.json")
  change_approval_definition    = file("${path.module}/workflows/change-approval-workflow.json")
  problem_investigation_definition = file("${path.module}/workflows/problem-investigation-workflow.json")
  knowledge_creation_definition = file("${path.module}/workflows/knowledge-creation-workflow.json")
  sla_monitoring_definition     = file("${path.module}/workflows/sla-monitoring-workflow.json")

  step_functions_role_arn = aws_iam_role.step_functions.arn

  environment = var.environment
  tags        = var.tags
}
```

## Execution Examples

### Start Incident Response Workflow

```bash
aws stepfunctions start-execution \
  --state-machine-arn arn:aws:states:us-east-1:123456789012:stateMachine:servicenow-incident-response \
  --name incident-$(date +%s) \
  --input '{
    "incident": {
      "sys_id": "INC0010001",
      "short_description": "Database connection error",
      "description": "Application unable to connect to production database",
      "caller_id": {"display_value": "user@example.com"},
      "impact": "1",
      "urgency": "1"
    },
    "incidentManagerAgentId": "AGENTID123",
    "incidentManagerAgentAliasId": "XXXXXX",
    "criticalAlertTopic": "arn:aws:sns:us-east-1:123456789012:critical-alerts"
  }'
```

### Start Ticket Triage Workflow

```bash
aws stepfunctions start-execution \
  --state-machine-arn arn:aws:states:us-east-1:123456789012:stateMachine:servicenow-ticket-triage \
  --name ticket-$(date +%s) \
  --input '{
    "ticket": {
      "sys_id": "REQ0020001",
      "category": "Hardware",
      "subcategory": "Laptop",
      "short_description": "Laptop not connecting to WiFi",
      "description": "Cannot connect to company WiFi network",
      "caller_id": {"display_value": "user@example.com"},
      "priority": "3"
    },
    "ticketAnalyzerAgentId": "AGENTID456"
  }'
```

## Monitoring & Debugging

### View Execution History

```bash
# List recent executions
aws stepfunctions list-executions \
  --state-machine-arn arn:aws:states:us-east-1:123456789012:stateMachine:servicenow-incident-response \
  --max-results 10

# Get execution details
aws stepfunctions describe-execution \
  --execution-arn arn:aws:states:us-east-1:123456789012:execution:servicenow-incident-response:exec-123

# Get execution history
aws stepfunctions get-execution-history \
  --execution-arn arn:aws:states:us-east-1:123456789012:execution:servicenow-incident-response:exec-123
```

### CloudWatch Logs

All workflows publish to CloudWatch Logs for detailed debugging:

```bash
# View incident response logs
aws logs tail /aws/states/servicenow-incident-response --follow

# View specific execution logs
aws logs filter-log-events \
  --log-group-name /aws/states/servicenow-incident-response \
  --filter-pattern "execution-123"
```

## Error Handling

All workflows include comprehensive error handling:

- **Catch blocks** on critical states
- **SNS notifications** for all errors
- **Retry logic** for transient failures (e.g., Lambda throttling)
- **Failed state** transitions with detailed error messages
- **DynamoDB state tracking** for recovery

## Best Practices

1. **Bedrock Agent Configuration**:
   - Use Claude 3.5 Sonnet for complex analysis
   - Configure appropriate action groups
   - Enable knowledge bases for context
   - Use guardrails for compliance

2. **Lambda Function Design**:
   - Implement idempotent operations
   - Return consistent JSON response format
   - Include error details in responses
   - Set appropriate timeouts (30-300 seconds)

3. **SLA & Monitoring**:
   - Set up CloudWatch dashboards
   - Create SNS subscriptions for alerts
   - Monitor workflow execution metrics
   - Track DynamoDB consumed capacity

4. **Cost Optimization**:
   - Use on-demand DynamoDB billing
   - Batch Lambda invocations where possible
   - Implement workflow result caching
   - Monitor Bedrock token usage

5. **Security**:
   - Use IAM roles with least privilege
   - Store secrets in AWS Secrets Manager
   - Enable VPC endpoints for ServiceNow API
   - Encrypt DynamoDB with KMS

## Troubleshooting

### Workflow State Machine Validation

```bash
# Validate workflow definition before deployment
aws stepfunctions validate-state-machine-definition \
  --definition file://incident-response-workflow.json
```

### Common Issues

**Issue**: Agent invocation timeout
- **Solution**: Increase agent session TTL, check agent configuration

**Issue**: DynamoDB capacity exceeded
- **Solution**: Use on-demand billing or increase provisioned capacity

**Issue**: SNS notifications not received
- **Solution**: Verify SNS topic ARN, check IAM permissions, confirm subscriptions

**Issue**: Lambda function execution fails
- **Solution**: Check CloudWatch logs, verify IAM role permissions, test function directly

## Support & Documentation

- [AWS Step Functions Documentation](https://docs.aws.amazon.com/step-functions/)
- [Amazon Bedrock Agents](https://docs.aws.amazon.com/bedrock/latest/userguide/agents.html)
- [ServiceNow REST API](https://docs.servicenow.com/bundle/tokyo-application-development/page/integrate/inbound-rest/concept/c_RESTAPITable.html)
- [AWS Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)

---

**Last Updated**: 2024-11-17
**Version**: 1.0.0
**Status**: Production Ready
