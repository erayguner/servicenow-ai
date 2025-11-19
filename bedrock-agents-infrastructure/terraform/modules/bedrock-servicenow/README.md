# ServiceNow Integration Module for Amazon Bedrock

This Terraform module creates a comprehensive ServiceNow integration powered by Amazon Bedrock agents, enabling AI-driven automation for incident management, ticket triage, change management, problem resolution, knowledge base synchronization, and SLA monitoring.

## Features

- **6 Specialized Bedrock Agents**:
  - Incident Management Agent
  - Ticket Triage Agent
  - Change Management Agent
  - Problem Management Agent
  - Knowledge Base Agent
  - SLA Monitoring Agent

- **API Integration**:
  - REST API webhooks for ServiceNow events
  - API Gateway with authentication and rate limiting
  - Lambda functions for ServiceNow API integration

- **Automated Workflows**:
  - Step Functions for incident and change management
  - EventBridge for event-driven automation
  - Automatic escalation and assignment

- **State Management**:
  - DynamoDB for ticket state tracking
  - Cross-session context preservation
  - Audit trail and compliance logging

- **Monitoring & Alerting**:
  - CloudWatch alarms for all components
  - SNS notifications for critical events
  - Custom dashboards and metrics
  - SLA breach prevention

## Architecture

```
ServiceNow Instance
    |
    v
API Gateway (Webhooks) --> Lambda (Webhook Processor)
    |                           |
    v                           v
EventBridge --------> Step Functions (Workflows)
    |                           |
    v                           v
Bedrock Agents <-------------> Lambda (Integration)
    |                           |
    v                           v
DynamoDB (State) ----------> CloudWatch (Monitoring)
    |
    v
SNS (Notifications)
```

## Prerequisites

- AWS Account with Bedrock access
- ServiceNow instance with API access
- Terraform >= 1.5.0
- AWS Provider >= 5.0

## Usage

### Basic Example

```hcl
module "servicenow_integration" {
  source = "./modules/bedrock-servicenow"

  servicenow_instance_url = "https://your-instance.service-now.com"
  servicenow_auth_type    = "oauth"

  enable_incident_automation  = true
  enable_ticket_triage       = true
  enable_change_management   = true
  enable_problem_management  = true
  enable_knowledge_sync      = true
  enable_sla_monitoring      = true

  auto_assignment_enabled    = true
  sla_breach_threshold      = 80

  alarm_notification_emails = [
    "ops-team@example.com",
    "servicenow-admins@example.com"
  ]

  environment = "prod"

  tags = {
    Project     = "ServiceNow-Automation"
    CostCenter  = "IT-Operations"
    ManagedBy   = "Terraform"
  }
}
```

### Advanced Example with VPC and Custom Configuration

```hcl
module "servicenow_integration" {
  source = "./modules/bedrock-servicenow"

  # ServiceNow Configuration
  servicenow_instance_url             = "https://your-instance.service-now.com"
  servicenow_auth_type                = "oauth"
  servicenow_credentials_secret_arn   = aws_secretsmanager_secret.servicenow.arn

  # Feature Flags
  enable_incident_automation  = true
  enable_ticket_triage       = true
  enable_change_management   = true
  enable_problem_management  = true
  enable_knowledge_sync      = true
  enable_sla_monitoring      = true

  # Agent Configuration
  agent_model_id         = "anthropic.claude-3-5-sonnet-20241022-v2:0"
  agent_idle_session_ttl = 1800

  # Auto-assignment
  auto_assignment_enabled            = true
  auto_assignment_confidence_threshold = 0.90

  # SLA Configuration
  sla_breach_threshold = 75

  # Workflow Timeouts
  incident_escalation_timeout_minutes = 45
  change_approval_timeout_minutes     = 300

  # Lambda Configuration
  lambda_runtime     = "python3.12"
  lambda_timeout     = 300
  lambda_memory_size = 1024

  # VPC Configuration
  vpc_id             = aws_vpc.main.id
  subnet_ids         = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.servicenow_integration.id]

  # API Gateway
  api_gateway_stage_name       = "prod"
  enable_api_gateway_logging   = true
  allowed_ip_ranges           = ["10.0.0.0/8", "192.168.1.0/24"]

  # DynamoDB
  dynamodb_billing_mode           = "PAY_PER_REQUEST"
  dynamodb_point_in_time_recovery = true

  # Security
  kms_key_id                 = aws_kms_key.servicenow.id
  enable_encryption_at_rest  = true
  enable_encryption_in_transit = true

  # Monitoring
  enable_enhanced_monitoring = true
  alarm_notification_emails = [
    "ops-team@example.com",
    "servicenow-admins@example.com"
  ]
  sns_kms_master_key_id = aws_kms_key.servicenow.id

  # Knowledge Base
  knowledge_base_ids     = [aws_bedrockagent_knowledge_base.servicenow.id]
  knowledge_sync_schedule = "cron(0 2 * * ? *)"

  environment = "prod"
  name_prefix = "servicenow"

  tags = {
    Project     = "ServiceNow-Automation"
    Environment = "Production"
    CostCenter  = "IT-Operations"
    ManagedBy   = "Terraform"
  }
}
```

## Post-Deployment Configuration

### 1. Update ServiceNow Credentials

After deployment, update the ServiceNow credentials in AWS Secrets Manager:

```bash
aws secretsmanager update-secret \
  --secret-id <credentials_secret_arn> \
  --secret-string '{
    "instance_url": "https://your-instance.service-now.com",
    "auth_type": "oauth",
    "username": "your-username",
    "password": "your-password",
    "client_id": "your-oauth-client-id",
    "client_secret": "your-oauth-client-secret"
  }'
```

### 2. Configure ServiceNow Webhooks

In ServiceNow, configure Business Rules or Outbound REST Messages to send webhooks:

**Incident Webhook URL**: `{api_gateway_url}/webhooks/incident`
**Change Webhook URL**: `{api_gateway_url}/webhooks/change`
**Problem Webhook URL**: `{api_gateway_url}/webhooks/problem`

**Headers**:
- `x-api-key`: `{api_key_value}` (from outputs)
- `Content-Type`: `application/json`

### 3. Test the Integration

Test incident creation:

```bash
curl -X POST "{api_gateway_url}/webhooks/incident" \
  -H "x-api-key: {api_key_value}" \
  -H "Content-Type: application/json" \
  -d '{
    "incident": {
      "sys_id": "test-123",
      "number": "INC0001234",
      "short_description": "Test incident",
      "description": "This is a test incident for validation",
      "priority": 3,
      "state": 1,
      "category": "network",
      "assignment_group": "Network Team"
    }
  }'
```

### 4. Subscribe to SNS Notifications

Confirm email subscriptions sent to the addresses specified in `alarm_notification_emails`.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| servicenow_instance_url | ServiceNow instance URL | string | - | yes |
| servicenow_auth_type | Authentication type (oauth/basic) | string | "oauth" | no |
| enable_incident_automation | Enable incident management | bool | true | no |
| enable_ticket_triage | Enable ticket triage | bool | true | no |
| enable_change_management | Enable change management | bool | true | no |
| enable_problem_management | Enable problem management | bool | true | no |
| enable_knowledge_sync | Enable knowledge sync | bool | true | no |
| enable_sla_monitoring | Enable SLA monitoring | bool | true | no |
| auto_assignment_enabled | Enable auto-assignment | bool | true | no |
| auto_assignment_confidence_threshold | Confidence threshold (0-1) | number | 0.85 | no |
| sla_breach_threshold | SLA breach threshold (0-100) | number | 80 | no |
| alarm_notification_emails | Email addresses for alarms | list(string) | [] | no |

See [variables.tf](./variables.tf) for complete list of inputs.

## Outputs

| Name | Description |
|------|-------------|
| bedrock_agents | Details of all Bedrock agents |
| webhook_endpoints | Webhook URLs for ServiceNow |
| api_key_value | API Gateway API key (sensitive) |
| incident_workflow_arn | ARN of incident workflow |
| state_table_name | DynamoDB table name |
| notification_topic_arn | SNS topic ARN |
| configuration | Configuration summary |
| integration_instructions | Setup instructions |

See [outputs.tf](./outputs.tf) for complete list of outputs.

## Agent Capabilities

### Incident Management Agent
- Analyzes incident severity and priority
- Categorizes incidents by type and affected services
- Recommends assignment groups
- Suggests resolution steps from knowledge base
- Monitors SLA compliance
- Identifies patterns for problem management

### Ticket Triage Agent
- Determines ticket type automatically
- Extracts key information and business impact
- Routes tickets to appropriate teams
- Identifies duplicate tickets
- Suggests automated responses
- Flags urgent tickets

### Change Management Agent
- Assesses change risk and impact
- Recommends approval/rejection
- Identifies conflicts and dependencies
- Suggests implementation windows
- Monitors change success rates
- Tracks compliance requirements

### Problem Management Agent
- Analyzes incident patterns
- Conducts root cause analysis
- Suggests permanent fixes and workarounds
- Tracks known errors
- Recommends prevention measures
- Documents lessons learned

### Knowledge Base Agent
- Creates knowledge articles from resolutions
- Maintains knowledge accuracy
- Suggests article improvements
- Categorizes and tags articles
- Identifies knowledge gaps
- Syncs with ServiceNow knowledge base

### SLA Monitor Agent
- Monitors SLA compliance real-time
- Predicts potential breaches
- Recommends preventive actions
- Escalates at-risk tickets
- Analyzes compliance trends
- Suggests SLA optimizations

## Workflows

### Incident Workflow
1. Analyze incident with Bedrock agent
2. Determine severity and priority
3. Critical incidents: immediate escalation
4. High priority: assign to team
5. Normal priority: triage and auto-assign if confident
6. Start SLA monitoring
7. Update state in DynamoDB
8. Capture knowledge when resolved

### Change Workflow
1. Analyze change request
2. Assess risk level
3. High risk: require CAB approval
4. Medium risk: require manager approval
5. Low risk: auto-approve
6. Schedule change implementation
7. Track approval status
8. Update state in DynamoDB

## Monitoring

The module creates comprehensive monitoring:

- **Lambda Metrics**: Invocations, errors, duration, throttles
- **API Gateway Metrics**: Request count, latency, errors
- **Step Functions Metrics**: Executions, failures, duration
- **DynamoDB Metrics**: Capacity, throttles
- **Bedrock Metrics**: Agent invocations, errors
- **Custom Metrics**: SLA breaches, auto-assignment rates

## Security

- All data encrypted at rest and in transit
- KMS encryption for secrets and DynamoDB
- VPC support for Lambda functions
- IAM least-privilege policies
- API Gateway with API key authentication
- IP address restrictions (optional)
- Audit logging via CloudWatch

## Cost Optimization

- On-demand DynamoDB billing by default
- Lambda reserved concurrency limits
- API Gateway usage plans with quotas
- CloudWatch log retention (30 days)
- DynamoDB TTL for old records

## Troubleshooting

### Common Issues

**Agents not responding:**
- Check CloudWatch logs: `/aws/bedrock/agents/{agent-name}`
- Verify agent preparation completed
- Check IAM permissions

**Webhooks failing:**
- Verify API key is correct
- Check API Gateway logs
- Validate webhook payload format
- Check IP restrictions

**Workflows timing out:**
- Increase timeout values in variables
- Check Step Functions execution logs
- Verify Lambda function performance

**SLA monitoring not triggering:**
- Check EventBridge rule patterns
- Verify SNS topic subscriptions
- Review CloudWatch metric filters

## Support

For issues and questions:
- Check CloudWatch Logs and metrics
- Review Step Functions execution history
- Examine DynamoDB state table
- Contact AWS Support for Bedrock issues

## License

This module is provided as-is under the MIT License.

## Contributing

Contributions welcome! Please submit pull requests with:
- Clear descriptions
- Updated documentation
- Test coverage
- Example usage

## Changelog

### Version 1.0.0
- Initial release
- 6 Bedrock agents for ServiceNow
- Complete workflow automation
- Comprehensive monitoring
- Security best practices
