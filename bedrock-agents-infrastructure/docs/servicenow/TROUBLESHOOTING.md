# ServiceNow Bedrock Integration - Troubleshooting Guide

## Table of Contents

1. [Common Issues](#common-issues)
2. [Debug Procedures](#debug-procedures)
3. [Log Analysis](#log-analysis)
4. [Performance Issues](#performance-issues)
5. [ServiceNow API Errors](#servicenow-api-errors)
6. [Bedrock Errors](#bedrock-errors)
7. [Lambda Execution Issues](#lambda-execution-issues)

## Common Issues

### Issue 1: Incidents Not Being Analyzed

**Symptoms**:
- Incident created but not categorized
- No agent analysis in work notes
- ServiceNow rules appear to trigger but nothing happens

**Diagnosis Steps**:

1. **Check ServiceNow Business Rule**
   ```bash
   # Log in to ServiceNow instance
   # Navigate to: Incident > Administration > Business Rules
   # Find: "Incident Created - Notify Bedrock Agent"
   # Verify:
   #   - Active checkbox is checked
   #   - Filter conditions match your incident
   #   - Script includes are properly configured
   ```

2. **Check Lambda Function Logs**
   ```bash
   aws logs tail /aws/lambda/servicenow-incident-agent --follow

   # Look for:
   # - Function invocation entries
   # - Error messages
   # - Timeout warnings
   # - Permission errors
   ```

3. **Test API Gateway Endpoint**
   ```bash
   curl -X POST \
     -H "Content-Type: application/json" \
     -H "x-api-key: YOUR_API_KEY" \
     -d '{
       "incident_number": "INC0001234",
       "short_description": "Test incident",
       "description": "Testing agent invocation"
     }' \
     https://your-api-id.execute-api.region.amazonaws.com/prod/incident

   # Check HTTP response code and body
   ```

4. **Verify Secrets Manager Access**
   ```bash
   aws secretsmanager get-secret-value \
     --secret-id servicenow/credentials/bedrock-integration \
     --region us-east-1

   # Should return valid ServiceNow credentials
   ```

5. **Check IAM Permissions**
   ```bash
   # Verify Lambda execution role has:
   # - bedrock:InvokeAgent
   # - secretsmanager:GetSecretValue
   # - logs:CreateLogGroup, CreateLogStream, PutLogEvents
   # - dynamodb:PutItem, GetItem, UpdateItem
   ```

**Resolution**:

- If business rule not triggering: Enable it and verify filter conditions
- If Lambda not invoked: Check API Gateway configuration and endpoint
- If credentials error: Verify secrets in Secrets Manager
- If permissions error: Update IAM role with required permissions

---

### Issue 2: "Authentication Failed" Errors

**Symptoms**:
- HTTP 401 errors from ServiceNow API calls
- Error message: "Invalid OAuth token" or "Authentication failed"
- Agent cannot access incident data

**Common Causes**:

1. **Expired OAuth Token**
2. **Invalid Credentials in Secrets Manager**
3. **Incorrect API User Permissions**
4. **Network Connectivity Issues**

**Resolution Steps**:

1. **Verify Credentials in Secrets Manager**
   ```bash
   aws secretsmanager get-secret-value \
     --secret-id servicenow/credentials/bedrock-integration \
     --region us-east-1

   # Check:
   # - instance_url is correct (https://instance.service-now.com)
   # - api_user exists and is active
   # - api_token is valid (not expired)
   ```

2. **Test ServiceNow Credentials Directly**
   ```bash
   CREDS="servicenow_bedrock_api:YOUR_API_TOKEN"

   curl -u "$CREDS" \
     https://your-instance.service-now.com/api/now/table/incident?sysparm_limit=1

   # Should return 200 OK with incident data
   ```

3. **Regenerate API Token**
   ```
   ServiceNow:
   1. Log in as the service account user
   2. Go to User Profile > Reset API Token
   3. Copy new token
   4. Update in Secrets Manager:
   ```
   ```bash
   aws secretsmanager update-secret \
     --secret-id servicenow/credentials/bedrock-integration \
     --secret-string '{
       "instance_url": "https://instance.service-now.com",
       "api_user": "servicenow_bedrock_api",
       "api_token": "NEW_TOKEN_HERE"
     }'
   ```

4. **Verify API User Permissions**
   ```
   ServiceNow:
   1. Navigate to System Security > Users > servicenow_bedrock_api
   2. Verify roles assigned:
      - incident_manager
      - change_manager
      - knowledge_manager
      - web_service_admin
   3. Check "Active" checkbox is enabled
   ```

5. **Check Network Connectivity**
   ```bash
   # From Lambda environment or local test:
   curl -I https://your-instance.service-now.com

   # Should return 200 OK, not timeout or connection refused
   ```

---

### Issue 3: Agent Takes Too Long to Respond

**Symptoms**:
- Lambda timeout after 60-300 seconds
- Slow agent analysis
- Increased latency for incident processing

**Diagnosis**:

1. **Check CloudWatch Metrics**
   ```bash
   aws cloudwatch get-metric-statistics \
     --namespace AWS/Lambda \
     --metric-name Duration \
     --dimensions Name=FunctionName,Value=servicenow-incident-agent \
     --start-time 2024-11-17T00:00:00Z \
     --end-time 2024-11-17T23:59:59Z \
     --period 3600 \
     --statistics Maximum,Average
   ```

2. **Review Lambda Logs**
   ```bash
   aws logs tail /aws/lambda/servicenow-incident-agent --follow

   # Look for:
   # - ServiceNow API call times
   # - Bedrock invocation times
   # - Database operations
   # - Processing delays
   ```

3. **Check Concurrent Lambda Executions**
   ```bash
   aws lambda get-function-concurrency \
     --function-name servicenow-incident-agent

   # If at reserved limit, may cause queueing
   ```

**Optimization Steps**:

1. **Increase Lambda Memory** (improves CPU and speed)
   ```bash
   aws lambda update-function-configuration \
     --function-name servicenow-incident-agent \
     --memory-size 1536
   ```

2. **Increase Lambda Timeout** (for complex operations)
   ```bash
   aws lambda update-function-configuration \
     --function-name servicenow-incident-agent \
     --timeout 600
   ```

3. **Increase Concurrency**
   ```bash
   aws lambda put-function-concurrency \
     --function-name servicenow-incident-agent \
     --reserved-concurrent-executions 100
   ```

4. **Implement Caching**
   - Cache KB search results (1-hour TTL)
   - Cache user/group information (24-hour TTL)
   - Reduces API calls by 40-60%

5. **Optimize ServiceNow Queries**
   ```bash
   # Before: Gets full incident record with all fields
   # Slow: Fields not specified
   GET /api/now/table/incident/sys_id

   # After: Gets only required fields
   # Fast: Specific fields requested
   GET /api/now/table/incident/sys_id?sysparm_fields=number,short_description,state
   ```

6. **Use Bedrock Model Optimization**
   ```javascript
   // Use faster model for simple tasks
   const simpleIncident = {
     short_description: "Password reset",
     description: "User forgot password"
   };

   // Use Haiku (faster, cheaper)
   agent = "anthropic.claude-3-haiku-20250101-v1:0"

   // Use Sonnet for complex analysis
   const complexIncident = { /* complex data */ };
   agent = "anthropic.claude-3-5-sonnet-20241022-v2:0"
   ```

---

### Issue 4: Knowledge Base Not Updating

**Symptoms**:
- No KB articles created from incident resolutions
- Duplicate articles still exist in KB
- Old articles not being updated

**Diagnosis Steps**:

1. **Check KB Agent Logs**
   ```bash
   aws logs tail /aws/lambda/servicenow-kb-agent --follow

   # Look for:
   # - Article generation attempts
   # - Error messages
   # - Success/failure records
   ```

2. **Verify KB Agent Configuration**
   ```bash
   aws lambda get-function-configuration \
     --function-name servicenow-kb-agent

   # Check:
   # - Environment variables set correctly
   # - Timeout sufficient (600 seconds recommended)
   # - Memory adequate (512 MB minimum)
   ```

3. **Check KB Permissions**
   ```
   ServiceNow:
   1. Go to System Security > Users > servicenow_bedrock_api
   2. Verify roles include: knowledge_manager
   3. Check table acl_kb_knowledge for permissions
   ```

4. **Test KB API Directly**
   ```bash
   CREDS="servicenow_bedrock_api:YOUR_API_TOKEN"

   curl -u "$CREDS" \
     -X POST \
     -H "Content-Type: application/json" \
     -d '{
       "short_description": "Test Article",
       "text": "This is a test KB article",
       "category": "Test",
       "workflow_state": "draft"
     }' \
     https://your-instance.service-now.com/api/now/table/kb_knowledge

   # Should return 201 Created
   ```

**Resolution**:

1. **Enable KB Agent**
   ```bash
   # Ensure Lambda function is deployed and active
   aws lambda get-function-configuration \
     --function-name servicenow-kb-agent
   ```

2. **Configure Trigger**
   ```
   ServiceNow:
   1. Create business rule: "Incident Resolved - Trigger KB Agent"
   2. Trigger on: incident.state changes to "Resolved"
   3. Call Lambda webhook with incident data
   ```

3. **Check Cloudwatch Events Schedule**
   ```bash
   # If using scheduled KB maintenance:
   aws events list-rules \
     --name-prefix servicenow-kb

   # Verify rule is enabled and schedule is correct
   ```

---

## Debug Procedures

### Enable Detailed Logging

```bash
# Update Lambda environment variables
aws lambda update-function-configuration \
  --function-name servicenow-incident-agent \
  --environment Variables="{
    LOG_LEVEL=DEBUG,
    ENABLE_API_LOGGING=true,
    ENABLE_AGENT_LOGGING=true
  }"
```

### Local Testing with SAM

```bash
# Install AWS SAM CLI
npm install -g aws-sam-cli

# Create test event
cat > test-event.json << 'EOF'
{
  "httpMethod": "POST",
  "body": "{\"incident_number\": \"INC0001234\", \"short_description\": \"Test\"}"
}
EOF

# Test locally
sam local invoke servicenow-incident-agent -e test-event.json

# Check CloudWatch logs
aws logs tail /aws/lambda/servicenow-incident-agent --follow
```

### Manual Agent Invocation

```bash
# Invoke Lambda directly
aws lambda invoke \
  --function-name servicenow-incident-agent \
  --payload file://test-event.json \
  response.json

# Check response
cat response.json | jq '.'
```

### ServiceNow Query Testing

```bash
# Test incident retrieval
curl -u "servicenow_bedrock_api:TOKEN" \
  'https://instance.service-now.com/api/now/table/incident?sysparm_limit=1&sysparm_fields=number,short_description,state'

# Test KB search
curl -u "servicenow_bedrock_api:TOKEN" \
  'https://instance.service-now.com/api/now/table/kb_knowledge?sysparm_query=CONTAINS(text,%27database%27)&sysparm_limit=5'

# Test user lookup
curl -u "servicenow_bedrock_api:TOKEN" \
  'https://instance.service-now.com/api/now/table/sys_user?sysparm_query=nameSTARTSWITHjohn'
```

---

## Log Analysis

### CloudWatch Log Patterns

```
Successful Incident Analysis:
[START] RequestId: req-123
[INFO] Incident INC0001234 received
[DEBUG] Searching KB for "database timeout"
[DEBUG] Found 5 KB articles
[DEBUG] Invoking Bedrock agent
[INFO] Analysis complete: Category=Software, Priority=1
[DEBUG] Updating incident in ServiceNow
[INFO] Incident updated successfully
[END] Duration: 2.345s

Failed API Call:
[ERROR] ServiceNow API returned 401: Invalid OAuth token
[DEBUG] Incident sys_id: a59c6c43db...
[ERROR] Failed to update incident: {error details}
[INFO] Escalating to error handler
[END] Failed with exception

Timeout Issue:
[START] RequestId: req-456
[INFO] Processing incident INC0001235
[DEBUG] KB search timeout after 30 seconds
[WARN] Timeout in external service call
[INFO] Retrying with fallback behavior
[END] Duration: 60.000s (approached timeout)
```

### Log Query Examples

```bash
# Find all errors in last hour
aws logs filter-log-events \
  --log-group-name /aws/lambda/servicenow-incident-agent \
  --start-time $(($(date +%s%N)/1000000 - 3600000)) \
  --filter-pattern "ERROR"

# Find slow operations (>5 seconds)
aws logs filter-log-events \
  --log-group-name /aws/lambda/servicenow-incident-agent \
  --filter-pattern "[..., duration > 5000]"

# Find authentication errors
aws logs filter-log-events \
  --log-group-name /aws/lambda/servicenow-incident-agent \
  --filter-pattern "401 OR unauthorized OR authentication"

# Find timeout warnings
aws logs filter-log-events \
  --log-group-name /aws/lambda/servicenow-incident-agent \
  --filter-pattern "timeout OR exceeded"
```

---

## Performance Issues

### Slow Incident Analysis

**Root Causes**:
1. Large KB with slow search (>30 seconds)
2. Incident history with many similar records
3. Bedrock model processing (inference time)
4. ServiceNow API latency

**Solutions**:

1. **Implement KB Search Caching**
   ```javascript
   // Cache search results for 1 hour
   const cachedResult = await cache.get(`kb-search:${symptom}`);
   if (cachedResult) return cachedResult;

   const result = await searchKB(symptom);
   await cache.set(`kb-search:${symptom}`, result, 3600);
   return result;
   ```

2. **Optimize Incident History Queries**
   ```bash
   # Before: Returns all fields for last 1000 incidents (slow)
   # After: Returns only essential fields, limit to 100 (fast)

   GET /api/now/table/incident?sysparm_limit=100&sysparm_fields=number,state,category
   ```

3. **Use Faster Model for Simple Cases**
   ```javascript
   if (isSimpleIncident(incident)) {
     // Use Haiku for fast simple analysis
     model = "anthropic.claude-3-haiku-20250101-v1:0";
   } else {
     // Use Sonnet for complex analysis
     model = "anthropic.claude-3-5-sonnet-20241022-v2:0";
   }
   ```

### High Memory Usage

**Diagnosis**:
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name MemoryUtilization \
  --dimensions Name=FunctionName,Value=servicenow-incident-agent \
  --start-time 2024-11-17T00:00:00Z \
  --end-time 2024-11-17T23:59:59Z \
  --period 300 \
  --statistics Maximum,Average
```

**Solutions**:

1. Increase Lambda memory allocation
2. Stream large responses instead of buffering
3. Clean up variables after use
4. Use smaller model or summarization

---

## ServiceNow API Errors

### HTTP 429 - Rate Limited

**Error Message**:
```
HTTP 429 Too Many Requests
RateLimit-Remaining: 0
RateLimit-Reset: 1637081400
Retry-After: 60
```

**Solution**:
```javascript
// Implement exponential backoff
async function callWithBackoff(fn, maxRetries = 4) {
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await fn();
    } catch (error) {
      if (error.status === 429) {
        const backoffMs = Math.pow(2, i) * 30000; // 30s, 60s, 120s, 240s
        console.log(`Rate limited, waiting ${backoffMs}ms before retry`);
        await new Promise(resolve => setTimeout(resolve, backoffMs));
      } else {
        throw error;
      }
    }
  }
}
```

### HTTP 400 - Bad Request

**Common Causes**:
- Invalid field value
- Missing required field
- Malformed JSON

**Debug**:
```bash
# Check request body
aws logs filter-log-events \
  --log-group-name /aws/lambda/servicenow-incident-agent \
  --filter-pattern "400 OR Bad Request"

# Check field values
curl -u "credentials" \
  -X POST \
  -d '{"field": "invalid"}' \
  https://instance.service-now.com/api/now/table/incident
```

---

## Bedrock Errors

### Model Unavailable

**Error**:
```
ValidationException: Model 'anthropic.claude-3-5-sonnet-20241022-v2:0' is not available
```

**Solution**:
```bash
# Check available models in your region
aws bedrock list-foundation-models --region us-east-1

# Use fallback model
MODEL_ID = "anthropic.claude-3-haiku-20250101-v1:0"
```

### Token Limit Exceeded

**Error**:
```
InputTokenLimitExceeded: Input tokens (8500) exceed model limit (8000)
```

**Solution**:
```javascript
// Summarize long incident descriptions
const summary = await summarizeText(incident.description, maxTokens=2000);
const incidentContext = {
  ...incident,
  description: summary
};
```

---

## Lambda Execution Issues

### Memory/Duration Limits

```bash
# Check current limits
aws lambda get-function-configuration --function-name servicenow-incident-agent

# Update limits
aws lambda update-function-configuration \
  --function-name servicenow-incident-agent \
  --memory-size 1024 \
  --timeout 300
```

### Concurrency Throttling

```bash
# Check concurrency
aws lambda get-function-concurrency --function-name servicenow-incident-agent

# Increase reserved concurrency
aws lambda put-function-concurrency \
  --function-name servicenow-incident-agent \
  --reserved-concurrent-executions 100
```

For additional support, check the [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md), [AGENT_GUIDE.md](AGENT_GUIDE.md), or [API_REFERENCE.md](API_REFERENCE.md).
