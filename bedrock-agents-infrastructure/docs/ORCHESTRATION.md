# Bedrock Agents Orchestration Guide

Comprehensive guide to multi-agent orchestration, Step Functions workflows,
consensus mechanisms, and state management.

## Overview

Orchestration coordinates multiple agents to achieve complex objectives. AWS
Step Functions provides a serverless workflow engine for defining and managing
multi-agent interactions.

## Step Functions Workflows

### Basic Sequential Workflow

```json
{
  "Comment": "Sequential multi-agent workflow",
  "StartAt": "ResearchPhase",
  "States": {
    "ResearchPhase": {
      "Type": "Task",
      "Resource": "arn:aws:states:::bedrock-agent:invokeAgent:sync",
      "Parameters": {
        "agentId": "research-agent-id",
        "agentAliasId": "PROD",
        "sessionId.$": "$.sessionId",
        "inputText.$": "$.researchQuery"
      },
      "Next": "AnalysisPhase"
    },
    "AnalysisPhase": {
      "Type": "Task",
      "Resource": "arn:aws:states:::bedrock-agent:invokeAgent:sync",
      "Parameters": {
        "agentId": "analysis-agent-id",
        "agentAliasId": "PROD",
        "sessionId.$": "$.sessionId",
        "inputText.$": "$.analysisQuery"
      },
      "Next": "SummarizationPhase"
    },
    "SummarizationPhase": {
      "Type": "Task",
      "Resource": "arn:aws:states:::bedrock-agent:invokeAgent:sync",
      "Parameters": {
        "agentId": "summarizer-agent-id",
        "agentAliasId": "PROD",
        "sessionId.$": "$.sessionId",
        "inputText.$": "$.summaryQuery"
      },
      "End": true
    }
  }
}
```

### Parallel Multi-Agent Workflow

```json
{
  "Comment": "Parallel agent execution",
  "StartAt": "ParallelPhase",
  "States": {
    "ParallelPhase": {
      "Type": "Parallel",
      "Branches": [
        {
          "StartAt": "DataAgent",
          "States": {
            "DataAgent": {
              "Type": "Task",
              "Resource": "arn:aws:states:::bedrock-agent:invokeAgent:sync",
              "Parameters": {
                "agentId": "data-agent-id",
                "agentAliasId": "PROD",
                "sessionId.$": "$.sessionId",
                "inputText": "Fetch data for analysis"
              },
              "End": true
            }
          }
        },
        {
          "StartAt": "ResearchAgent",
          "States": {
            "ResearchAgent": {
              "Type": "Task",
              "Resource": "arn:aws:states:::bedrock-agent:invokeAgent:sync",
              "Parameters": {
                "agentId": "research-agent-id",
                "agentAliasId": "PROD",
                "sessionId.$": "$.sessionId",
                "inputText": "Research relevant sources"
              },
              "End": true
            }
          }
        },
        {
          "StartAt": "PolicyAgent",
          "States": {
            "PolicyAgent": {
              "Type": "Task",
              "Resource": "arn:aws:states:::bedrock-agent:invokeAgent:sync",
              "Parameters": {
                "agentId": "policy-agent-id",
                "agentAliasId": "PROD",
                "sessionId.$": "$.sessionId",
                "inputText": "Check compliance policies"
              },
              "End": true
            }
          }
        }
      ],
      "Next": "ConsolidateResults"
    },
    "ConsolidateResults": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:REGION:ACCOUNT:function:consolidate-results",
      "End": true
    }
  }
}
```

### Conditional Branching Workflow

```json
{
  "Comment": "Conditional routing based on agent decisions",
  "StartAt": "RouteDecision",
  "States": {
    "RouteDecision": {
      "Type": "Task",
      "Resource": "arn:aws:states:::bedrock-agent:invokeAgent:sync",
      "Parameters": {
        "agentId": "router-agent-id",
        "agentAliasId": "PROD",
        "sessionId.$": "$.sessionId",
        "inputText.$": "$.userRequest"
      },
      "Next": "EvaluateRoute"
    },
    "EvaluateRoute": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.agentOutput.selectedAgent",
          "StringEquals": "technical-support",
          "Next": "TechnicalSupportAgent"
        },
        {
          "Variable": "$.agentOutput.selectedAgent",
          "StringEquals": "billing-support",
          "Next": "BillingSupportAgent"
        },
        {
          "Variable": "$.agentOutput.selectedAgent",
          "StringEquals": "general-support",
          "Next": "GeneralSupportAgent"
        }
      ],
      "Default": "EscalationAgent"
    },
    "TechnicalSupportAgent": {
      "Type": "Task",
      "Resource": "arn:aws:states:::bedrock-agent:invokeAgent:sync",
      "Parameters": {
        "agentId": "technical-support-agent-id",
        "agentAliasId": "PROD",
        "sessionId.$": "$.sessionId",
        "inputText.$": "$.userRequest"
      },
      "Next": "CompleteRequest"
    },
    "BillingSupportAgent": {
      "Type": "Task",
      "Resource": "arn:aws:states:::bedrock-agent:invokeAgent:sync",
      "Parameters": {
        "agentId": "billing-support-agent-id",
        "agentAliasId": "PROD",
        "sessionId.$": "$.sessionId",
        "inputText.$": "$.userRequest"
      },
      "Next": "CompleteRequest"
    },
    "GeneralSupportAgent": {
      "Type": "Task",
      "Resource": "arn:aws:states:::bedrock-agent:invokeAgent:sync",
      "Parameters": {
        "agentId": "general-support-agent-id",
        "agentAliasId": "PROD",
        "sessionId.$": "$.sessionId",
        "inputText.$": "$.userRequest"
      },
      "Next": "CompleteRequest"
    },
    "EscalationAgent": {
      "Type": "Task",
      "Resource": "arn:aws:states:::bedrock-agent:invokeAgent:sync",
      "Parameters": {
        "agentId": "escalation-agent-id",
        "agentAliasId": "PROD",
        "sessionId.$": "$.sessionId",
        "inputText.$": "$.userRequest"
      },
      "Next": "CompleteRequest"
    },
    "CompleteRequest": {
      "Type": "Pass",
      "End": true
    }
  }
}
```

### Error Handling and Retry Workflow

```json
{
  "Comment": "Workflow with error handling",
  "StartAt": "PrimaryAgent",
  "States": {
    "PrimaryAgent": {
      "Type": "Task",
      "Resource": "arn:aws:states:::bedrock-agent:invokeAgent:sync",
      "Parameters": {
        "agentId": "primary-agent-id",
        "agentAliasId": "PROD",
        "sessionId.$": "$.sessionId",
        "inputText.$": "$.input"
      },
      "Retry": [
        {
          "ErrorEquals": ["States.TaskFailed"],
          "IntervalSeconds": 2,
          "MaxAttempts": 3,
          "BackoffRate": 2.0
        }
      ],
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "Next": "FallbackAgent"
        }
      ],
      "Next": "Success"
    },
    "FallbackAgent": {
      "Type": "Task",
      "Resource": "arn:aws:states:::bedrock-agent:invokeAgent:sync",
      "Parameters": {
        "agentId": "fallback-agent-id",
        "agentAliasId": "PROD",
        "sessionId.$": "$.sessionId",
        "inputText.$": "$.input"
      },
      "End": true
    },
    "Success": {
      "Type": "Pass",
      "End": true
    }
  }
}
```

## Multi-Agent Coordination Patterns

### Master-Worker Pattern

One coordinator agent distributes tasks to specialist agents:

```python
import boto3
import json
from typing import List, Dict, Any

bedrock_runtime = boto3.client('bedrock-agent-runtime')
stepfunctions = boto3.client('stepfunctions')

def execute_master_worker(
    task: str,
    worker_agents: List[str],
    coordinator_agent: str
) -> Dict[str, Any]:
    """
    Execute master-worker pattern
    """
    # Coordinator agent decides task distribution
    coordinator_response = bedrock_runtime.invoke_agent(
        agentId=coordinator_agent,
        agentAliasId='PROD',
        sessionId='master-worker-session',
        inputText=f"Distribute this task: {task}"
    )

    # Get distribution plan from coordinator
    distribution_plan = parse_coordinator_response(coordinator_response)

    # Execute parallel worker tasks
    execution = stepfunctions.start_execution(
        stateMachineArn='arn:aws:states:...:stateMachine:parallel-workers',
        input=json.dumps({
            'plan': distribution_plan,
            'worker_agents': worker_agents
        })
    )

    # Wait for completion
    execution_arn = execution['executionArn']
    # Poll for completion...

    return {
        'coordination': distribution_plan,
        'execution_arn': execution_arn
    }
```

### Voting/Consensus Pattern

Multiple agents vote on decisions:

```python
def execute_voting_consensus(
    decision_agents: List[str],
    proposal: str,
    threshold: float = 0.5
) -> Dict[str, Any]:
    """
    Execute voting consensus pattern
    """
    votes = {}
    reasoning = {}

    # Each agent votes
    for agent_id in decision_agents:
        response = bedrock_runtime.invoke_agent(
            agentId=agent_id,
            agentAliasId='PROD',
            sessionId=f'vote-session-{agent_id}',
            inputText=f"Vote on this proposal: {proposal}\n\nRespond with APPROVE or REJECT and reasoning."
        )

        result = parse_agent_response(response)
        votes[agent_id] = result['vote']
        reasoning[agent_id] = result['reasoning']

    # Calculate consensus
    approvals = sum(1 for v in votes.values() if v == 'APPROVE')
    approval_ratio = approvals / len(votes)

    consensus_reached = approval_ratio >= threshold

    return {
        'proposal': proposal,
        'votes': votes,
        'reasoning': reasoning,
        'approval_ratio': approval_ratio,
        'consensus_reached': consensus_reached,
        'decision': 'APPROVED' if consensus_reached else 'REJECTED'
    }
```

### Pipeline/Assembly Line Pattern

Sequential processing with agent handoff:

```python
def execute_assembly_line(
    item: str,
    pipeline_agents: List[str]
) -> Dict[str, Any]:
    """
    Execute assembly line (pipeline) pattern
    """
    state = {
        'item': item,
        'results': {},
        'history': []
    }

    # Pass item through each agent in sequence
    for agent_id in pipeline_agents:
        response = bedrock_runtime.invoke_agent(
            agentId=agent_id,
            agentAliasId='PROD',
            sessionId=f'pipeline-{agent_id}',
            inputText=f"Process this: {json.dumps(state['item'])}"
        )

        result = parse_agent_response(response)
        state['results'][agent_id] = result['output']
        state['item'] = result['transformed_item']
        state['history'].append({
            'agent': agent_id,
            'result': result,
            'timestamp': datetime.utcnow().isoformat()
        })

    return state
```

## Consensus Mechanisms

### Byzantine Fault Tolerant Consensus

For critical decisions with potentially faulty agents:

```python
def byzantine_fault_tolerant_consensus(
    agents: List[str],
    proposal: str,
    f: int = 1  # Max faulty agents
) -> Dict[str, Any]:
    """
    Byzantine Fault Tolerant consensus algorithm

    Requires: n >= 3f + 1 agents
    f = max number of faulty agents
    """
    assert len(agents) >= 3 * f + 1, "Not enough agents for BFT"

    votes = {}

    # Phase 1: Gather votes
    for agent_id in agents:
        response = bedrock_runtime.invoke_agent(
            agentId=agent_id,
            agentAliasId='PROD',
            sessionId=f'bft-{agent_id}',
            inputText=proposal
        )
        votes[agent_id] = parse_agent_response(response)['vote']

    # Phase 2: Consensus by majority
    vote_counts = {}
    for vote in votes.values():
        vote_counts[vote] = vote_counts.get(vote, 0) + 1

    # Majority decision (more than 2f+1)
    threshold = 2 * f + 2
    for vote, count in vote_counts.items():
        if count >= threshold:
            return {
                'consensus': vote,
                'confidence': count / len(agents),
                'votes': votes
            }

    return {
        'consensus': None,
        'confidence': 0,
        'votes': votes,
        'error': 'No consensus reached'
    }
```

### RAFT Consensus

For distributed state management:

```python
def raft_consensus_cycle(
    leader_agent: str,
    follower_agents: List[str],
    log_entry: str
) -> Dict[str, Any]:
    """
    RAFT consensus simulation using Bedrock agents
    """
    # Phase 1: Leader sends log entry to followers
    append_entries = bedrock_runtime.invoke_agent(
        agentId=leader_agent,
        agentAliasId='PROD',
        sessionId='raft-leader',
        inputText=f"Propose log entry for replication: {log_entry}"
    )

    # Phase 2: Followers acknowledge
    acks = {}
    for follower_id in follower_agents:
        response = bedrock_runtime.invoke_agent(
            agentId=follower_id,
            agentAliasId='PROD',
            sessionId=f'raft-follower-{follower_id}',
            inputText=f"ACK log entry: {log_entry}"
        )
        acks[follower_id] = parse_agent_response(response)['ack']

    # Phase 3: Commit when majority acknowledged
    ack_count = sum(1 for ack in acks.values() if ack)
    quorum_size = len(follower_agents) // 2 + 1

    return {
        'entry': log_entry,
        'acks': acks,
        'committed': ack_count >= quorum_size,
        'ack_count': ack_count,
        'quorum_required': quorum_size
    }
```

## State Management

### Agent State Storage

```python
import dynamodb

def save_agent_state(
    agent_id: str,
    session_id: str,
    state: Dict[str, Any]
) -> None:
    """
    Save agent state to DynamoDB
    """
    dynamodb_table = boto3.resource('dynamodb').Table('agent-state')

    dynamodb_table.put_item(
        Item={
            'agent_id': agent_id,
            'session_id': session_id,
            'state': state,
            'timestamp': int(time.time()),
            'ttl': int(time.time()) + 86400  # 24 hour TTL
        }
    )

def load_agent_state(
    agent_id: str,
    session_id: str
) -> Dict[str, Any]:
    """
    Load agent state from DynamoDB
    """
    dynamodb_table = boto3.resource('dynamodb').Table('agent-state')

    response = dynamodb_table.get_item(
        Key={
            'agent_id': agent_id,
            'session_id': session_id
        }
    )

    return response.get('Item', {}).get('state', {})
```

### Conversation History

```python
def store_conversation(
    session_id: str,
    agent_id: str,
    role: str,  # 'user' or 'assistant'
    message: str
) -> None:
    """
    Store conversation in DynamoDB
    """
    dynamodb_table = boto3.resource('dynamodb').Table('conversations')

    dynamodb_table.put_item(
        Item={
            'session_id': session_id,
            'timestamp': int(time.time() * 1000),
            'agent_id': agent_id,
            'role': role,
            'message': message
        }
    )

def get_conversation_history(
    session_id: str,
    limit: int = 50
) -> List[Dict[str, Any]]:
    """
    Retrieve conversation history
    """
    dynamodb_table = boto3.resource('dynamodb').Table('conversations')

    response = dynamodb_table.query(
        KeyConditionExpression='session_id = :sid',
        ExpressionAttributeValues={':sid': session_id},
        ScanIndexForward=True,
        Limit=limit
    )

    return response.get('Items', [])
```

## Workflow Management as Code (Terraform)

```hcl
# Create Step Functions state machine
resource "aws_sfn_state_machine" "multi_agent_orchestration" {
  name       = "bedrock-multi-agent-workflow"
  role_arn   = aws_iam_role.stepfunctions_role.arn
  definition = file("${path.module}/workflows/multi-agent-orchestration.json")

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.workflow_logs.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  tracing_configuration {
    enabled = true
  }

  tags = {
    Environment = var.environment
  }
}

# Create execution
resource "aws_sfn_state_machine_execution" "example" {
  state_machine_arn = aws_sfn_state_machine.multi_agent_orchestration.arn
  name              = "execution-${formatdate("YYYY-MM-DD-hhmm-ss", timestamp())}"

  input = jsonencode({
    researchQuery  = "Analyze market trends"
    analysisQuery  = "Generate insights"
    summaryQuery   = "Create executive summary"
  })
}
```

## Monitoring Orchestration

```python
def get_workflow_metrics(state_machine_arn: str, start_time: str) -> Dict[str, Any]:
    """
    Get Step Functions workflow metrics
    """
    cloudwatch = boto3.client('cloudwatch')

    metrics = cloudwatch.get_metric_statistics(
        Namespace='AWS/States',
        MetricName='ExecutionsFailed',
        Dimensions=[
            {
                'Name': 'StateMachineArn',
                'Value': state_machine_arn
            }
        ],
        StartTime=start_time,
        EndTime=datetime.utcnow(),
        Period=300,
        Statistics=['Sum', 'Average']
    )

    return {
        'failed_executions': metrics['Datapoints'],
        'state_machine': state_machine_arn
    }
```

---

**Version**: 1.0.0 **Last Updated**: 2025-01-17
