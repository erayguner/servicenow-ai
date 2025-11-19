# Bedrock Agents Documentation

Complete guide to agent types, configuration, action groups, and knowledge base setup.

## Agent Types & Purposes

### 1. Core Agents (Specialist Agents)

Focused agents specialized for specific domains.

#### Research Agent
- **Purpose**: Research and gather information
- **Inputs**: Query, research domain, depth level
- **Outputs**: Findings, sources, summary
- **Action Groups**: Web search, document retrieval, database query
- **Example**:
```python
research_agent = {
    "name": "research-agent",
    "model_id": "anthropic.claude-3-sonnet-20240229-v1:0",
    "role": "Research specialist",
    "instructions": "Conduct thorough research on topics..."
}
```

#### Analysis Agent
- **Purpose**: Analyze data and generate insights
- **Inputs**: Dataset, analysis type, metrics
- **Outputs**: Analysis report, visualizations, recommendations
- **Action Groups**: Data processing, statistical analysis, charting
- **Example**:
```python
analysis_agent = {
    "name": "analysis-agent",
    "model_id": "anthropic.claude-3-sonnet-20240229-v1:0",
    "role": "Data analyst",
    "instructions": "Analyze provided data and generate insights..."
}
```

#### Code Agent
- **Purpose**: Write and review code
- **Inputs**: Specification, language, constraints
- **Outputs**: Code, documentation, tests
- **Action Groups**: Code generation, linting, testing
- **Example**:
```python
code_agent = {
    "name": "code-agent",
    "model_id": "anthropic.claude-3-sonnet-20240229-v1:0",
    "role": "Senior software engineer",
    "instructions": "Write clean, well-tested code..."
}
```

### 2. Orchestration Agents

Coordinate multiple agents and manage workflows.

#### Coordinator Agent
- **Purpose**: Manage multi-agent workflows
- **Inputs**: Task, agent registry, constraints
- **Outputs**: Workflow results, agent decisions log
- **Action Groups**: Agent delegation, workflow management, consensus building
- **Configuration**:
```yaml
name: coordinator-agent
model: anthropic.claude-3-opus-20240229-v1:0
role: Orchestration specialist
instructions: |
  Coordinate multiple specialized agents.
  Delegate tasks appropriately.
  Ensure consensus on decisions.
```

#### Router Agent
- **Purpose**: Route requests to appropriate agents
- **Inputs**: User request, agent capabilities
- **Outputs**: Routed request, selected agent
- **Action Groups**: Agent lookup, request parsing
- **Configuration**:
```yaml
name: router-agent
model: anthropic.claude-3-haiku-20240307-v1:0
role: Request router
instructions: |
  Route incoming requests to specialized agents.
  Consider agent capabilities and workload.
```

### 3. SPARC Agents

Implement Specification, Pseudocode, Architecture, Refinement, Completion methodology.

#### Specification Agent
- **Purpose**: Define requirements and specifications
- **Action Groups**: Requirement gathering, documentation, validation
- **Outputs**: Detailed specifications document

#### Pseudocode Agent
- **Purpose**: Design algorithms and high-level logic
- **Action Groups**: Algorithm design, optimization analysis
- **Outputs**: Pseudocode, design rationale

#### Architecture Agent
- **Purpose**: Design system architecture
- **Action Groups**: Architecture documentation, diagram generation
- **Outputs**: Architecture design, component definitions

#### Refinement Agent
- **Purpose**: Implement and test code
- **Action Groups**: Code generation, testing, debugging
- **Outputs**: Production code, test suites

### 4. Specialized Agents

Custom agents for specific business logic.

#### ServiceNow Integration Agent
- **Purpose**: Interact with ServiceNow APIs
- **Action Groups**:
  - Create/update incidents
  - Query knowledge base
  - Change management
- **Configuration**:
```python
servicenow_agent = {
    "name": "servicenow-agent",
    "instructions": "Interact with ServiceNow for ticket management...",
    "action_groups": [
        {
            "name": "servicenow-api",
            "description": "ServiceNow REST API integration",
            "action_type": "Lambda",
            "lambda_arn": "arn:aws:lambda:region:account:function:servicenow-api-handler"
        }
    ]
}
```

#### Email Agent
- **Purpose**: Send and manage emails
- **Action Groups**:
  - Send email
  - Query mailbox
  - Create calendar events

#### Document Processing Agent
- **Purpose**: Extract and process documents
- **Action Groups**:
  - Text extraction
  - OCR processing
  - Document classification

### 5. Coordinator Agents

Implement consensus and distributed coordination patterns.

#### Byzantine Fault Tolerant Coordinator
- **Purpose**: Reach consensus despite faulty agents
- **Outputs**: Consensus decision with validation proof

#### RAFT Consensus Manager
- **Purpose**: Manage distributed state with RAFT protocol
- **Features**: Leader election, log replication

#### Gossip Protocol Coordinator
- **Purpose**: Propagate information across agent network
- **Features**: Eventual consistency, anti-entropy

## Agent Configuration

### Basic Configuration

```hcl
# Terraform example
resource "aws_bedrock_agent" "main" {
  agent_name           = "my-agent"
  agent_resource_role_arn = aws_iam_role.agent_role.arn
  description          = "My custom agent"
  foundation_model_arn = "arn:aws:bedrock:${var.aws_region}::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0"

  agent_instruction = "You are a helpful assistant that..."

  tags = {
    Environment = var.environment
    Project     = "servicenow-ai"
  }
}
```

### Advanced Configuration

```hcl
# With memory and guardrails
resource "aws_bedrock_agent" "advanced" {
  agent_name = "advanced-agent"

  agent_instruction = "..."
  foundation_model_arn = "..."
  agent_resource_role_arn = aws_iam_role.agent_role.arn

  # Agent memory
  agent_memory_configuration {
    enabled_memory_types = ["LONG_TERM_MEMORY"]
  }

  # Add action groups
  action_groups {
    action_group_name           = "web-search"
    action_group_executor_role_arn = aws_iam_role.action_executor.arn

    api_schema = {
      payload = file("${path.module}/schemas/web-search-openapi.json")
    }
  }

  # Add knowledge base
  knowledge_bases {
    description         = "Company knowledge base"
    knowledge_base_state = "ENABLED"
    knowledge_base_id   = aws_bedrock_knowledge_base.main.id
  }

  prompt_override_configuration {
    prompt_configurations {
      prompt_type = "ORCHESTRATION"
      prompt_creation_mode = "OVERRIDDEN"
      prompt_state = "ENABLED"
      base_prompt_template = "You are a helpful assistant. Use the provided tools..."
      inference_parameters {
        max_length = 2000
        temperature = 0.7
        top_p = 0.9
      }
    }
  }
}
```

### Python SDK Configuration

```python
import boto3
from botocore.exceptions import ClientError

bedrock_client = boto3.client('bedrock-agent', region_name='us-east-1')

# Create agent
response = bedrock_client.create_agent(
    agentName='my-agent',
    agentResourceRoleArn='arn:aws:iam::ACCOUNT:role/agent-role',
    description='My intelligent agent',
    foundationModel='anthropic.claude-3-sonnet-20240229-v1:0',
    instruction='You are a helpful assistant. Use provided tools to help users...',
    tags={
        'Environment': 'dev',
        'Project': 'servicenow-ai'
    }
)

agent_id = response['agent']['agentId']

# Create agent alias
alias_response = bedrock_client.create_agent_alias(
    agentId=agent_id,
    agentAliasName='PROD',
    description='Production alias'
)

# Prepare agent (required before invocation)
prepare_response = bedrock_client.prepare_agent(
    agentId=agent_id
)
```

## Action Groups Reference

Action groups are Lambda functions that agents can invoke.

### Web Search Action Group

```python
# Lambda function: web-search-handler
import json
import boto3
from typing import Any, Dict

search_client = boto3.client('kendra')

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Web search action group handler
    """
    body = json.loads(event.get('body', '{}'))
    query = body.get('query')
    max_results = body.get('max_results', 10)

    try:
        # Search using Kendra
        response = search_client.query(
            IndexId='knowledge-base-index-id',
            QueryText=query,
            PageSize=max_results,
            PageNumber=1
        )

        results = []
        for result in response.get('ResultItems', []):
            results.append({
                'title': result.get('DocumentTitle', ''),
                'content': result.get('Content', ''),
                'confidence': result.get('ScoreAttributes', {}).get('ScoreConfidence', 'MEDIUM')
            })

        return {
            'statusCode': 200,
            'body': json.dumps({
                'query': query,
                'results': results,
                'count': len(results)
            })
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
```

### Database Query Action Group

```python
# Lambda function: database-query-handler
import json
import boto3
from typing import Any, Dict
import psycopg2

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Database query action group handler
    """
    body = json.loads(event.get('body', '{}'))
    query_type = body.get('query_type')
    params = body.get('params', {})

    try:
        # Get database credentials from Secrets Manager
        secrets = boto3.client('secretsmanager')
        secret = json.loads(
            secrets.get_secret_value(SecretId='db-credentials')['SecretString']
        )

        # Connect to database
        conn = psycopg2.connect(
            host=secret['host'],
            port=secret['port'],
            database=secret['database'],
            user=secret['username'],
            password=secret['password']
        )

        cursor = conn.cursor()

        # Execute query based on type
        if query_type == 'get_incidents':
            query = "SELECT * FROM incidents WHERE status = %s LIMIT 10"
            cursor.execute(query, (params.get('status', 'open'),))

        elif query_type == 'create_incident':
            query = "INSERT INTO incidents (title, description) VALUES (%s, %s) RETURNING id"
            cursor.execute(query, (params.get('title'), params.get('description')))
            conn.commit()

        else:
            raise ValueError(f"Unknown query type: {query_type}")

        # Fetch results
        results = cursor.fetchall()
        cursor.close()
        conn.close()

        return {
            'statusCode': 200,
            'body': json.dumps({'results': results})
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
```

### REST API Action Group

```python
# Lambda function: api-call-handler
import json
import boto3
import requests
from typing import Any, Dict

secrets = boto3.client('secretsmanager')

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    REST API call action group handler
    """
    body = json.loads(event.get('body', '{}'))
    api_endpoint = body.get('endpoint')
    method = body.get('method', 'GET').upper()
    payload = body.get('payload', {})

    try:
        # Get API key from Secrets Manager
        secret = json.loads(
            secrets.get_secret_value(SecretId='api-credentials')['SecretString']
        )
        api_key = secret.get('api_key')

        # Prepare headers
        headers = {
            'Authorization': f'Bearer {api_key}',
            'Content-Type': 'application/json'
        }

        # Make request
        if method == 'GET':
            response = requests.get(api_endpoint, headers=headers, params=payload)
        elif method == 'POST':
            response = requests.post(api_endpoint, headers=headers, json=payload)
        elif method == 'PUT':
            response = requests.put(api_endpoint, headers=headers, json=payload)
        elif method == 'DELETE':
            response = requests.delete(api_endpoint, headers=headers)
        else:
            raise ValueError(f"Unsupported method: {method}")

        return {
            'statusCode': response.status_code,
            'body': json.dumps({
                'data': response.json() if response.text else {},
                'status': response.status_code
            })
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
```

## Knowledge Base Setup

### Create Knowledge Base

```hcl
# Terraform
resource "aws_bedrock_knowledge_base" "main" {
  name         = "servicenow-knowledge-base"
  description  = "Company knowledge base for agent RAG"
  role_arn     = aws_iam_role.knowledge_base_role.arn

  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.titan-embed-text-v2:0"
    }
  }

  storage_configuration {
    type = "OPENSEARCH"
    opensearch_serverless_configuration {
      collection_arn = aws_opensearchserverless_collection.embeddings.arn
      vector_index_name = "bedrock-knowledge-base-index"
      field_mapping {
        metadata_field = "METADATA"
        text_field     = "CONTENT"
        vector_field   = "EMBEDDING"
      }
    }
  }

  tags = {
    Environment = var.environment
  }
}
```

### Upload Documents

```python
import boto3
import os
from pathlib import Path

bedrock_agent = boto3.client('bedrock-agent')
s3_client = boto3.client('s3')

# Upload to S3
bucket_name = 'servicenow-knowledge-base'
documents_path = './documents'

for document in Path(documents_path).glob('*'):
    if document.is_file():
        s3_client.upload_file(
            str(document),
            bucket_name,
            document.name
        )

# Create data source
data_source = bedrock_agent.create_data_source(
    knowledgeBaseId='kb-xxx',
    dataSourceConfiguration={
        'type': 'S3',
        's3Configuration': {
            'bucketArn': f'arn:aws:s3:::{bucket_name}',
            'inclusionPrefixes': ['documents/']
        }
    },
    name='servicenow-documents',
    description='ServiceNow documentation'
)

# Ingest data
bedrock_agent.start_ingestion_job(
    knowledgeBaseId='kb-xxx',
    dataSourceId=data_source['dataSource']['dataSourceId']
)
```

### Query Knowledge Base

```python
bedrock_runtime = boto3.client('bedrock-agent-runtime')

response = bedrock_runtime.retrieve(
    knowledgeBaseId='kb-xxx',
    retrievalConfiguration={
        'vectorSearchConfiguration': {
            'numberOfResults': 5
        }
    },
    retrievalQuery={
        'text': 'How do I create a ServiceNow incident?'
    }
)

for retrieval_result in response['retrievalResults']:
    print(f"Content: {retrieval_result['content']['text']}")
    print(f"Source: {retrieval_result['location']['s3Location']['uri']}")
    print(f"Score: {retrieval_result['score']}\n")
```

## Security Best Practices

1. **IAM Roles**: Use least privilege principle
2. **Encryption**: Enable KMS encryption for data
3. **VPC**: Deploy in private subnets
4. **Secrets Management**: Use AWS Secrets Manager
5. **Monitoring**: Enable CloudWatch and X-Ray
6. **Input Validation**: Sanitize all user inputs
7. **Rate Limiting**: Implement request throttling
8. **Audit Logging**: Track all agent activities

## Performance Optimization

1. **Model Selection**: Use appropriate model for task
   - Simple tasks: Haiku (faster, cheaper)
   - Complex tasks: Sonnet or Opus
2. **Caching**: Cache frequently used data
3. **Parallelization**: Run independent actions concurrently
4. **Batch Operations**: Process multiple items together
5. **Connection Pooling**: Reuse database connections
6. **Memory Configuration**: Set appropriate timeouts

## Example Agent Implementation

See [examples/](examples/) for complete implementations.

---

**Version**: 1.0.0
**Last Updated**: 2025-01-17
