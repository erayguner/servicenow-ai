# Amazon Bedrock Agents - Quick Start Guide

## 5-Minute Overview

This guide provides a rapid deployment path for the Bedrock agent architecture.

## Prerequisites

- AWS Account with Bedrock enabled
- Terraform >= 1.11.0
- AWS CLI configured
- Bedrock model access (Claude 3.5 Sonnet, Haiku)

## Quick Deploy (Development Environment)

### Step 1: Enable Bedrock Models (5 minutes)

```bash
# Request model access via AWS Console or CLI
aws bedrock list-foundation-models --region us-east-1

# Enable Claude models
aws bedrock put-model-invocation-logging-configuration \
  --region us-east-1 \
  --logging-config '{
    "cloudWatchConfig": {
      "logGroupName": "/aws/bedrock/modelinvocations",
      "roleArn": "arn:aws:iam::ACCOUNT:role/BedrockLoggingRole"
    }
  }'
```

### Step 2: Deploy Infrastructure (15 minutes)

```bash
# Clone repository
git clone https://github.com/your-org/bedrock-agents
cd bedrock-agents/terraform/environments/dev

# Create terraform.tfvars
cat > terraform.tfvars <<TFVARS
region             = "eu-west-2"
environment        = "dev"
project_name       = "ai-agents"
agent_models = {
  coder    = "anthropic.claude-3-5-sonnet-20241022-v2:0"
  tester   = "anthropic.claude-3-5-haiku-20241022-v1:0"
  reviewer = "anthropic.claude-3-5-sonnet-20241022-v2:0"
}
TFVARS

# Deploy
terraform init
terraform plan
terraform apply -auto-approve
```

### Step 3: Create Your First Agent (5 minutes)

```bash
# Using AWS CLI
aws bedrock-agent create-agent \
  --agent-name "my-first-coder" \
  --foundation-model "anthropic.claude-3-5-sonnet-20241022-v2:0" \
  --instruction "You are a senior software developer specializing in Python and JavaScript." \
  --agent-resource-role-arn "arn:aws:iam::ACCOUNT:role/BedrockAgentRole"

# Get agent ID from output
AGENT_ID=$(aws bedrock-agent list-agents --query 'agentSummaries[0].agentId' --output text)

# Create alias
aws bedrock-agent create-agent-alias \
  --agent-id $AGENT_ID \
  --alias-name "dev"
```

### Step 4: Test Your Agent (2 minutes)

```python
import boto3
import json

bedrock_agent = boto3.client('bedrock-agent-runtime')

def test_agent(agent_id, alias_id, prompt):
    response = bedrock_agent.invoke_agent(
        agentId=agent_id,
        agentAliasId=alias_id,
        sessionId='test-session-001',
        inputText=prompt
    )

    result = ""
    for event in response['completion']:
        if 'chunk' in event:
            result += event['chunk']['bytes'].decode('utf-8')

    return result

# Test
result = test_agent(
    agent_id='YOUR_AGENT_ID',
    alias_id='YOUR_ALIAS_ID',
    prompt='Write a Python function to calculate fibonacci numbers'
)
print(result)
```

## Essential Components Checklist

- [ ] Bedrock model access enabled
- [ ] IAM roles created (Agent, Lambda, KB)
- [ ] DynamoDB tables (state, memory, tasks)
- [ ] S3 buckets (documents, artifacts)
- [ ] First agent created and tested
- [ ] Knowledge base (optional)
- [ ] Action group with Lambda (optional)
- [ ] CloudWatch logging enabled

## Common Agent Patterns

### Pattern 1: Simple Code Generator

```python
# No action groups, just model invocation
agent_config = {
    "agentName": "code-generator",
    "foundationModel": "anthropic.claude-3-5-sonnet-20241022-v2:0",
    "instruction": "Generate clean, well-documented code based on requirements."
}
```

### Pattern 2: Agent with Knowledge Base

```python
# Agent can retrieve from knowledge base
agent_config = {
    "agentName": "documentation-expert",
    "foundationModel": "anthropic.claude-3-5-sonnet-20241022-v2:0",
    "instruction": "Answer questions using the project documentation.",
    "knowledgeBases": [
        {
            "knowledgeBaseId": "KB123",
            "description": "Project documentation and API specs"
        }
    ]
}
```

### Pattern 3: Agent with Actions

```python
# Agent can execute actions via Lambda
agent_config = {
    "agentName": "devops-engineer",
    "foundationModel": "anthropic.claude-3-5-haiku-20241022-v1:0",
    "instruction": "Manage infrastructure and deployments.",
    "actionGroups": [
        {
            "actionGroupName": "terraform-ops",
            "actionGroupExecutor": {
                "lambda": "arn:aws:lambda:REGION:ACCOUNT:function:terraform-ops"
            }
        }
    ]
}
```

## Cost Optimization Tips

1. **Use Haiku for Simple Tasks**

   - 75% cheaper than Sonnet
   - Perfect for testing, simple queries

2. **Implement Caching**

   - Cache knowledge base results
   - Cache common prompts
   - Use ElastiCache Redis

3. **Optimize Prompts**

   - Shorter prompts = fewer tokens
   - Be specific to reduce iterations

4. **Monitor Usage**
   ```bash
   aws cloudwatch get-metric-statistics \
     --namespace AWS/Bedrock \
     --metric-name InvocationCount \
     --dimensions Name=ModelId,Value=anthropic.claude-3-5-sonnet-20241022-v2:0 \
     --start-time 2025-01-01T00:00:00Z \
     --end-time 2025-01-31T23:59:59Z \
     --period 86400 \
     --statistics Sum
   ```

## Troubleshooting

### Agent Not Responding

```bash
# Check agent status
aws bedrock-agent get-agent --agent-id AGENT_ID

# Check CloudWatch logs
aws logs tail /aws/bedrock/agents/AGENT_ID --follow

# Verify IAM role
aws iam get-role --role-name BedrockAgentRole
```

### High Costs

```bash
# Check token usage
aws cloudwatch get-metric-statistics \
  --namespace BedrockAgents \
  --metric-name TokensUsed \
  --statistics Sum \
  --period 3600

# Analyze by agent
aws cloudwatch get-metric-statistics \
  --namespace BedrockAgents \
  --metric-name TokensUsed \
  --dimensions Name=AgentId,Value=AGENT_ID \
  --statistics Sum
```

### Knowledge Base Issues

```bash
# Check ingestion job status
aws bedrock-agent list-ingestion-jobs \
  --knowledge-base-id KB_ID

# Verify OpenSearch collection
aws opensearchserverless list-collections
```

## Next Steps

1. **Add More Agents**: Create specialized agents for different tasks
2. **Build Workflows**: Use Step Functions for multi-agent orchestration
3. **Implement Coordination**: Add hierarchical or mesh coordination
4. **Production Hardening**: Add monitoring, alerting, backup
5. **Optimize Costs**: Implement caching, use appropriate models

## Quick Reference - AWS CLI Commands

```bash
# List all agents
aws bedrock-agent list-agents

# Invoke agent
aws bedrock-agent-runtime invoke-agent \
  --agent-id AGENT_ID \
  --agent-alias-id ALIAS_ID \
  --session-id SESSION_ID \
  --input-text "Your prompt here"

# Create knowledge base
aws bedrock-agent create-knowledge-base \
  --name "my-kb" \
  --role-arn "arn:aws:iam::ACCOUNT:role/BedrockKBRole" \
  --knowledge-base-configuration '{...}'

# Start ingestion
aws bedrock-agent start-ingestion-job \
  --knowledge-base-id KB_ID \
  --data-source-id DS_ID

# Delete agent
aws bedrock-agent delete-agent --agent-id AGENT_ID
```

## Minimal Working Example

**Complete working example in 50 lines:**

```python
import boto3
import json

# Initialize clients
bedrock = boto3.client('bedrock-agent')
bedrock_runtime = boto3.client('bedrock-agent-runtime')
iam = boto3.client('iam')

# 1. Create IAM role (if not exists)
role_name = 'BedrockAgentMinimalRole'
assume_role_policy = {
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow",
        "Principal": {"Service": "bedrock.amazonaws.com"},
        "Action": "sts:AssumeRole"
    }]
}

try:
    role = iam.create_role(
        RoleName=role_name,
        AssumeRolePolicyDocument=json.dumps(assume_role_policy)
    )
    role_arn = role['Role']['Arn']
except iam.exceptions.EntityAlreadyExistsException:
    role_arn = iam.get_role(RoleName=role_name)['Role']['Arn']

# 2. Attach policy
iam.put_role_policy(
    RoleName=role_name,
    PolicyName='BedrockModelAccess',
    PolicyDocument=json.dumps({
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Action": "bedrock:InvokeModel",
            "Resource": "arn:aws:bedrock:*::foundation-model/*"
        }]
    })
)

# 3. Create agent
agent = bedrock.create_agent(
    agentName='minimal-coder',
    foundationModel='anthropic.claude-3-5-haiku-20241022-v1:0',
    instruction='You are a helpful coding assistant.',
    agentResourceRoleArn=role_arn
)
agent_id = agent['agent']['agentId']

# 4. Prepare agent
bedrock.prepare_agent(agentId=agent_id)

# 5. Create alias
alias = bedrock.create_agent_alias(
    agentId=agent_id,
    agentAliasName='prod'
)
alias_id = alias['agentAlias']['agentAliasId']

# 6. Invoke agent
response = bedrock_runtime.invoke_agent(
    agentId=agent_id,
    agentAliasId=alias_id,
    sessionId='demo-session',
    inputText='Write a hello world function in Python'
)

# 7. Print response
for event in response['completion']:
    if 'chunk' in event:
        print(event['chunk']['bytes'].decode('utf-8'), end='')
```

## Resources

- [AWS Bedrock Agents Documentation](https://docs.aws.amazon.com/bedrock/latest/userguide/agents.html)
- [Bedrock Pricing](https://aws.amazon.com/bedrock/pricing/)
- [Claude Model Cards](https://www.anthropic.com/claude)
- [Example Terraform Modules](../terraform/modules/)

---

**Ready to deploy? Start with the 5-minute quick deploy above!**
