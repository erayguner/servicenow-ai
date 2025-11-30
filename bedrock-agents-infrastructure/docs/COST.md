# Bedrock Agents Infrastructure - Cost Analysis

Detailed cost analysis, optimization strategies, and monitoring for
multi-environment deployments.

## Monthly Cost Estimates

### Development Environment

**Configuration**

- 2 agents (basic models)
- 100 invocations/day
- Knowledge base: 50 MB
- Lambda: 128MB, 1s average duration
- Data storage: Minimal

**Breakdown**

| Service               | Usage                 | Cost             |
| --------------------- | --------------------- | ---------------- |
| Bedrock (Haiku)       | 7,300 invocations     | $1.50            |
| Lambda                | 7,300 executions × 1s | $0.15            |
| OpenSearch Serverless | 10 OCU × 730 hours    | $50.00           |
| RDS (t3.micro)        | On-demand             | $15.00           |
| S3                    | Storage + requests    | $5.00            |
| DynamoDB              | On-demand             | $5.00            |
| CloudWatch            | Logs + metrics        | $10.00           |
| **Total**             |                       | **$86.65/month** |

**Annual Cost**: ~$1,040

### Staging Environment

**Configuration**

- 5 agents (mixed models)
- 1,000 invocations/day
- Knowledge base: 500 MB
- Lambda: 256MB, 2s average duration
- Moderate data storage

**Breakdown**

| Service               | Usage                      | Cost              |
| --------------------- | -------------------------- | ----------------- |
| Bedrock (Sonnet)      | 36,500 invocations         | $25.00            |
| Lambda                | 36,500 executions × 2s     | $1.46             |
| OpenSearch Serverless | 20 OCU × 730 hours         | $100.00           |
| RDS (db.t3.small)     | On-demand, Multi-AZ backup | $80.00            |
| S3                    | Storage + requests         | $20.00            |
| DynamoDB              | On-demand                  | $25.00            |
| CloudWatch            | Logs + metrics             | $30.00            |
| Step Functions        | 36,500 state transitions   | $1.50             |
| **Total**             |                            | **$283.00/month** |

**Annual Cost**: ~$3,400

### Production Environment

**Configuration**

- 10+ agents (all models)
- 50,000+ invocations/day
- Knowledge base: 5+ GB
- Lambda: 512MB-1024MB, 3-5s average
- Heavy data storage and processing

**Breakdown**

| Service                | Usage                          | Cost                |
| ---------------------- | ------------------------------ | ------------------- |
| Bedrock (Mixed Models) | 1.8M invocations               | $3,500.00           |
| Lambda                 | 1.8M executions × 3.5s average | $315.00             |
| OpenSearch Serverless  | 40 OCU × 730 hours             | $200.00             |
| RDS (db.r6i.xlarge)    | Multi-AZ HA, backups           | $400.00             |
| S3                     | 50 GB storage + heavy access   | $150.00             |
| DynamoDB               | On-demand, GSI                 | $200.00             |
| CloudWatch             | Logs + metrics + alarms        | $100.00             |
| Step Functions         | 1.8M state transitions         | $90.00              |
| NAT Gateway            | Data transfer + hours          | $100.00             |
| **Total**              |                                | **$5,055.00/month** |

**Annual Cost**: ~$60,660

## Bedrock Pricing Details

### Input/Output Token Pricing

**Claude 3 Models (us-east-1)**

| Model  | Input              | Output             |
| ------ | ------------------ | ------------------ |
| Haiku  | $0.00025/1K tokens | $0.00125/1K tokens |
| Sonnet | $0.003/1K tokens   | $0.015/1K tokens   |
| Opus   | $0.015/1K tokens   | $0.075/1K tokens   |

**Example Calculation (10,000 requests)**

```
Haiku:
  Input:  10,000 requests × 500 avg tokens × $0.00025 = $1.25
  Output: 10,000 requests × 200 avg tokens × $0.00125 = $2.50
  Total: $3.75

Sonnet:
  Input:  10,000 requests × 500 avg tokens × $0.003 = $15.00
  Output: 10,000 requests × 200 avg tokens × $0.015 = $30.00
  Total: $45.00

Opus:
  Input:  10,000 requests × 500 avg tokens × $0.015 = $75.00
  Output: 10,000 requests × 200 avg tokens × $0.075 = $150.00
  Total: $225.00
```

## Cost Optimization Strategies

### 1. Model Selection Strategy

Choose the right model for each agent:

```
┌─────────────────────────────────────────┐
│      Task Complexity vs Cost             │
├─────────────────────────────────────────┤
│ Simple parsing/routing → Haiku (fast)   │
│ Standard Q&A, analysis  → Sonnet        │
│ Complex reasoning       → Opus          │
│ Specialized/fine-tuned  → Custom Models │
└─────────────────────────────────────────┘
```

**Implementation**

```python
def select_model_for_task(task_type: str) -> str:
    """Select optimal model based on task"""
    model_map = {
        'routing': 'anthropic.claude-3-haiku-20240307-v1:0',
        'analysis': 'anthropic.claude-3-sonnet-20240229-v1:0',
        'reasoning': 'anthropic.claude-3-opus-20240229-v1:0',
        'code': 'anthropic.claude-3-sonnet-20240229-v1:0',
    }
    return model_map.get(task_type, 'anthropic.claude-3-haiku-20240307-v1:0')
```

### 2. Caching Strategy

Implement semantic caching to reduce API calls:

```python
import hashlib
import json
from functools import lru_cache

@lru_cache(maxsize=1000)
def cached_agent_invocation(query_hash: str) -> str:
    """Cache agent responses"""
    # Implementation with TTL
    pass

def invoke_with_cache(agent_id: str, query: str):
    """Invoke agent with caching"""
    query_hash = hashlib.sha256(query.encode()).hexdigest()

    # Check cache first
    cached = cache_store.get(query_hash)
    if cached:
        return cached

    # Call agent
    response = bedrock_runtime.invoke_agent(
        agentId=agent_id,
        agentAliasId='PROD',
        sessionId=f'cached-{query_hash}',
        inputText=query
    )

    # Cache result
    cache_store.set(query_hash, response, ttl=3600)  # 1 hour TTL
    return response
```

### 3. Batch Processing

Group related requests:

```python
def batch_process_queries(queries: List[str], agent_id: str):
    """Process multiple queries in single session"""
    session_id = f'batch-session-{int(time.time())}'
    results = []

    for i, query in enumerate(queries):
        # Maintain session for context
        response = bedrock_runtime.invoke_agent(
            agentId=agent_id,
            agentAliasId='PROD',
            sessionId=session_id,  # Reuse session
            inputText=query
        )
        results.append(response)

    return results
```

**Cost Savings**: 20-30% reduction through context reuse

### 4. Reserved Capacity

For predictable workloads:

```
Monthly Invocations | Capacity Type | Savings
──────────────────────────────────────────────
< 100K              | On-demand     | None
100K - 1M           | Monthly       | 15-20%
1M - 10M            | Yearly        | 25-30%
10M+                | Dedicated     | 40-50%
```

### 5. Knowledge Base Optimization

```python
# Reduce indexing costs with selective ingestion
def ingest_documents_selectively(
    knowledge_base_id: str,
    documents: List[str],
    filter_duplicates: bool = True
) -> int:
    """Ingest only necessary documents"""

    bedrock_agent = boto3.client('bedrock-agent')

    # Remove duplicates
    if filter_duplicates:
        documents = list(set(documents))

    # Calculate token usage before ingestion
    total_tokens = sum(estimate_tokens(doc) for doc in documents)
    estimated_cost = total_tokens * 0.0001  # Example pricing

    print(f"Estimated ingestion cost: ${estimated_cost}")

    # Batch upload
    for doc_batch in batch(documents, 100):
        bedrock_agent.start_ingestion_job(
            knowledgeBaseId=knowledge_base_id,
            dataSourceId='ds-xxx',
            documents=doc_batch
        )

    return len(documents)

def estimate_tokens(text: str) -> int:
    """Estimate token count"""
    # Rough approximation: 1 token per 4 chars
    return len(text) // 4
```

### 6. Lambda Optimization

```python
# Right-size Lambda functions
import time
import json

def optimize_lambda_config():
    """Optimize Lambda memory and timeout"""

    lambda_client = boto3.client('lambda')

    # Analyze CloudWatch metrics
    cloudwatch = boto3.client('cloudwatch')

    response = cloudwatch.get_metric_statistics(
        Namespace='AWS/Lambda',
        MetricName='Duration',
        Dimensions=[
            {'Name': 'FunctionName', 'Value': 'action-group-handler'}
        ],
        StartTime='datetime.utcnow() - timedelta(days=7)',
        EndTime='datetime.utcnow()',
        Period=300,
        Statistics=['Average', 'Maximum']
    )

    max_duration = max(d['Maximum'] for d in response['Datapoints'])

    # Set timeout 10% above max observed
    new_timeout = int(max_duration * 1.1)

    # Update function
    lambda_client.update_function_configuration(
        FunctionName='action-group-handler',
        Timeout=new_timeout,
        MemorySize=512  # Optimize based on performance needs
    )
```

## Cost Monitoring

### CloudWatch Dashboard

```python
def create_cost_dashboard():
    """Create real-time cost monitoring dashboard"""

    cloudwatch = boto3.client('cloudwatch')

    dashboard_body = {
        'widgets': [
            {
                'type': 'metric',
                'properties': {
                    'metrics': [
                        ['AWS/Bedrock', 'Invocations'],
                        ['AWS/Lambda', 'Duration'],
                        ['AWS/OpenSearchServerless', 'IndexingDocuments'],
                    ],
                    'period': 300,
                    'stat': 'Sum',
                    'region': 'us-east-1'
                }
            }
        ]
    }

    cloudwatch.put_dashboard(
        DashboardName='bedrock-cost-monitoring',
        DashboardBody=json.dumps(dashboard_body)
    )
```

### Budget Alerts

```hcl
# Terraform
resource "aws_budgets_budget" "bedrock_agents_budget" {
  name              = "bedrock-agents-monthly"
  budget_type       = "MONTHLY"
  limit_amount      = "1000"
  limit_unit        = "USD"
  time_period_start = "2025-01-01"
  time_period_end   = "2087-12-31"

  cost_filters = {
    Service = ["Amazon Bedrock"]
  }
}

resource "aws_budgets_budget_notification" "bedrock_agents_notification" {
  budget_name              = aws_budgets_budget.bedrock_agents_budget.name
  comparison_operator      = "GREATER_THAN"
  notification_type        = "ACTUAL"
  threshold                = 80
  threshold_type           = "PERCENTAGE"
  notification_channel_arns = [aws_sns_topic.budget_alerts.arn]
}
```

## Cost Reduction Checklist

- [ ] Use Haiku for simple routing and parsing tasks
- [ ] Implement request caching with TTL
- [ ] Use batch processing where possible
- [ ] Right-size Lambda memory and timeout
- [ ] Enable knowledge base batching
- [ ] Monitor and alert on cost anomalies
- [ ] Use Reserved Capacity for production
- [ ] Archive old conversations and logs
- [ ] Implement query rate limiting
- [ ] Regular cost reviews and optimization

## Cost Comparison: Bedrock vs Competitors

| Feature        | Bedrock     | Claude API  | Self-Hosted  |
| -------------- | ----------- | ----------- | ------------ |
| Cost/1M tokens | $0.35-$1.50 | $0.30-$0.90 | $50-200      |
| Setup time     | <1 hour     | <1 hour     | 1-2 weeks    |
| Infrastructure | Managed     | Managed     | Self-managed |
| Scalability    | Auto        | Auto        | Manual       |
| Compliance     | AWS         | Anthropic   | Full control |

---

**Version**: 1.0.0 **Last Updated**: 2025-01-17
