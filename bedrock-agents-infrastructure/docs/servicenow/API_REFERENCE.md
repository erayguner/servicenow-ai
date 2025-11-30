# ServiceNow Bedrock Integration - API Reference

## Table of Contents

1. [ServiceNow REST API Endpoints](#servicenow-rest-api-endpoints)
2. [Lambda Action Reference](#lambda-action-reference)
3. [Request/Response Schemas](#requestresponse-schemas)
4. [Authentication Methods](#authentication-methods)
5. [Rate Limiting](#rate-limiting)
6. [Error Codes and Handling](#error-codes-and-handling)

## ServiceNow REST API Endpoints

### Base URL Configuration

```
Base URL: https://{instance}.service-now.com/api/now/

Authentication:
  - OAuth 2.0 (recommended)
  - Basic Authentication
  - Service Account with API Token

Headers:
  Content-Type: application/json
  Accept: application/json
  Authorization: Bearer {access_token} OR Basic {base64_credentials}
```

### Incident Management Endpoints

#### Create Incident

```
POST /table/incident

Request:
{
  "short_description": "Unable to connect to database",
  "description": "Users experiencing connection timeouts to production database",
  "caller_id": "sys_id_of_caller",
  "category": "Software",
  "subcategory": "Database",
  "contact_type": "Email",
  "impact": "1",
  "urgency": "1",
  "assignment_group": "Database Support"
}

Response (Success - 201):
{
  "result": {
    "sys_id": "a59c6c43dbXXXXXXXXXXXX",
    "number": "INC0010234",
    "short_description": "Unable to connect to database",
    "state": "1",
    "created_on": "2024-11-17T10:30:00Z",
    "created_by": "servicenow_bedrock_api"
  }
}

Response (Error - 400):
{
  "error": {
    "message": "Invalid field value",
    "detail": "Field 'impact' must be 1, 2, or 3"
  },
  "status": "failure"
}
```

#### Update Incident

```
PATCH /table/incident/{sys_id}

Request:
{
  "state": "2",
  "assignment_group": "Email Support Team",
  "work_notes": "Analyzed incident, root cause identified. Assigned to email team.",
  "short_description": "[RESOLVED] Unable to access email - OAuth config updated",
  "comments": "User's OAuth configuration updated per KB0056789"
}

Response (Success - 200):
{
  "result": {
    "sys_id": "a59c6c43dbXXXXXXXXXXXX",
    "number": "INC0010234",
    "state": "2",
    "assignment_group": "Email Support Team",
    "updated_on": "2024-11-17T11:45:00Z"
  }
}

Response (Error - 404):
{
  "error": {
    "message": "Record not found",
    "detail": "No incident found with sys_id: invalid-id"
  },
  "status": "failure"
}
```

#### Get Incident

```
GET /table/incident/{sys_id}

Query Parameters:
  - sysparm_fields=number,short_description,state,assigned_to,assignment_group
  - sysparm_exclude_reference_link=true
  - sysparm_display_value=true

Response (Success - 200):
{
  "result": {
    "sys_id": "a59c6c43dbXXXXXXXXXXXX",
    "number": "INC0010234",
    "short_description": "Unable to connect to database",
    "description": "Users experiencing connection timeouts...",
    "state": "1",
    "state_display": "New",
    "impact": "1",
    "urgency": "1",
    "priority": "1",
    "category": "Software",
    "subcategory": "Database",
    "assignment_group": "Database Support",
    "assigned_to": "john.smith",
    "created_on": "2024-11-17T10:30:00Z",
    "updated_on": "2024-11-17T11:45:00Z",
    "created_by": "servicenow_bedrock_api"
  }
}
```

#### Search Incidents

```
GET /table/incident

Query Parameters:
  - sysparm_query=ORDERBYDESCcreated_on
  - sysparm_limit=50
  - sysparm_offset=0
  - sysparm_fields=number,short_description,state,priority,assigned_to

Advanced Query Examples:
  - ?sysparm_query=state=1^ORDERBYDESCpriority
    Returns: New incidents ordered by priority (highest first)

  - ?sysparm_query=assigned_to=NULL^state!=6
    Returns: Unassigned incidents excluding closed incidents

  - ?sysparm_query=created_on>=javascript:gs.dateAdd(new GlideDateTime(),'days',-7)
    Returns: Incidents created in last 7 days

  - ?sysparm_query=category=Software^priority=1
    Returns: High-priority software incidents

Response (Success - 200):
{
  "result": [
    {
      "sys_id": "a59c6c43db...",
      "number": "INC0010234",
      "short_description": "Unable to connect to database",
      "state": "1",
      "priority": "1",
      "assigned_to": ""
    },
    {
      "sys_id": "b62d7d54eb...",
      "number": "INC0010235",
      "short_description": "Email sync not working",
      "state": "2",
      "priority": "2",
      "assigned_to": "jane.doe"
    }
  ]
}

Response Headers:
  X-Total-Count: 1245
  Link: <...?offset=50>; rel="next"
```

### Change Request Endpoints

#### Create Change Request

```
POST /table/change_request

Request:
{
  "short_description": "Upgrade database to v12.4",
  "description": "Upgrade production database to version 12.4 with performance improvements",
  "type": "normal",
  "assignment_group": "Database Team",
  "planned_start_date": "2024-11-25T02:00:00Z",
  "planned_end_date": "2024-11-25T04:00:00Z",
  "implementation_plan": "1. Backup production\n2. Upgrade database...",
  "backout_plan": "1. Stop upgrade process\n2. Restore from backup..."
}

Response (Success - 201):
{
  "result": {
    "sys_id": "c73e8e65fc...",
    "number": "CHG0098765",
    "short_description": "Upgrade database to v12.4",
    "type": "normal",
    "state": "1",
    "created_on": "2024-11-17T10:30:00Z"
  }
}
```

#### Update Change Request

```
PATCH /table/change_request/{sys_id}

Request:
{
  "state": "3",
  "implementation_comments": "Database upgrade completed successfully",
  "actual_start_date": "2024-11-25T02:05:00Z",
  "actual_end_date": "2024-11-25T03:45:00Z",
  "work_notes": "All tests passed, users report no issues"
}

Response (Success - 200):
{
  "result": {
    "sys_id": "c73e8e65fc...",
    "number": "CHG0098765",
    "state": "3",
    "state_display": "Successful",
    "updated_on": "2024-11-25T04:00:00Z"
  }
}
```

#### Get Change Request

```
GET /table/change_request/{sys_id}

Query Parameters:
  - sysparm_fields=number,short_description,state,type,assignment_group

Response (Success - 200):
{
  "result": {
    "sys_id": "c73e8e65fc...",
    "number": "CHG0098765",
    "short_description": "Upgrade database to v12.4",
    "type": "normal",
    "state": "1",
    "state_display": "Draft",
    "assignment_group": "Database Team",
    "planned_start_date": "2024-11-25T02:00:00Z",
    "planned_end_date": "2024-11-25T04:00:00Z",
    "implementation_plan": "...",
    "backout_plan": "..."
  }
}
```

#### Get Change Tasks

```
GET /table/change_request/{sys_id}/change_tasks

Response (Success - 200):
{
  "result": [
    {
      "sys_id": "d84f9f76gd...",
      "number": "CHT0001",
      "title": "Pre-implementation backup",
      "description": "Backup production database",
      "assigned_to": "backup-team",
      "state": "1"
    },
    {
      "sys_id": "e95g0g87he...",
      "number": "CHT0002",
      "title": "Execute upgrade",
      "description": "Run database upgrade script",
      "assigned_to": "dba-team",
      "state": "1"
    }
  ]
}
```

### Knowledge Base Endpoints

#### Create KB Article

```
POST /table/kb_knowledge

Request:
{
  "short_description": "Resolve database connection timeout errors",
  "text": "## Symptoms\nUsers experience database connection timeouts...\n## Root Cause\nDatabase pool exhaustion...\n## Solution\n1. Increase connection pool size...",
  "category": "Database",
  "kb_category": "How to",
  "kb_knowledge_base": "IT Service Management",
  "workflow_state": "draft",
  "meta": "database, connection, timeout",
  "author": "servicenow_bedrock_api"
}

Response (Success - 201):
{
  "result": {
    "sys_id": "f06h1h98if...",
    "number": "KB0090234",
    "short_description": "Resolve database connection timeout errors",
    "workflow_state": "draft",
    "created_on": "2024-11-17T10:30:00Z"
  }
}
```

#### Update KB Article

```
PATCH /table/kb_knowledge/{sys_id}

Request:
{
  "text": "## Symptoms\nUpdated symptoms list...",
  "workflow_state": "published",
  "valid_from": "2024-11-17T00:00:00Z"
}

Response (Success - 200):
{
  "result": {
    "sys_id": "f06h1h98if...",
    "number": "KB0090234",
    "workflow_state": "published",
    "updated_on": "2024-11-17T11:45:00Z"
  }
}
```

#### Search KB Articles

```
GET /table/kb_knowledge

Query Parameters:
  - sysparm_query=CONTAINS(text,'database connection timeout')
  - sysparm_limit=20
  - sysparm_fields=number,short_description,text,category

Response (Success - 200):
{
  "result": [
    {
      "sys_id": "f06h1h98if...",
      "number": "KB0090234",
      "short_description": "Resolve database connection timeout errors",
      "category": "Database",
      "workflow_state": "published",
      "views": 245,
      "rating": 4.5
    }
  ]
}
```

### User and Group Lookup

#### Get User Information

```
GET /table/sys_user/{sys_id}

Query Parameters:
  - sysparm_fields=name,email,phone,department

Response (Success - 200):
{
  "result": {
    "sys_id": "g17i2i09jg...",
    "name": "John Smith",
    "user_name": "john.smith",
    "email": "john.smith@company.com",
    "phone": "+1-555-0123",
    "department": "Finance"
  }
}
```

#### Search Users

```
GET /table/sys_user

Query Parameters:
  - sysparm_query=nameLIKEJohn^active=true
  - sysparm_fields=name,user_name,email,phone

Response (Success - 200):
{
  "result": [
    {
      "sys_id": "g17i2i09jg...",
      "name": "John Smith",
      "user_name": "john.smith",
      "email": "john.smith@company.com"
    }
  ]
}
```

#### Get Group Information

```
GET /table/sys_user_group/{sys_id}

Response (Success - 200):
{
  "result": {
    "sys_id": "h28j3j10kh...",
    "name": "Database Support Team",
    "description": "Team responsible for database support and administration",
    "manager": "database-manager-id",
    "active": "true"
  }
}
```

## Lambda Action Reference

### Incident Resolution Actions

#### IncidentAnalysisAction

```
Action: incident_analysis
Input: {
  incident_id: string (sys_id),
  include_history: boolean (default: true),
  search_kb: boolean (default: true)
}

Output: {
  incident_id: string,
  symptoms: string[],
  probable_causes: {
    cause: string,
    confidence: number (0-100)
  }[],
  recommended_category: string,
  recommended_subcategory: string,
  severity_score: number (1-10),
  kb_articles: {
    number: string,
    title: string,
    relevance_score: number (0-100)
  }[],
  similar_incidents: {
    number: string,
    resolution: string
  }[]
}

Example:
{
  incident_id: "a59c6c43db...",
  symptoms: ["Database timeout", "Connection refused", "Slow queries"],
  probable_causes: [
    { cause: "Database pool exhaustion", confidence: 85 },
    { cause: "Network connectivity issue", confidence: 45 }
  ],
  recommended_category: "Software",
  recommended_subcategory: "Database",
  severity_score: 8,
  kb_articles: [
    { number: "KB0012345", title: "DB Pool Management", relevance_score: 95 }
  ]
}
```

#### AssignIncidentAction

```
Action: assign_incident
Input: {
  incident_id: string (sys_id),
  assignment_group: string (group name or sys_id),
  assigned_to: string (optional, user id or name),
  work_notes: string (optional)
}

Output: {
  incident_id: string,
  assignment_group: string,
  assigned_to: string,
  assignment_timestamp: ISO8601,
  status: "success" | "failed"
}

Example:
{
  incident_id: "a59c6c43db...",
  assignment_group: "Database Support Team",
  assigned_to: "john.smith",
  assignment_timestamp: "2024-11-17T10:35:00Z",
  status: "success"
}
```

### Change Management Actions

#### ChangeRiskAssessmentAction

```
Action: assess_change_risk
Input: {
  change_id: string (sys_id),
  detailed: boolean (default: false)
}

Output: {
  change_id: string,
  technical_risk: number (1-10),
  business_risk: number (1-10),
  operational_risk: number (1-10),
  overall_risk_score: number (1-100),
  risk_level: "LOW" | "MEDIUM" | "HIGH" | "CRITICAL",
  cab_required: boolean,
  testing_required: boolean,
  rollback_required: boolean,
  confidence: number (0-100),
  risk_factors: string[],
  mitigation_strategies: string[]
}

Example:
{
  change_id: "c73e8e65fc...",
  technical_risk: 6,
  business_risk: 8,
  operational_risk: 5,
  overall_risk_score: 68,
  risk_level: "HIGH",
  cab_required: true,
  testing_required: true,
  rollback_required: true,
  confidence: 87
}
```

#### ScheduleChangeAction

```
Action: schedule_change
Input: {
  change_id: string (sys_id),
  start_date: ISO8601,
  end_date: ISO8601,
  check_conflicts: boolean (default: true)
}

Output: {
  change_id: string,
  scheduled: boolean,
  scheduled_start: ISO8601,
  scheduled_end: ISO8601,
  conflicts: {
    change_id: string,
    change_number: string,
    conflict_type: string
  }[],
  status: "scheduled" | "conflict_detected" | "failed"
}
```

### Knowledge Base Actions

#### CreateKBArticleAction

```
Action: create_kb_article
Input: {
  title: string,
  content: string,
  category: string,
  kb_category: string,
  keywords: string[],
  related_incidents: string[] (optional),
  incident_source: string (optional, source incident sys_id)
}

Output: {
  article_id: string,
  article_number: string,
  title: string,
  status: "draft" | "published",
  created_timestamp: ISO8601,
  url: string,
  status_code: "success" | "validation_error" | "failed"
}

Example:
{
  article_id: "f06h1h98if...",
  article_number: "KB0090234",
  title: "Resolve database connection timeout errors",
  status: "draft",
  created_timestamp: "2024-11-17T10:30:00Z",
  url: "https://instance.service-now.com/kb_view.do?sys_id=f06h1h98if...",
  status_code: "success"
}
```

## Request/Response Schemas

### Common Request Headers

```
Content-Type: application/json
Accept: application/json
Authorization: Bearer {access_token}
User-Agent: Bedrock-ServiceNow-Agent/1.0
X-Requested-With: XMLHttpRequest
```

### Common Response Headers

```
Content-Type: application/json; charset=utf-8
Cache-Control: no-cache, no-store, must-revalidate
X-Total-Count: {total_matching_records}
X-Page-Number: {current_page}
X-Page-Size: {records_per_page}
Link: <url>; rel="next"
RateLimit-Limit: 1000
RateLimit-Remaining: 987
RateLimit-Reset: 1637081400
```

### Error Response Schema

```json
{
  "error": {
    "message": "Short error message",
    "detail": "Detailed explanation of the error",
    "code": "ERROR_CODE",
    "target": "field_name_if_applicable"
  },
  "status": "failure",
  "statusCode": 400
}
```

### Pagination Response Schema

```json
{
  "result": [
    {
      /* record 1 */
    },
    {
      /* record 2 */
    }
  ],
  "meta": {
    "total_count": 1245,
    "limit": 50,
    "offset": 0,
    "page": 1,
    "pages": 25
  },
  "links": {
    "first": "/api/now/table/incident?offset=0&limit=50",
    "last": "/api/now/table/incident?offset=1200&limit=50",
    "next": "/api/now/table/incident?offset=50&limit=50",
    "previous": null
  }
}
```

## Authentication Methods

### OAuth 2.0 Authentication

```
1. Get Access Token:
   POST https://instance.service-now.com/oauth_token.do

   Headers:
     Content-Type: application/x-www-form-urlencoded

   Body:
     grant_type=client_credentials
     client_id={CLIENT_ID}
     client_secret={CLIENT_SECRET}

   Response:
   {
     "access_token": "eyJ0eXAiOiJKV1QiLCJhbGc...",
     "token_type": "Bearer",
     "expires_in": 3600,
     "scope": "api"
   }

2. Use Access Token:
   GET /api/now/table/incident
   Authorization: Bearer {access_token}

3. Refresh Token (if near expiration):
   POST https://instance.service-now.com/oauth_token.do

   Body:
     grant_type=refresh_token
     client_id={CLIENT_ID}
     client_secret={CLIENT_SECRET}
     refresh_token={REFRESH_TOKEN}
```

### Basic Authentication

```
GET /api/now/table/incident
Authorization: Basic {base64(username:password)}

Example:
Authorization: Basic dXNlcm5hbWU6cGFzc3dvcmQ=
```

### API Token Authentication

```
Authorization: Bearer {api_token}

Or (Legacy):
Username: servicenow_user
Password: api_token_value
```

## Rate Limiting

### Rate Limit Headers

```
RateLimit-Limit: 1000           # Max requests per window
RateLimit-Remaining: 987        # Remaining requests
RateLimit-Reset: 1637081400     # Unix timestamp when limit resets
```

### Rate Limit Policies

```
Standard API Rate Limits:
- Authenticated: 1000 requests per minute
- Concurrent Requests: 50 concurrent requests per user
- Query Limit: 10,000 records maximum per request
- Timeout: 30 seconds per request

Recommended Strategies:
1. Implement exponential backoff for retries
2. Cache responses when possible
3. Use batch operations for multiple records
4. Monitor RateLimit-Remaining header
5. Implement circuit breaker pattern
```

### Handling Rate Limit Exceeded

```
Response (429 Too Many Requests):
{
  "error": {
    "message": "Rate limit exceeded",
    "detail": "API rate limit of 1000 requests per minute exceeded",
    "retry_after": 60
  },
  "status": "failure",
  "statusCode": 429
}

HTTP Headers:
  Retry-After: 60
  X-RateLimit-Reset: 1637081400

Lambda Handler Response:
{
  "statusCode": 429,
  "body": {
    "message": "Rate limit exceeded",
    "retryAfter": 60
  },
  "retryable": true,
  "backoffMs": 30000
}
```

## Error Codes and Handling

### HTTP Status Codes

```
200 OK
  - Request succeeded
  - Response contains result data

201 Created
  - Resource successfully created
  - Response contains created resource data

204 No Content
  - Request succeeded
  - No response body

400 Bad Request
  - Invalid request format
  - Missing required field
  - Invalid field value
  Action: Fix request and retry (not retryable after fixes)

401 Unauthorized
  - Missing or invalid credentials
  - Token expired
  Action: Refresh token or update credentials

403 Forbidden
  - Authenticated but lacks permission
  - User doesn't have required role
  Action: Check user permissions (not retryable)

404 Not Found
  - Record doesn't exist
  - Endpoint not found
  Action: Verify sys_id or endpoint (not retryable)

429 Too Many Requests
  - Rate limit exceeded
  Action: Implement exponential backoff and retry

500 Internal Server Error
  - ServiceNow server error
  Action: Retry with exponential backoff

502 Bad Gateway
  - Temporary connectivity issue
  Action: Retry with exponential backoff

503 Service Unavailable
  - ServiceNow temporarily down
  Action: Retry with exponential backoff
```

### ServiceNow-Specific Error Codes

```
INVALID_TABLE
  Message: "Invalid table name"
  HTTP Status: 404
  Action: Check table name spelling and permissions

INVALID_FIELD
  Message: "Invalid field in query"
  HTTP Status: 400
  Action: Verify field names and table structure

INVALID_QUERY_SYNTAX
  Message: "Invalid encoded query syntax"
  HTTP Status: 400
  Action: Fix query syntax and retry

RECORD_NOT_FOUND
  Message: "No records found matching query"
  HTTP Status: 404
  Action: Adjust query parameters

PERMISSION_DENIED
  Message: "You do not have permission to access this table"
  HTTP Status: 403
  Action: Check IAM permissions and user roles

MANDATORY_FIELD_MISSING
  Message: "Mandatory field '{field_name}' is missing"
  HTTP Status: 400
  Action: Include required field in request

INVALID_FIELD_VALUE
  Message: "Invalid value for field '{field_name}'"
  HTTP Status: 400
  Action: Provide valid value for field

DUPLICATE_RECORD
  Message: "A record with this value already exists"
  HTTP Status: 400
  Action: Use unique values or update existing record
```

### Bedrock-Specific Error Codes

```
MODEL_UNAVAILABLE
  Message: "The specified model is not available"
  Action: Retry with different model or wait

INVALID_INPUT
  Message: "Input does not match model requirements"
  Action: Fix input format and retry

TOKEN_LIMIT_EXCEEDED
  Message: "Input exceeds maximum token limit"
  Action: Reduce input size or use streaming

THROTTLING_EXCEPTION
  Message: "Model is currently throttled"
  Action: Implement exponential backoff

SERVICE_UNAVAILABLE
  Message: "Bedrock service temporarily unavailable"
  Action: Retry with exponential backoff
```

## Lambda Response Format

### Successful Response

```json
{
  "statusCode": 200,
  "headers": {
    "Content-Type": "application/json"
  },
  "body": {
    "status": "success",
    "message": "Operation completed successfully",
    "data": {
      "incident_id": "a59c6c43db...",
      "incident_number": "INC0010234",
      "action_taken": "Incident analyzed and assigned",
      "timestamp": "2024-11-17T10:35:00Z"
    },
    "executionTime": 2345
  }
}
```

### Error Response

```json
{
  "statusCode": 400,
  "headers": {
    "Content-Type": "application/json"
  },
  "body": {
    "status": "error",
    "errorCode": "INVALID_INPUT",
    "message": "Invalid incident ID provided",
    "details": {
      "field": "incident_id",
      "error": "Incident ID must be a valid sys_id"
    },
    "timestamp": "2024-11-17T10:35:00Z",
    "requestId": "req-12345-abcde"
  }
}
```

### Async Response (Queued)

```json
{
  "statusCode": 202,
  "headers": {
    "Content-Type": "application/json"
  },
  "body": {
    "status": "queued",
    "message": "Operation queued for processing",
    "executionId": "exec-12345-abcde",
    "estimatedProcessingTime": 30,
    "statusCheckUrl": "/api/execution-status/exec-12345-abcde"
  }
}
```

For more information, refer to the
[ServiceNow REST API Documentation](https://docs.servicenow.com/bundle/vancouver-api-reference/page/integrate/inbound-rest/concept/c_TableAPI.html)
and the [TROUBLESHOOTING.md](TROUBLESHOOTING.md) guide.
