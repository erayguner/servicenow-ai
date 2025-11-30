# ServiceNow API Integration Lambda Function

Comprehensive AWS Lambda function for integrating Amazon Bedrock Agents with
ServiceNow ITSM platform via REST API v2.

## Features

### Supported Actions

#### Incident Management (7 actions)

- `create-incident` - Create new incident
- `update-incident` - Update existing incident
- `resolve-incident` - Resolve incident with notes
- `get-incident` - Retrieve incident details
- `search-incidents` - Search incidents by query
- `assign-incident` - Assign to user/group
- `add-comment` - Add customer comment

#### Ticket Operations (5 actions)

- `create-ticket` - Create generic ticket
- `update-ticket` - Update ticket status
- `close-ticket` - Close ticket with notes
- `get-ticket-status` - Get ticket status
- `add-work-notes` - Add internal work notes

#### Change Management (5 actions)

- `create-change-request` - Create change request
- `update-change-request` - Update change details
- `assess-change-risk` - Perform risk assessment
- `approve-change` - Approve change request
- `schedule-change` - Schedule change window

#### Problem Management (4 actions)

- `create-problem` - Create problem record
- `link-incidents-to-problem` - Link related incidents
- `update-problem` - Update problem details
- `resolve-problem` - Resolve with root cause

#### Knowledge Base (4 actions)

- `search-knowledge` - Search KB articles
- `create-kb-article` - Create new article
- `update-kb-article` - Update existing article
- `get-kb-article` - Get article by ID/number

#### User/Group Operations (3 actions)

- `get-user-info` - Retrieve user details
- `get-group-info` - Retrieve group details
- `assign-to-group` - Assign task to group

#### Reporting (3 actions)

- `get-incident-metrics` - Get incident statistics
- `get-sla-status` - Check SLA compliance
- `generate-report` - Generate custom reports

## Architecture

```
┌─────────────────┐
│ Bedrock Agent   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐      ┌──────────────────┐
│ Lambda Function │─────▶│ Secrets Manager  │
│  (This code)    │      │  (Credentials)   │
└────────┬────────┘      └──────────────────┘
         │
         ▼
┌─────────────────┐      ┌──────────────────┐
│ ServiceNow      │      │ CloudWatch Logs  │
│ REST API v2     │◀─────│  (Monitoring)    │
└─────────────────┘      └──────────────────┘
```

## Setup

### 1. Prerequisites

- Node.js 18.x or later
- AWS CLI configured
- ServiceNow instance and credentials
- AWS account with Lambda and Secrets Manager access

### 2. Install Dependencies

```bash
npm install
```

### 3. Configure Secrets Manager

Create a secret in AWS Secrets Manager with ServiceNow credentials:

**For Basic Authentication:**

```json
{
  "instance": "https://your-instance.service-now.com",
  "username": "your-username",
  "password": "your-password",
  "authType": "basic"
}
```

**For OAuth Authentication:**

```json
{
  "instance": "https://your-instance.service-now.com",
  "clientId": "your-client-id",
  "clientSecret": "your-client-secret",
  "username": "your-username",
  "password": "your-password",
  "authType": "oauth"
}
```

### 4. Build the Function

```bash
npm run build
```

### 5. Run Tests

```bash
npm test
npm run test:coverage
```

### 6. Deploy to AWS Lambda

```bash
# Create deployment package
npm run package

# Upload to Lambda
aws lambda create-function \
  --function-name servicenow-integration \
  --runtime nodejs18.x \
  --handler dist/index.handler \
  --role arn:aws:iam::ACCOUNT_ID:role/lambda-execution-role \
  --zip-file fileb://servicenow-integration.zip \
  --timeout 60 \
  --memory-size 512 \
  --environment Variables="{SERVICENOW_SECRET_NAME=servicenow/credentials,RATE_LIMIT_ENABLED=true,MAX_REQUESTS=100,WINDOW_MS=60000}"
```

## Usage Examples

### Create Incident

```json
{
  "action": "create-incident",
  "parameters": {
    "incident": {
      "short_description": "Server down",
      "description": "Production server is not responding",
      "caller_id": "user123",
      "impact": "1",
      "urgency": "1",
      "category": "hardware",
      "assignment_group": "network-team"
    }
  }
}
```

### Update Incident

```json
{
  "action": "update-incident",
  "parameters": {
    "sys_id": "abc123",
    "incident": {
      "state": "2",
      "work_notes": "Investigating the issue",
      "assigned_to": "tech123"
    }
  }
}
```

### Resolve Incident

```json
{
  "action": "resolve-incident",
  "parameters": {
    "sys_id": "abc123",
    "resolution_notes": "Server restarted, issue resolved",
    "close_code": "Solved (Permanently)"
  }
}
```

### Search Incidents

```json
{
  "action": "search-incidents",
  "parameters": {
    "query": "caller_id=user123^state=1^impact=1"
  }
}
```

### Create Change Request

```json
{
  "action": "create-change-request",
  "parameters": {
    "change": {
      "short_description": "Database migration",
      "description": "Migrate to PostgreSQL 15",
      "type": "normal",
      "risk": "2",
      "impact": "2",
      "requested_by": "user123",
      "start_date": "2025-02-01 02:00:00",
      "end_date": "2025-02-01 06:00:00"
    }
  }
}
```

### Search Knowledge Base

```json
{
  "action": "search-knowledge",
  "parameters": {
    "search_query": "password reset"
  }
}
```

### Get Incident Metrics

```json
{
  "action": "get-incident-metrics",
  "parameters": {
    "start_date": "2025-01-01",
    "end_date": "2025-01-31"
  }
}
```

## Environment Variables

| Variable                 | Description                 | Default                  |
| ------------------------ | --------------------------- | ------------------------ |
| `SERVICENOW_SECRET_NAME` | Secrets Manager secret name | `servicenow/credentials` |
| `RATE_LIMIT_ENABLED`     | Enable rate limiting        | `true`                   |
| `MAX_REQUESTS`           | Max requests per window     | `100`                    |
| `WINDOW_MS`              | Rate limit window (ms)      | `60000`                  |

## Features

### Authentication

- **Basic Auth**: Username/password authentication
- **OAuth 2.0**: Client credentials with automatic token refresh
- Credentials stored securely in AWS Secrets Manager

### Rate Limiting

- Token bucket algorithm
- Configurable limits
- Automatic request throttling

### Retry Logic

- Exponential backoff
- Configurable retry attempts
- Jitter to prevent thundering herd

### Error Handling

- Comprehensive error types
- Detailed error messages
- CloudWatch logging
- Status code mapping

### Monitoring

- CloudWatch Logs integration
- Structured JSON logging
- Operation tracking
- Performance metrics

## API Response Format

**Success Response:**

```json
{
  "success": true,
  "statusCode": 200,
  "message": "Operation completed successfully",
  "data": {
    /* ServiceNow response data */
  }
}
```

**Error Response:**

```json
{
  "success": false,
  "statusCode": 400,
  "error": "Missing required parameters: short_description"
}
```

## ServiceNow API Reference

This integration uses ServiceNow REST API v2:

- **Table API**: `/api/now/table/{table_name}`
- **Documentation**: https://developer.servicenow.com/dev.do

### Key Tables

- `incident` - Incident management
- `change_request` - Change management
- `problem` - Problem management
- `kb_knowledge` - Knowledge base articles
- `sys_user` - User records
- `sys_user_group` - User groups
- `task_sla` - SLA records

## IAM Permissions

The Lambda execution role needs:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["secretsmanager:GetSecretValue"],
      "Resource": "arn:aws:secretsmanager:region:account:secret:servicenow/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
```

## Development

### Project Structure

```
servicenow-integration/
├── index.ts              # Main Lambda handler
├── types.ts              # TypeScript type definitions
├── utils.ts              # Utility functions (auth, retry, rate limit)
├── servicenow-client.ts  # ServiceNow API client
├── index.test.ts         # Unit tests
├── package.json          # Dependencies and scripts
├── tsconfig.json         # TypeScript configuration
└── README.md             # This file
```

### Testing

```bash
# Run all tests
npm test

# Watch mode
npm run test:watch

# Coverage report
npm run test:coverage
```

### Linting

```bash
# Check code style
npm run lint

# Auto-fix issues
npm run lint:fix
```

## Troubleshooting

### Common Issues

1. **Authentication Failed**

   - Verify credentials in Secrets Manager
   - Check ServiceNow instance URL
   - Ensure user has required permissions

2. **Rate Limit Exceeded**

   - Increase `MAX_REQUESTS` environment variable
   - Extend `WINDOW_MS` time window
   - Implement client-side throttling

3. **Timeout Errors**

   - Increase Lambda timeout (default: 60s)
   - Check ServiceNow instance performance
   - Verify network connectivity

4. **Missing Permissions**
   - Review IAM role permissions
   - Check ServiceNow user ACLs
   - Verify Secrets Manager access

## Performance Optimization

- **Connection Reuse**: HTTP client persists across invocations
- **Rate Limiting**: Prevents API throttling
- **Retry Logic**: Handles transient failures
- **Caching**: OAuth tokens cached until expiry

## Security Best Practices

✅ **DO:**

- Store credentials in Secrets Manager
- Use IAM roles for Lambda execution
- Enable CloudWatch Logs encryption
- Implement rate limiting
- Validate all input parameters
- Use HTTPS for ServiceNow connections

❌ **DON'T:**

- Hardcode credentials
- Expose sensitive data in logs
- Disable SSL verification
- Skip input validation

## License

MIT License - See LICENSE file for details

## Support

For issues and questions:

- GitHub Issues: [Your repository]
- Documentation: [Your docs]
- Email: [Your email]

## Contributing

1. Fork the repository
2. Create feature branch
3. Make changes with tests
4. Submit pull request

## Changelog

### v1.0.0 (2025-01-17)

- Initial release
- 31 ServiceNow actions
- OAuth and Basic Auth
- Rate limiting and retry logic
- Comprehensive error handling
- Unit tests with 80%+ coverage
