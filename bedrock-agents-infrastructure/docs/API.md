# Bedrock Agents Infrastructure - API Reference

Complete API reference for Bedrock Agents, Lambda Action Groups, and
orchestration endpoints.

## Bedrock Agents API

### Invoke Agent

**Synchronous Invocation**

```http
POST /invoke-agent HTTP/1.1
Host: bedrock-agent-runtime.us-east-1.amazonaws.com
Content-Type: application/x-amz-json-1.1

{
  "agentId": "AGENT_ID",
  "agentAliasId": "ALIAS_ID",
  "sessionId": "unique-session-id",
  "inputText": "What are the latest incidents?"
}
```

**Response Schema**

```json
{
  "sessionId": "unique-session-id",
  "agentVersion": "1",
  "agentId": "AGENT_ID",
  "output": "There are 5 critical incidents requiring attention..."
}
```

**Python SDK Example**

```python
import boto3

client = boto3.client('bedrock-agent-runtime')

response = client.invoke_agent(
    agentId='AGENT_ID',
    agentAliasId='PROD',
    sessionId='session-123',
    inputText='Create a new incident for the database outage'
)

print(response['output'])
```

**Error Codes**

| Code  | Description                        |
| ----- | ---------------------------------- |
| `400` | Invalid input or malformed request |
| `401` | Authentication failed              |
| `403` | Insufficient permissions           |
| `404` | Agent not found                    |
| `429` | Rate limit exceeded                |
| `500` | Internal server error              |
| `503` | Service unavailable                |

### Retrieve from Knowledge Base

```http
POST /retrieve HTTP/1.1
Host: bedrock-agent-runtime.us-east-1.amazonaws.com
Content-Type: application/x-amz-json-1.1

{
  "knowledgeBaseId": "KB_ID",
  "retrievalQuery": {
    "text": "How do I reset my password?"
  },
  "retrievalConfiguration": {
    "vectorSearchConfiguration": {
      "numberOfResults": 5
    }
  }
}
```

**Response Schema**

```json
{
  "retrievalResults": [
    {
      "content": {
        "text": "To reset your password, follow these steps..."
      },
      "location": {
        "s3Location": {
          "uri": "s3://bucket/document.pdf"
        }
      },
      "score": 0.95
    }
  ]
}
```

## Lambda Action Group APIs

### REST API Pattern

**Invocation**

Bedrock agents invoke action groups as follows:

```python
# Inside Bedrock agent orchestration
response = lambda_client.invoke(
    FunctionName='arn:aws:lambda:region:account:function:action-group-handler',
    InvocationType='RequestResponse',
    Payload=json.dumps({
        'action': 'GetIncidents',
        'parameters': {
            'status': 'open',
            'limit': 10
        }
    })
)
```

### Standard Response Format

All Lambda action groups must return:

```json
{
  "statusCode": 200,
  "body": {
    "success": true,
    "data": {},
    "message": "Action completed successfully"
  }
}
```

### Create Incident Action Group

**Endpoint**: `POST /action-groups/create-incident`

**Request**

```json
{
  "title": "Database connection timeout",
  "description": "Database connection timing out on production",
  "severity": "high",
  "assignment_group": "Database Team",
  "additional_info": {}
}
```

**Response**

```json
{
  "statusCode": 201,
  "body": {
    "success": true,
    "incident_id": "INC0012345",
    "incident_number": "INC-2025-001234",
    "timestamp": "2025-01-17T10:30:00Z"
  }
}
```

**Lambda Implementation**

```python
import json
import boto3
from datetime import datetime

servicenow = boto3.client('servicenow')  # Custom boto3 client

def lambda_handler(event, context):
    """Create incident in ServiceNow"""

    body = json.loads(event.get('body', '{}'))

    try:
        # Validate required fields
        required = ['title', 'description', 'severity']
        if not all(k in body for k in required):
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'success': False,
                    'error': 'Missing required fields'
                })
            }

        # Create incident
        incident = servicenow.create_incident(
            short_description=body['title'],
            description=body['description'],
            severity=map_severity(body['severity']),
            assignment_group=body.get('assignment_group', 'Incident Management'),
            cmdb_ci=body.get('cmdb_ci'),
            additional_comments=json.dumps(body.get('additional_info', {}))
        )

        return {
            'statusCode': 201,
            'body': json.dumps({
                'success': True,
                'incident_id': incident['id'],
                'incident_number': incident['number'],
                'timestamp': datetime.utcnow().isoformat() + 'Z'
            })
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({
                'success': False,
                'error': str(e)
            })
        }

def map_severity(sev_str):
    """Map text severity to numeric"""
    mapping = {'critical': '1', 'high': '2', 'medium': '3', 'low': '4'}
    return mapping.get(sev_str.lower(), '3')
```

### Query Incidents Action Group

**Endpoint**: `GET /action-groups/query-incidents`

**Request Parameters**

```json
{
  "status": "open",
  "assignment_group": "Database Team",
  "severity": "high",
  "limit": 20,
  "offset": 0
}
```

**Response**

```json
{
  "statusCode": 200,
  "body": {
    "success": true,
    "data": [
      {
        "id": "INC0012345",
        "number": "INC-2025-001234",
        "title": "Database timeout",
        "severity": "high",
        "status": "open",
        "created_at": "2025-01-17T10:00:00Z",
        "updated_at": "2025-01-17T10:30:00Z",
        "assignment_group": "Database Team"
      }
    ],
    "total_count": 45,
    "offset": 0,
    "limit": 20
  }
}
```

### Update Incident Action Group

**Endpoint**: `PUT /action-groups/update-incident`

**Request**

```json
{
  "incident_id": "INC0012345",
  "status": "in_progress",
  "notes": "Work started on the issue",
  "time_spent": 30
}
```

**Response**

```json
{
  "statusCode": 200,
  "body": {
    "success": true,
    "incident_id": "INC0012345",
    "updated_at": "2025-01-17T10:35:00Z"
  }
}
```

### Send Email Action Group

**Endpoint**: `POST /action-groups/send-email`

**Request**

```json
{
  "to": ["user@company.com"],
  "cc": ["manager@company.com"],
  "subject": "Incident INC-2025-001234 Update",
  "body": "The incident has been assigned to the Database Team.",
  "template": "incident-update"
}
```

**Response**

```json
{
  "statusCode": 200,
  "body": {
    "success": true,
    "message_id": "msg-abc123",
    "recipients": 2,
    "timestamp": "2025-01-17T10:36:00Z"
  }
}
```

## Request/Response Schemas

### Common Error Response

```json
{
  "statusCode": 400,
  "body": {
    "success": false,
    "error": "Error description",
    "error_code": "INVALID_INPUT",
    "details": {
      "field": "status",
      "reason": "Invalid status value. Valid values: open, in_progress, resolved, closed"
    },
    "request_id": "req-12345"
  }
}
```

### Pagination Schema

```json
{
  "statusCode": 200,
  "body": {
    "success": true,
    "data": [],
    "pagination": {
      "total": 150,
      "page": 1,
      "per_page": 20,
      "total_pages": 8,
      "has_next": true,
      "has_prev": false
    }
  }
}
```

### Async Operation Response

```json
{
  "statusCode": 202,
  "body": {
    "success": true,
    "operation_id": "op-abc123",
    "status": "pending",
    "status_url": "https://api.example.com/operations/op-abc123"
  }
}
```

## Rate Limiting

### Headers

```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1705502400
```

### Implementation

```python
from functools import wraps
import time

def rate_limit(max_calls, time_window):
    """Rate limiter decorator"""
    def decorator(func):
        calls = []

        @wraps(func)
        def wrapper(*args, **kwargs):
            now = time.time()

            # Remove old calls outside time window
            calls[:] = [call for call in calls if call > now - time_window]

            if len(calls) >= max_calls:
                raise Exception(f"Rate limit exceeded: {max_calls} calls per {time_window}s")

            calls.append(now)
            return func(*args, **kwargs)

        return wrapper
    return decorator

@rate_limit(max_calls=1000, time_window=60)
def api_endpoint():
    return {"status": "ok"}
```

## Authentication

### IAM-based Authentication

```python
import boto3
from botocore.exceptions import ClientError

def authenticate_request(event):
    """Verify AWS signature"""
    try:
        # Extract signature from event headers
        signature = event['headers'].get('Authorization')

        # Verify using AWS Signature Version 4
        # Implementation details...

        return True
    except ClientError:
        return False
```

### API Key Authentication

```python
import os
import hmac
import hashlib

def verify_api_key(api_key):
    """Verify API key"""
    stored_key = os.environ.get('API_KEY_HASH')
    computed_hash = hashlib.sha256(api_key.encode()).hexdigest()

    return hmac.compare_digest(computed_hash, stored_key)
```

## Examples

### Create and Update Incident

```python
import boto3
import json

client = boto3.client('bedrock-agent-runtime')

# Step 1: Ask agent to create incident
create_response = client.invoke_agent(
    agentId='incident-management-agent',
    agentAliasId='PROD',
    sessionId='incident-workflow-001',
    inputText='Create an incident for a critical database outage with title "Database Cluster Failure" and description "Primary database cluster unresponsive"'
)

print("Create response:", create_response['output'])

# Step 2: Ask agent to update incident
update_response = client.invoke_agent(
    agentId='incident-management-agent',
    agentAliasId='PROD',
    sessionId='incident-workflow-001',
    inputText='Update the incident status to in_progress and add a note that the database team has acknowledged the issue'
)

print("Update response:", update_response['output'])

# Step 3: Ask agent to query incidents
query_response = client.invoke_agent(
    agentId='incident-management-agent',
    agentAliasId='PROD',
    sessionId='incident-workflow-001',
    inputText='Show me all open critical incidents for the database team'
)

print("Query response:", query_response['output'])
```

### Knowledge Base Query

```python
client = boto3.client('bedrock-agent-runtime')

# Retrieve relevant documents
response = client.retrieve(
    knowledgeBaseId='kb-servicenow-docs',
    retrievalQuery={
        'text': 'How do I configure CMDB for AWS resources?'
    },
    retrievalConfiguration={
        'vectorSearchConfiguration': {
            'numberOfResults': 5
        }
    }
)

# Process results
for result in response['retrievalResults']:
    print(f"Document: {result['location']['s3Location']['uri']}")
    print(f"Content: {result['content']['text'][:200]}...")
    print(f"Confidence: {result['score']}\n")
```

### Parallel Action Group Calls

```python
import concurrent.futures

# Invoke multiple action groups in parallel
action_group_arns = [
    'arn:aws:lambda:us-east-1:123456789:function:get-incidents',
    'arn:aws:lambda:us-east-1:123456789:function:get-changes',
    'arn:aws:lambda:us-east-1:123456789:function:get-problems'
]

lambda_client = boto3.client('lambda')

def invoke_action_group(arn):
    response = lambda_client.invoke(
        FunctionName=arn,
        InvocationType='RequestResponse',
        Payload=json.dumps({'action': 'list'})
    )
    return json.loads(response['Payload'].read())

with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
    results = list(executor.map(invoke_action_group, action_group_arns))

print("Results:", results)
```

---

**Version**: 1.0.0 **Last Updated**: 2025-01-17
