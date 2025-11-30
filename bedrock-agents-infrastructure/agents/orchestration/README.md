# Orchestration Workflows

This directory contains AWS Step Functions state machine definitions for
orchestrating multi-agent workflows.

## Available Workflows

### 1. SPARC Workflow (`sparc-workflow.json`)

**Purpose:** Implements the complete SPARC (Specification, Pseudocode,
Architecture, Refinement, Completion) methodology as an automated workflow.

**Phases:**

1. **Specification** - Requirements gathering and specification creation
2. **Pseudocode** - Algorithm design in structured pseudocode
3. **Architecture** - System design and component architecture
4. **Refinement** - TDD implementation with Red-Green-Refactor
5. **Testing & Validation** - Comprehensive testing
6. **Code Review** - Quality and security review

**Features:**

- Sequential phase execution
- Validation gates between phases
- Automatic retry logic (up to 3 iterations)
- Error handling with SNS notifications
- Artifact storage in S3
- Review feedback loop

**Input Parameters:**

```json
{
  "sessionId": "unique-session-id",
  "userRequirements": "Feature requirements...",
  "specificationAgentId": "agent-id",
  "specificationAgentAliasId": "alias-id",
  "pseudocodeAgentId": "agent-id",
  "pseudocodeAgentAliasId": "alias-id",
  "architectureAgentId": "agent-id",
  "architectureAgentAliasId": "alias-id",
  "refinementAgentId": "agent-id",
  "refinementAgentAliasId": "alias-id",
  "testerAgentId": "agent-id",
  "testerAgentAliasId": "alias-id",
  "reviewerAgentId": "agent-id",
  "reviewerAgentAliasId": "alias-id",
  "notificationTopicArn": "sns-topic-arn",
  "artifactBucket": "s3-bucket-name",
  "iterationCount": 0
}
```

**Use Cases:**

- New feature development
- Systematic software development
- TDD projects
- Quality-critical implementations

---

### 2. Full-Stack Development Workflow (`full-stack-development-workflow.json`)

**Purpose:** Orchestrates parallel development of backend, frontend, and ML
components with integration and deployment preparation.

**Phases:**

1. **Planning Phase** (Parallel)

   - Project planning
   - Architecture design

2. **Parallel Development**

   - Backend development + tests
   - Frontend development + tests
   - ML development + validation

3. **Parallel Review**

   - Code quality review
   - Security audit

4. **Integration Phase**

   - Component integration
   - End-to-end testing

5. **Deployment Preparation** (Parallel)
   - Documentation generation
   - Artifact storage
   - Notifications

**Features:**

- Parallel execution for speed
- Multi-component coordination
- Comprehensive testing at each level
- Security integration
- Deployment readiness

**Input Parameters:**

```json
{
  "sessionId": "unique-session-id",
  "projectRequirements": "Project requirements...",
  "plannerAgentId": "agent-id",
  "plannerAgentAliasId": "alias-id",
  "architectureAgentId": "agent-id",
  "architectureAgentAliasId": "alias-id",
  "backendDevAgentId": "agent-id",
  "backendDevAgentAliasId": "alias-id",
  "frontendDevAgentId": "agent-id",
  "frontendDevAgentAliasId": "alias-id",
  "mlDeveloperAgentId": "agent-id",
  "mlDeveloperAgentAliasId": "alias-id",
  "testerAgentId": "agent-id",
  "testerAgentAliasId": "alias-id",
  "reviewerAgentId": "agent-id",
  "reviewerAgentAliasId": "alias-id",
  "securityAuditorAgentId": "agent-id",
  "securityAuditorAgentAliasId": "alias-id",
  "hierarchicalCoordinatorAgentId": "agent-id",
  "hierarchicalCoordinatorAgentAliasId": "alias-id",
  "notificationTopicArn": "sns-topic-arn",
  "artifactBucket": "s3-bucket-name"
}
```

**Use Cases:**

- Full-stack application development
- Microservices architecture
- ML-powered applications
- Complex system integration

---

### 3. Adaptive Coordination Workflow (`adaptive-coordination-workflow.json`)

**Purpose:** Dynamically selects and adapts coordination strategies based on
task characteristics and performance metrics.

**Coordination Strategies:**

1. **Hierarchical** - Top-down delegation for complex tasks
2. **Mesh** - Peer-to-peer collaboration for innovation
3. **Hybrid** - Mixed approach for balanced needs
4. **Autonomous** - Minimal coordination for independent work

**Features:**

- Intelligent strategy selection
- Performance monitoring
- Dynamic adaptation (strategy switching)
- Learning from execution (stores patterns)
- Validation and quality checks

**Decision Factors:**

- Task complexity (1-10)
- Team size
- Deadline pressure
- Task interdependency
- Team expertise level

**Input Parameters:**

```json
{
  "sessionId": "unique-session-id",
  "taskDescription": "Task description...",
  "teamSize": 5,
  "deadline": "2024-01-31",
  "adaptiveCoordinatorAgentId": "agent-id",
  "adaptiveCoordinatorAgentAliasId": "alias-id",
  "hierarchicalCoordinatorAgentId": "agent-id",
  "hierarchicalCoordinatorAgentAliasId": "alias-id",
  "meshCoordinatorAgentId": "agent-id",
  "meshCoordinatorAgentAliasId": "alias-id",
  "reviewerAgentId": "agent-id",
  "reviewerAgentAliasId": "alias-id",
  "assignedAgents": [
    {
      "agentId": "agent-id-1",
      "agentAliasId": "alias-id-1",
      "taskPortion": "Task portion 1"
    }
  ],
  "hybridWorkflowStateMachineArn": "state-machine-arn",
  "notificationTopicArn": "sns-topic-arn",
  "artifactBucket": "s3-bucket-name",
  "learningsTableName": "dynamodb-table-name"
}
```

**Use Cases:**

- Unknown or variable task complexity
- Long-running projects with evolving needs
- Learning optimal coordination patterns
- Experimental approaches

---

## Deployment

### Using Terraform

```hcl
resource "aws_sfn_state_machine" "sparc_workflow" {
  name     = "sparc-workflow-${var.environment}"
  role_arn = aws_iam_role.step_functions_role.arn

  definition = file("${path.module}/agents/orchestration/sparc-workflow.json")

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = "servicenow-ai"
  }
}

resource "aws_sfn_state_machine" "full_stack_workflow" {
  name     = "full-stack-workflow-${var.environment}"
  role_arn = aws_iam_role.step_functions_role.arn

  definition = file("${path.module}/agents/orchestration/full-stack-development-workflow.json")

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = "servicenow-ai"
  }
}

resource "aws_sfn_state_machine" "adaptive_workflow" {
  name     = "adaptive-coordination-workflow-${var.environment}"
  role_arn = aws_iam_role.step_functions_role.arn

  definition = file("${path.module}/agents/orchestration/adaptive-coordination-workflow.json")

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = "servicenow-ai"
  }
}
```

### IAM Role Requirements

The Step Functions execution role needs permissions for:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["bedrock:InvokeAgent"],
      "Resource": "arn:aws:bedrock:*:*:agent/*"
    },
    {
      "Effect": "Allow",
      "Action": ["sns:Publish"],
      "Resource": "arn:aws:sns:*:*:*"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:PutObject", "s3:GetObject"],
      "Resource": "arn:aws:s3:::artifact-bucket/*"
    },
    {
      "Effect": "Allow",
      "Action": ["dynamodb:PutItem", "dynamodb:GetItem"],
      "Resource": "arn:aws:dynamodb:*:*:table/learnings-table"
    },
    {
      "Effect": "Allow",
      "Action": ["states:StartExecution"],
      "Resource": "arn:aws:states:*:*:stateMachine:*"
    }
  ]
}
```

## Execution

### Using AWS CLI

```bash
# Start SPARC workflow
aws stepfunctions start-execution \
  --state-machine-arn arn:aws:states:us-east-1:123456789012:stateMachine:sparc-workflow-dev \
  --input file://sparc-input.json \
  --name sparc-execution-$(date +%s)

# Start Full-Stack workflow
aws stepfunctions start-execution \
  --state-machine-arn arn:aws:states:us-east-1:123456789012:stateMachine:full-stack-workflow-dev \
  --input file://full-stack-input.json \
  --name fullstack-execution-$(date +%s)

# Start Adaptive workflow
aws stepfunctions start-execution \
  --state-machine-arn arn:aws:states:us-east-1:123456789012:stateMachine:adaptive-workflow-dev \
  --input file://adaptive-input.json \
  --name adaptive-execution-$(date +%s)
```

### Using AWS SDK (Python)

```python
import boto3
import json

sfn = boto3.client('stepfunctions')

# Start execution
response = sfn.start_execution(
    stateMachineArn='arn:aws:states:us-east-1:123456789012:stateMachine:sparc-workflow-dev',
    input=json.dumps({
        'sessionId': 'session-123',
        'userRequirements': 'Build a REST API...',
        # ... other parameters
    })
)

# Monitor execution
execution_arn = response['executionArn']

# Get status
status = sfn.describe_execution(executionArn=execution_arn)
print(f"Status: {status['status']}")

# Get history
history = sfn.get_execution_history(executionArn=execution_arn)
```

## Monitoring

### CloudWatch Metrics

Monitor these metrics:

- `ExecutionsFailed`
- `ExecutionsSucceeded`
- `ExecutionTime`
- `ExecutionsTimedOut`

### CloudWatch Logs

Enable logging for detailed execution traces:

```hcl
resource "aws_sfn_state_machine" "example" {
  # ... other configuration

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.sfn_logs.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }
}

resource "aws_cloudwatch_log_group" "sfn_logs" {
  name              = "/aws/stepfunctions/workflow-logs"
  retention_in_days = 30
}
```

## Best Practices

1. **Session ID Management**

   - Use unique, trackable session IDs
   - Include timestamp and workflow type
   - Example: `sparc-20240101-123456-abc123`

2. **Error Handling**

   - Always include Catch blocks
   - Send notifications on failures
   - Store error context for debugging

3. **Artifact Storage**

   - Store all intermediate results
   - Use consistent S3 key patterns
   - Enable versioning on artifact bucket

4. **Retry Logic**

   - Set appropriate retry limits
   - Use exponential backoff
   - Track iteration counts

5. **Performance**

   - Use parallel execution where possible
   - Set appropriate timeouts
   - Monitor execution duration

6. **Cost Optimization**
   - Minimize state transitions
   - Use efficient parallel patterns
   - Set appropriate timeouts

## Customization

### Adding Custom States

```json
{
  "CustomState": {
    "Type": "Task",
    "Resource": "arn:aws:states:::bedrock:invokeAgent",
    "Parameters": {
      "AgentId.$": "$.customAgentId",
      "AgentAliasId.$": "$.customAgentAliasId",
      "SessionId.$": "$.sessionId",
      "InputText": "Custom instructions..."
    },
    "ResultPath": "$.customResult",
    "Next": "NextState"
  }
}
```

### Modifying Branching Logic

```json
{
  "CheckCondition": {
    "Type": "Choice",
    "Choices": [
      {
        "Variable": "$.someValue",
        "NumericGreaterThan": 10,
        "Next": "PathA"
      },
      {
        "Variable": "$.someValue",
        "NumericLessThanEquals": 10,
        "Next": "PathB"
      }
    ],
    "Default": "DefaultPath"
  }
}
```

## Troubleshooting

### Common Issues

1. **Agent Not Found**

   - Verify agent IDs and alias IDs
   - Check agent is in same region
   - Ensure agent is not deleted

2. **Permission Denied**

   - Check Step Functions execution role
   - Verify Bedrock agent permissions
   - Review S3 bucket policies

3. **Timeout Errors**

   - Increase state timeout values
   - Check agent processing time
   - Review parallel branch limits

4. **Data Size Limits**
   - Step Functions has 256KB limit
   - Store large data in S3
   - Pass S3 references instead

## Support

- [AWS Step Functions Documentation](https://docs.aws.amazon.com/step-functions/)
- [Bedrock Agent Integration](https://docs.aws.amazon.com/bedrock/latest/userguide/agents-step-functions.html)
- [Step Functions Best Practices](https://docs.aws.amazon.com/step-functions/latest/dg/best-practices.html)
