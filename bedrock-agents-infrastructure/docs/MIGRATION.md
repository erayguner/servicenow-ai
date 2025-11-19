# Bedrock Agents Infrastructure - Migration Guide from claude-flow

Complete guide for migrating from Claude-Flow orchestration to AWS Bedrock Agents infrastructure.

## Comparison Matrix

### Architecture Comparison

| Aspect | Claude-Flow | Bedrock Agents |
|--------|------------|----------------|
| **Hosting** | Local/Cloud (via MCP) | AWS Managed |
| **Agent Model** | Claude variants | Claude, Mistral, others |
| **State Management** | In-memory/File-based | DynamoDB, RDS |
| **Orchestration** | Claude-Flow commands | Step Functions |
| **Scalability** | Vertical | Horizontal (auto-scaling) |
| **Cost Model** | Token-based | Token + infrastructure |
| **Compliance** | Flexible | AWS compliance built-in |
| **Monitoring** | Custom logging | CloudWatch native |

### Feature Mapping

| Feature | Claude-Flow | Bedrock | Notes |
|---------|------------|---------|-------|
| Agent creation | JS/TS objects | Terraform/SDK | IaC approach |
| Multi-agent coordination | Task tool | Step Functions | More mature |
| Knowledge bases | In-memory | OpenSearch + S3 | Persistent |
| Action groups | Custom functions | Lambda + schema | Type-safe |
| Session management | Memory-based | DynamoDB | Durable |
| Monitoring | Logs file | CloudWatch | Enterprise-grade |

## Migration Phases

### Phase 1: Assessment (1-2 weeks)

**Inventory Existing Agents**

```python
# Document current agent configuration
agents_inventory = {
    'research-agent': {
        'framework': 'claude-flow',
        'model': 'claude-3-sonnet',
        'action_groups': ['web-search', 'document-retrieval'],
        'complexity': 'medium',
        'usage_monthly': 10000
    },
    'code-agent': {
        'framework': 'claude-flow',
        'model': 'claude-3-opus',
        'action_groups': ['code-generation', 'testing'],
        'complexity': 'high',
        'usage_monthly': 5000
    }
}
```

**Compatibility Check**

```bash
# Analyze dependencies
grep -r "claude-flow" . --include="*.py" --include="*.js"
grep -r "@Task\|@Agent" . --include="*.py"
grep -r "invoke_agent\|bedrock_invoke" . --include="*.py"
```

**Cost Analysis**

```python
# Calculate current vs projected costs
claude_flow_cost = monthly_invocations * avg_tokens_per_invocation * token_price
bedrock_cost = monthly_invocations * avg_tokens_per_invocation * token_price + infrastructure_cost

print(f"Current (Claude-Flow): ${claude_flow_cost}")
print(f"Projected (Bedrock): ${bedrock_cost}")
print(f"Difference: {((bedrock_cost - claude_flow_cost) / claude_flow_cost * 100):.1f}%")
```

### Phase 2: Planning (1 week)

**Migration Strategy**

Option 1: **Big Bang** - Migrate all agents at once
- Pros: Quick transition, clear cutover date
- Cons: High risk, potential downtime
- Best for: Small deployments (< 5 agents)

Option 2: **Phased** - Migrate agents by priority
- Pros: Lower risk, validate patterns
- Cons: Extended migration period, dual maintenance
- Best for: Medium deployments (5-20 agents)

Option 3: **Hybrid** - Run both in parallel
- Pros: Zero downtime, gradual validation
- Cons: Complex dual systems, higher cost
- Best for: Large critical deployments

**Architecture Design**

```
┌─────────────────────────────────────────┐
│     Client Applications                  │
└──────────────┬──────────────────────────┘
               │
        ┌──────┴────────┐
        ▼                ▼
   ┌─────────┐      ┌──────────────┐
   │ API     │      │ API Gateway  │
   │ Gateway │      │ (Bedrock)    │
   └────┬────┘      └────┬─────────┘
        │                │
   ┌────┴────┐      ┌────┴──────────────────┐
   │ Legacy  │      │  Bedrock Agents       │
   │ Claude- │      │  + Step Functions     │
   │ Flow    │      │  + Lambda Action Grps │
   └─────────┘      └───────────────────────┘
```

### Phase 3: Infrastructure Setup (1-2 weeks)

**Deploy Bedrock Infrastructure**

```bash
cd bedrock-agents-infrastructure/terraform
terraform init
terraform plan -var-file="environments/staging.tfvars"
terraform apply -var-file="environments/staging.tfvars"
```

**Create Migration Workspace**

```bash
# Create separate environment for testing
mkdir -p migration-workspace
cd migration-workspace

# Set up Python environment
python3 -m venv venv
source venv/bin/activate
pip install boto3 bedrock bedrock-agents
```

### Phase 4: Agent Migration (2-4 weeks)

#### Example: Migrate Research Agent

**Claude-Flow Version**

```python
# Original claude-flow agent
class ResearchAgent(Agent):
    def __init__(self):
        super().__init__(
            name="research-agent",
            model="claude-3-sonnet-20240229-v1:0",
            description="Research and gather information"
        )
        self.add_action_group("web-search", WebSearchAction)
        self.add_action_group("document-retrieval", DocumentAction)

    async def execute(self, query: str) -> str:
        response = await self.invoke(query)
        return response
```

**Bedrock Version**

```python
# Migrated to Bedrock Agents
import boto3
import json

bedrock_agent = boto3.client('bedrock-agent')
bedrock_runtime = boto3.client('bedrock-agent-runtime')

# Step 1: Create agent (one-time)
agent_config = {
    'agentName': 'research-agent-bedrock',
    'description': 'Research and gather information',
    'foundationModel': 'anthropic.claude-3-sonnet-20240229-v1:0',
    'agentInstruction': 'You are a research specialist...',
    'agentResourceRoleArn': 'arn:aws:iam::ACCOUNT:role/bedrock-agent-role'
}

agent = bedrock_agent.create_agent(**agent_config)
agent_id = agent['agent']['agentId']

# Step 2: Create and configure action groups
# (via Terraform or CLI)

# Step 3: Prepare agent (required before invocation)
bedrock_agent.prepare_agent(agentId=agent_id)

# Step 4: Invoke agent (replaces execute)
def execute(query: str) -> str:
    response = bedrock_runtime.invoke_agent(
        agentId=agent_id,
        agentAliasId='PROD',
        sessionId=f'research-session-{uuid.uuid4()}',
        inputText=query
    )
    return response['output']

# Usage
result = execute("Research latest AI trends")
```

#### Migration Checklist

```yaml
For Each Agent:
  - [ ] Document current functionality
  - [ ] Identify all action groups/dependencies
  - [ ] Design Bedrock equivalent
  - [ ] Create Terraform configuration
  - [ ] Implement Lambda action handlers
  - [ ] Create unit tests
  - [ ] Perform load testing
  - [ ] Validate against production data
  - [ ] Create runbooks for operations
  - [ ] Document any behavior changes
  - [ ] Schedule cutover
  - [ ] Execute cutover
  - [ ] Monitor for 24 hours
```

### Phase 5: Action Group Migration (1-2 weeks)

#### Web Search Action Group

**Claude-Flow Original**

```python
class WebSearchAction:
    async def execute(self, query: str) -> List[Dict]:
        results = await search_api.search(query)
        return results
```

**Bedrock Lambda Handler**

```python
import json
import boto3

def lambda_handler(event, context):
    """Web search Lambda action group"""

    body = json.loads(event.get('body', '{}'))
    query = body.get('query')
    max_results = body.get('max_results', 5)

    # Use search service (Google, Bing, etc.)
    results = perform_search(query, max_results)

    return {
        'statusCode': 200,
        'body': json.dumps({
            'query': query,
            'results': results,
            'count': len(results)
        })
    }

def perform_search(query: str, limit: int) -> List[Dict]:
    # Implement actual search logic
    pass
```

**OpenAPI Schema**

```yaml
openapi: 3.0.0
info:
  title: Web Search API
  version: 1.0.0
paths:
  /search:
    post:
      operationId: webSearch
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              properties:
                query:
                  type: string
                  description: Search query
                max_results:
                  type: integer
                  description: Maximum results to return
      responses:
        '200':
          description: Search results
          content:
            application/json:
              schema:
                type: object
                properties:
                  results:
                    type: array
                    items:
                      type: object
```

### Phase 6: Knowledge Base Migration (1-2 weeks)

**Export from Claude-Flow**

```python
# Extract knowledge from claude-flow memory
def export_knowledge():
    knowledge = memory_store.get_all()

    # Serialize to documents
    documents = []
    for key, value in knowledge.items():
        doc = {
            'id': key,
            'content': json.dumps(value),
            'metadata': {
                'source': 'claude-flow-migration',
                'migrated_at': datetime.utcnow().isoformat()
            }
        }
        documents.append(doc)

    # Save to S3
    s3 = boto3.client('s3')
    s3.put_object(
        Bucket='knowledge-base-migration',
        Key='documents.jsonl',
        Body=json.dumps(documents)
    )

    return len(documents)
```

**Import to Bedrock**

```python
# Import to Bedrock Knowledge Base
def import_knowledge(bucket: str, key: str):
    bedrock_agent = boto3.client('bedrock-agent')

    # Create data source
    data_source = bedrock_agent.create_data_source(
        knowledgeBaseId='kb-xxx',
        dataSourceConfiguration={
            'type': 'S3',
            's3Configuration': {
                'bucketArn': f'arn:aws:s3:::{bucket}',
                'inclusionPrefixes': [key.split('/')[0]]
            }
        },
        name='claude-flow-migration'
    )

    # Start ingestion
    job = bedrock_agent.start_ingestion_job(
        knowledgeBaseId='kb-xxx',
        dataSourceId=data_source['dataSource']['dataSourceId']
    )

    # Monitor ingestion
    while True:
        status = bedrock_agent.get_ingestion_job(
            knowledgeBaseId='kb-xxx',
            dataSourceId=data_source['dataSource']['dataSourceId'],
            ingestionJobId=job['ingestionJob']['ingestionJobId']
        )

        if status['ingestionJob']['status'] in ['COMPLETE', 'FAILED']:
            return status

        time.sleep(5)
```

### Phase 7: Testing & Validation (2-3 weeks)

**Unit Tests**

```python
import pytest
import boto3
from moto import mock_bedrock

@mock_bedrock
def test_agent_creation():
    client = boto3.client('bedrock-agent', region_name='us-east-1')

    response = client.create_agent(
        agentName='test-agent',
        foundationModel='anthropic.claude-3-haiku-20240307-v1:0',
        agentInstruction='Test agent',
        agentResourceRoleArn='arn:aws:iam::123456789:role/test-role'
    )

    assert response['agent']['agentName'] == 'test-agent'
    assert response['agent']['agentStatus'] == 'CREATING'

@mock_bedrock
def test_action_group_invocation():
    # Test Lambda action group responses
    pass
```

**Integration Tests**

```python
def test_end_to_end_workflow():
    """Test complete workflow"""

    client = boto3.client('bedrock-agent-runtime')

    # Invoke agent
    response = client.invoke_agent(
        agentId='research-agent',
        agentAliasId='PROD',
        sessionId='test-session',
        inputText='Test query'
    )

    # Validate response
    assert 'output' in response
    assert len(response['output']) > 0
```

**Load Testing**

```python
import concurrent.futures
import time

def load_test(agent_id: str, num_requests: int = 100):
    """Load test agent"""

    client = boto3.client('bedrock-agent-runtime')

    def invoke_agent(i):
        start = time.time()
        response = client.invoke_agent(
            agentId=agent_id,
            agentAliasId='PROD',
            sessionId=f'load-test-{i}',
            inputText=f'Test query {i}'
        )
        return time.time() - start

    with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
        durations = list(executor.map(invoke_agent, range(num_requests)))

    print(f"Average latency: {sum(durations)/len(durations):.3f}s")
    print(f"Min: {min(durations):.3f}s, Max: {max(durations):.3f}s")
```

### Phase 8: Cutover (1-2 days)

**Pre-Cutover Checklist**

- [ ] All agents migrated and tested
- [ ] All action groups deployed and validated
- [ ] Knowledge base fully migrated
- [ ] Monitoring and alerts configured
- [ ] Rollback plan documented
- [ ] Team trained on new system
- [ ] Customer communication prepared

**Cutover Procedure**

```bash
# 1. Final sync of any data
./scripts/final-sync.sh

# 2. Enable Bedrock endpoints
aws apigateway update-stage \
  --rest-api-id api-xxx \
  --stage-name prod \
  --patch-operations op=replace,path=/*/throttle/burstLimit,value=5000

# 3. Monitor metrics
./scripts/monitor-cutover.sh

# 4. Gradual traffic shift (if using load balancer)
for percent in 10 25 50 75 100; do
  ./scripts/shift-traffic.sh $percent
  sleep 300  # 5 minutes
  ./scripts/check-health.sh
done
```

**Rollback Procedure**

```bash
# If issues detected within 24 hours:
./scripts/rollback.sh

# This will:
# 1. Redirect traffic back to claude-flow
# 2. Preserve Bedrock data for investigation
# 3. Stop Bedrock resources to reduce costs
```

### Phase 9: Post-Cutover Optimization (1-2 weeks)

**Performance Tuning**

```python
# Analyze CloudWatch metrics
def analyze_performance():
    cloudwatch = boto3.client('cloudwatch')

    metrics = cloudwatch.get_metric_statistics(
        Namespace='AWS/Bedrock',
        MetricName='Invocations',
        StartTime='datetime.utcnow() - timedelta(days=1)',
        EndTime='datetime.utcnow()',
        Period=60,
        Statistics=['Sum', 'Average']
    )

    # Recommend optimizations
    for metric in metrics['Datapoints']:
        if metric['Sum'] > 10000:
            print("Consider caching frequent queries")
        if metric['Average'] > 2.0:
            print("Consider using Haiku for simple queries")
```

**Cost Optimization**

```python
# Review and optimize costs
def optimize_costs():
    ce = boto3.client('ce')

    # Get cost breakdown
    response = ce.get_cost_and_usage(
        TimePeriod={
            'Start': '2025-01-01',
            'End': '2025-01-31'
        },
        Granularity='DAILY',
        Metrics=['BlendedCost'],
        GroupBy=[
            {'Type': 'DIMENSION', 'Key': 'SERVICE'}
        ]
    )

    # Identify optimization opportunities
    for result in response['ResultsByTime']:
        for group in result['Groups']:
            if group['Keys'][0] == 'Amazon Bedrock':
                cost = float(group['Metrics']['BlendedCost']['Amount'])
                print(f"Daily Bedrock cost: ${cost:.2f}")
```

## Hybrid Approach (Running Both in Parallel)

```
┌─────────────────────────────────────────┐
│         Client Application               │
└──────────────┬──────────────────────────┘
               │
        ┌──────┴────────┐
        ▼                ▼
   ┌─────────────┐  ┌──────────────┐
   │ Claude-Flow │  │ Bedrock      │
   │ (Legacy)    │  │ (New)        │
   └─────────────┘  └──────────────┘
        │                │
   ┌────┴────┐      ┌────┴──────────────┐
   │ Agents  │      │  Bedrock Agents   │
   │ v1.0    │      │  v1.0 Beta        │
   └─────────┘      └───────────────────┘
```

**Implementation**

```python
def invoke_agent_with_fallback(query: str, agent_name: str):
    """Invoke Bedrock with fallback to claude-flow"""

    try:
        # Try Bedrock first
        response = bedrock_runtime.invoke_agent(
            agentId=agent_name,
            agentAliasId='PROD',
            sessionId=uuid.uuid4(),
            inputText=query
        )

        # Log successful Bedrock invocation
        log_metric('bedrock_success', 1)
        return response

    except Exception as e:
        # Fallback to claude-flow
        logger.warning(f"Bedrock failed, falling back to claude-flow: {e}")
        log_metric('bedrock_fallback', 1)

        response = claude_flow_agent.invoke(query)
        return response
```

## Rollback Procedures

### Full Rollback

```bash
# If critical issues found
terraform destroy -var-file="environments/prod.tfvars"

# Restore from Claude-Flow backups
./scripts/restore-from-backup.sh claude-flow-backup-latest
```

### Partial Rollback

```bash
# Roll back specific agents
terraform destroy -target="aws_bedrock_agent.research-agent" \
  -var-file="environments/prod.tfvars"

# Keep other agents running
```

## Common Issues & Solutions

### Issue: Knowledge Base Indexing Slow

**Solution**: Batch uploads in smaller chunks

```python
def batch_upload_documents(documents: List[str], batch_size: int = 100):
    for i in range(0, len(documents), batch_size):
        batch = documents[i:i+batch_size]
        bedrock_agent.start_ingestion_job(
            knowledgeBaseId='kb-xxx',
            dataSourceId='ds-xxx'
        )
```

### Issue: High Latency

**Solution**: Implement caching and use appropriate models

```python
# Cache frequent queries
# Use Haiku for simple requests
# Use Sonnet/Opus only when needed
```

### Issue: Cost Higher Than Expected

**Solution**: Review and optimize token usage

```python
# Implement request batching
# Use model selection strategy
# Enable caching
# Review knowledge base size
```

---

**Version**: 1.0.0
**Last Updated**: 2025-01-17
