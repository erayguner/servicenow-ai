# ServiceNow + Bedrock Integration Deployment Guide

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [ServiceNow Configuration](#servicenow-configuration)
3. [AWS Account Setup](#aws-account-setup)
4. [Lambda Functions Deployment](#lambda-functions-deployment)
5. [Secrets Manager Configuration](#secrets-manager-configuration)
6. [Integration Testing](#integration-testing)
7. [Production Deployment](#production-deployment)
8. [Monitoring Setup](#monitoring-setup)
9. [Rollback Procedures](#rollback-procedures)

## Prerequisites

### ServiceNow Requirements

- **ServiceNow Instance**: Vancouver, Xanadu, or later version
- **Instance Type**: Production, Sandbox, or Development instance
- **Admin Access**: To create users, configure APIs, and manage workflows
- **Required Modules**:
  - Incident Management
  - Change Management
  - Knowledge Base
  - Service Catalog
- **REST API Enabled**: System > Web Services > REST APIs
- **MID Server** (optional): For on-premises integration

### AWS Requirements

- **AWS Account**: With appropriate permissions
- **IAM User**: With programmatic access (Access Key and Secret Key)
- **Permissions**:
  - Lambda full access
  - Bedrock full access
  - Secrets Manager access
  - DynamoDB access
  - CloudWatch access
  - API Gateway access
  - IAM role creation
- **Region**: Recommended us-east-1 or us-west-2 (Bedrock regions)

### Local Development Requirements

```bash
# Node.js and npm
node --version  # v18 or higher
npm --version   # v9 or higher

# AWS CLI
aws --version   # v2.13 or higher
aws configure   # Configure with your credentials

# Docker (for local testing)
docker --version

# Git
git --version   # v2.30 or higher
```

### Credentials and Access Tokens

```
1. ServiceNow Instance URL: https://your-instance.service-now.com
2. ServiceNow Admin User: admin (or service account)
3. ServiceNow Admin Password: [Secure password]
4. AWS Access Key ID: AKIA... (from IAM)
5. AWS Secret Access Key: [Generate from IAM]
```

## ServiceNow Configuration

### Step 1: Create ServiceNow Service Account

1. **Log in to ServiceNow** as administrator
2. **Navigate**: System Security > Users and Groups > Users
3. **Create New User**:

   ```
   Field              Value
   -------------------
   User ID            servicenow_bedrock_api
   First Name         ServiceNow
   Last Name          Bedrock Integration
   Email              integration@company.com
   Phone              [Optional]
   Department         IT Service Management
   Manager            [Select appropriate manager]
   ```

4. **Assign Roles**:

   - `incident_manager` (for incident operations)
   - `change_manager` (for change request operations)
   - `knowledge_manager` (for KB operations)
   - `web_service_admin` (for API access)

5. **Reset API Token**:
   - Click on the newly created user
   - Click "Reset API Token" (or generate in API Token table)
   - Copy the token securely

### Step 2: Enable REST API

1. **Navigate**: System Web Services > REST APIs
2. **Verify REST API is enabled**:

   ```
   System > System Settings > REST API enabled checkbox should be checked
   ```

3. **Test REST API Access**:
   ```bash
   curl -u "servicenow_bedrock_api:YOUR_API_TOKEN" \
     https://your-instance.service-now.com/api/now/table/incident?sysparm_limit=1
   ```

### Step 3: Create Business Rules for Triggers

Create business rules to trigger Lambda functions when incidents/changes are
created or updated.

#### Incident Creation Trigger

1. **Navigate**: Incident > Incident [List] > Administration > Business Rules
2. **New Business Rule**:

   ```
   Name: Incident Created - Notify Bedrock Agent
   Table: Incident
   Active: Yes

   When to run: Before insert/update
   Filter conditions:
     - created_on changes
     - OR state is 1 (New)

   Actions:
     - Script:
       (function executeAction() {
         var payload = {
           'incident_number': current.number.toString(),
           'short_description': current.short_description.toString(),
           'description': current.description.toString(),
           'caller': current.caller_id.toString(),
           'state': current.state.toString()
         };

         var gr = new GlideRecord('sys_script_include');
         gr.addQuery('name', 'BedrockIntegrationUtil');
         gr.query();
         if (gr.next()) {
           var util = new BedrockIntegrationUtil();
           util.triggerIncidentAgent(payload);
         }
       })()
   ```

#### Change Request Trigger

1. **Navigate**: Change > Change Request [List] > Administration > Business
   Rules
2. **New Business Rule**:

   ```
   Name: Change Request - Notify Bedrock Agent
   Table: Change Request
   Active: Yes

   When to run: Before insert/update
   Filter conditions:
     - created_on changes
     - OR state changes

   Actions: Similar to incident, trigger change agent
   ```

### Step 4: Create Script Include for Integration

1. **Navigate**: System Definition > Script Includes
2. **New Script Include**:

   ```javascript
   Name: BedrockIntegrationUtil;

   var BedrockIntegrationUtil = Class.create();
   BedrockIntegrationUtil.prototype = {
     initialize: function () {
       this.apiEndpoint = gs.getProperty('servicenow.bedrock.api_endpoint', '');
       this.apiKey = gs.getProperty('servicenow.bedrock.api_key', '');
     },

     triggerIncidentAgent: function (payload) {
       try {
         var request = new GlideHTTPRequest();
         request.setEndpoint(this.apiEndpoint + '/incident');
         request.setBasicAuth('servicenow', this.apiKey);
         request.setBody(JSON.stringify(payload));
         request.execute();
       } catch (e) {
         gs.error('Bedrock integration error: ' + e);
       }
     },

     triggerChangeAgent: function (payload) {
       try {
         var request = new GlideHTTPRequest();
         request.setEndpoint(this.apiEndpoint + '/change');
         request.setBasicAuth('servicenow', this.apiKey);
         request.setBody(JSON.stringify(payload));
         request.execute();
       } catch (e) {
         gs.error('Bedrock integration error: ' + e);
       }
     },

     type: 'BedrockIntegrationUtil',
   };
   ```

### Step 5: Create System Properties

1. **Navigate**: System Properties > System Property
2. **Create New Properties**:

   ```
   Property Name: servicenow.bedrock.api_endpoint
   Value: https://your-lambda-api-gateway-url.execute-api.region.amazonaws.com/prod
   Private: No

   Property Name: servicenow.bedrock.api_key
   Value: [Your API key from API Gateway]
   Private: Yes (make sure this is marked as private)

   Property Name: servicenow.bedrock.max_retries
   Value: 3

   Property Name: servicenow.bedrock.timeout
   Value: 30000 (milliseconds)
   ```

### Step 6: Create Custom Tables for Audit Trail (Optional)

1. **Navigate**: System Definition > Tables
2. **New Table**:

   ```
   Table Name: Bedrock Agent Execution
   Label: Bedrock Agent Execution

   Add Columns:
     - incident_id (Reference to Incident)
     - agent_type (String)
     - execution_timestamp (DateTime)
     - execution_status (Choice: Success/Failed/In Progress)
     - response_summary (Text)
     - execution_time (Integer - milliseconds)
     - error_message (Text)
   ```

## AWS Account Setup

### Step 1: Create IAM Role for Lambda

1. **AWS Console**: IAM > Roles > Create Role
2. **Service**: Lambda
3. **Permissions Policies**: Attach the following policies:

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": ["bedrock:InvokeAgent", "bedrock:InvokeModel"],
         "Resource": "*"
       },
       {
         "Effect": "Allow",
         "Action": [
           "secretsmanager:GetSecretValue",
           "secretsmanager:DescribeSecret"
         ],
         "Resource": "arn:aws:secretsmanager:*:*:secret:servicenow/*"
       },
       {
         "Effect": "Allow",
         "Action": [
           "dynamodb:PutItem",
           "dynamodb:GetItem",
           "dynamodb:UpdateItem",
           "dynamodb:Query",
           "dynamodb:Scan"
         ],
         "Resource": "arn:aws:dynamodb:*:*:table/servicenow-*"
       },
       {
         "Effect": "Allow",
         "Action": [
           "logs:CreateLogGroup",
           "logs:CreateLogStream",
           "logs:PutLogEvents"
         ],
         "Resource": "arn:aws:logs:*:*:*"
       },
       {
         "Effect": "Allow",
         "Action": ["cloudwatch:PutMetricData"],
         "Resource": "*"
       },
       {
         "Effect": "Allow",
         "Action": ["sns:Publish"],
         "Resource": "arn:aws:sns:*:*:servicenow-*"
       }
     ]
   }
   ```

4. **Role Name**: `servicenow-bedrock-lambda-role`

### Step 2: Create Bedrock Agent

1. **AWS Console**: Bedrock > Agents > Create Agent
2. **Configure Agent**:

   ```
   Agent Name: ServiceNow Incident Agent
   Agent Description: AI agent for incident resolution

   Model: Claude 3.5 Sonnet (anthropic.claude-3-5-sonnet-20241022-v2:0)

   Agent Instructions:
   "You are an AI assistant specialized in IT incident management integrated with ServiceNow.
   Your role is to:
   1. Analyze incident descriptions and symptoms
   2. Search the knowledge base for solutions
   3. Provide troubleshooting steps
   4. Recommend appropriate teams for assignment
   5. Update incident records with recommendations

   Always be professional, clear, and provide step-by-step guidance. When uncertain,
   escalate to human experts and provide context for their decision-making."

   Session State Configuration:
     - Track conversation history
     - Maintain context across interactions
     - Store intermediate results
   ```

3. **Add Agent Tools** (will be configured in Lambda):
   - SearchIncidents
   - UpdateIncident
   - SearchKnowledgeBase
   - GetUserInfo
   - AssignIncident

### Step 3: Create DynamoDB Tables

```bash
# Table 1: Agent Session State
aws dynamodb create-table \
  --table-name servicenow-agent-sessions \
  --attribute-definitions AttributeName=sessionId,AttributeType=S \
  --key-schema AttributeName=sessionId,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --tags Key=Project,Value=ServiceNow Key=Purpose,Value=AgentSessions

# Table 2: Incident Cache
aws dynamodb create-table \
  --table-name servicenow-incident-cache \
  --attribute-definitions \
    AttributeName=incidentId,AttributeType=S \
    AttributeName=timestamp,AttributeType=N \
  --key-schema \
    AttributeName=incidentId,KeyType=HASH \
    AttributeName=timestamp,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST \
  --tags Key=Project,Value=ServiceNow

# Table 3: Agent Audit Trail
aws dynamodb create-table \
  --table-name servicenow-agent-audit \
  --attribute-definitions AttributeName=executionId,AttributeType=S \
  --key-schema AttributeName=executionId,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --ttl-specification AttributeName=expirationTime,Enabled=true \
  --tags Key=Project,Value=ServiceNow
```

### Step 4: Create SNS Topics

```bash
# Create SNS topics for notifications
aws sns create-topic --name servicenow-incident-alerts
aws sns create-topic --name servicenow-change-alerts
aws sns create-topic --name servicenow-kb-alerts
aws sns create-topic --name servicenow-errors

# Subscribe to alerts
aws sns subscribe \
  --topic-arn arn:aws:sns:region:account:servicenow-incident-alerts \
  --protocol email \
  --notification-endpoint your-email@company.com
```

## Secrets Manager Configuration

### Step 1: Create Secrets

```bash
# Secret 1: ServiceNow Credentials
aws secretsmanager create-secret \
  --name servicenow/credentials/bedrock-integration \
  --description "ServiceNow API credentials for Bedrock integration" \
  --secret-string '{
    "instance_url": "https://your-instance.service-now.com",
    "api_user": "servicenow_bedrock_api",
    "api_token": "YOUR_API_TOKEN_HERE"
  }'

# Secret 2: Bedrock Agent Configuration
aws secretsmanager create-secret \
  --name servicenow/bedrock/agent-config \
  --description "Bedrock agent configuration" \
  --secret-string '{
    "agent_id": "YOUR_AGENT_ID",
    "agent_alias_id": "PROD",
    "model_id": "anthropic.claude-3-5-sonnet-20241022-v2:0",
    "bedrock_region": "eu-west-2"
  }'

# Secret 3: API Gateway Key
aws secretsmanager create-secret \
  --name servicenow/api-gateway/key \
  --description "API Gateway subscription key" \
  --secret-string '{
    "api_key": "YOUR_API_KEY_HERE",
    "api_endpoint": "https://your-api-id.execute-api.region.amazonaws.com/prod"
  }'
```

### Step 2: Configure Secret Rotation (Optional but Recommended)

```bash
# Create Lambda rotation function
aws secretsmanager rotate-secret \
  --secret-id servicenow/credentials/bedrock-integration \
  --rotation-rules AutomaticallyAfterDays=30 \
  --rotation-lambda-arn arn:aws:lambda:region:account:function:rotate-secrets

# Enable rotation
aws secretsmanager update-secret-version-stage \
  --secret-id servicenow/credentials/bedrock-integration \
  --version-stage AWSCURRENT
```

## Lambda Functions Deployment

### Step 1: Prepare Lambda Function Code

```bash
# Clone or download the bedrock-agents-infrastructure
cd /path/to/bedrock-agents-infrastructure/lambda

# Create deployment package
mkdir -p lambda-package
cd lambda-package

# Install dependencies
npm install axios jsonwebtoken uuid aws-sdk

# Copy Lambda function code
cp ../src/incident-agent-handler.js .
cp ../src/change-agent-handler.js .
cp ../src/kb-agent-handler.js .
cp ../src/shared/servicenow-client.js shared/
cp ../src/shared/bedrock-client.js shared/
```

### Step 2: Deploy Incident Agent Handler

```bash
# Package the function
zip -r incident-agent-handler.zip .

# Create Lambda function
aws lambda create-function \
  --function-name servicenow-incident-agent \
  --runtime nodejs18.x \
  --role arn:aws:iam::ACCOUNT:role/servicenow-bedrock-lambda-role \
  --handler incident-agent-handler.handler \
  --zip-file fileb://incident-agent-handler.zip \
  --timeout 300 \
  --memory-size 1024 \
  --environment Variables="{
    SERVICENOW_INSTANCE=https://your-instance.service-now.com,
    BEDROCK_REGION=us-east-1,
    AGENT_ID=YOUR_AGENT_ID,
    SESSION_TABLE=servicenow-agent-sessions,
    CACHE_TABLE=servicenow-incident-cache,
    AUDIT_TABLE=servicenow-agent-audit
  }" \
  --tags "Project=ServiceNow,Purpose=IncidentAgent"

# Update function configuration
aws lambda update-function-code \
  --function-name servicenow-incident-agent \
  --zip-file fileb://incident-agent-handler.zip
```

### Step 3: Deploy Change Agent Handler

```bash
# Similar process for change agent
zip -r change-agent-handler.zip .

aws lambda create-function \
  --function-name servicenow-change-agent \
  --runtime nodejs18.x \
  --role arn:aws:iam::ACCOUNT:role/servicenow-bedrock-lambda-role \
  --handler change-agent-handler.handler \
  --zip-file fileb://change-agent-handler.zip \
  --timeout 300 \
  --memory-size 1024
```

### Step 4: Deploy Knowledge Base Agent Handler

```bash
# Similar process for KB agent
zip -r kb-agent-handler.zip .

aws lambda create-function \
  --function-name servicenow-kb-agent \
  --runtime nodejs18.x \
  --role arn:aws:iam::ACCOUNT:role/servicenow-bedrock-lambda-role \
  --handler kb-agent-handler.handler \
  --zip-file fileb://kb-agent-handler.zip \
  --timeout 600 \
  --memory-size 512
```

## API Gateway Configuration

### Step 1: Create REST API

```bash
# Create API
aws apigateway create-rest-api \
  --name servicenow-bedrock-integration \
  --description "API Gateway for ServiceNow Bedrock integration" \
  --api-key-selection-expression header.X-API-Key

# Note the REST API ID
API_ID="YOUR_API_ID_HERE"
```

### Step 2: Create Resources and Methods

```bash
# Get root resource
ROOT_ID=$(aws apigateway get-resources --rest-api-id $API_ID \
  --query 'items[0].id' --output text)

# Create /incident resource
INCIDENT_ID=$(aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $ROOT_ID \
  --path-part incident \
  --query 'id' --output text)

# Create POST method
aws apigateway put-method \
  --rest-api-id $API_ID \
  --resource-id $INCIDENT_ID \
  --http-method POST \
  --authorization-type AWS_IAM \
  --api-key-required

# Set Lambda integration
aws apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id $INCIDENT_ID \
  --http-method POST \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri arn:aws:apigateway:region:lambda:path/2015-03-31/functions/arn:aws:lambda:region:account:function:servicenow-incident-agent/invocations
```

### Step 3: Deploy API

```bash
# Create deployment
aws apigateway create-deployment \
  --rest-api-id $API_ID \
  --stage-name prod

# Get API endpoint
API_ENDPOINT=$(aws apigateway get-rest-api \
  --rest-api-id $API_ID \
  --query 'endpointConfiguration.types[0]' --output text)

echo "API Endpoint: https://$API_ID.execute-api.region.amazonaws.com/prod"
```

### Step 4: Configure API Keys and Usage Plans

```bash
# Create API key
API_KEY=$(aws apigateway create-api-key \
  --name servicenow-integration \
  --description "API Key for ServiceNow integration" \
  --enabled \
  --query 'id' --output text)

# Create usage plan
USAGE_PLAN=$(aws apigateway create-usage-plan \
  --name servicenow-integration-plan \
  --description "Usage plan for ServiceNow integration" \
  --quota '{"limit": 100000, "period": "DAY"}' \
  --throttle '{"rateLimit": 1000, "burstLimit": 2000}' \
  --query 'id' --output text)

# Associate API key with usage plan
aws apigateway create-usage-plan-key \
  --usage-plan-id $USAGE_PLAN \
  --key-id $API_KEY \
  --key-type API_KEY

echo "API Key: $API_KEY"
```

## Integration Testing

### Step 1: Test ServiceNow API Connectivity

```bash
# Test incident retrieval
curl -u "servicenow_bedrock_api:YOUR_API_TOKEN" \
  https://your-instance.service-now.com/api/now/table/incident?sysparm_limit=1

# Test incident creation
curl -u "servicenow_bedrock_api:YOUR_API_TOKEN" \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "short_description": "Test incident from Bedrock",
    "description": "This is a test incident",
    "caller_id": "your-user-id"
  }' \
  https://your-instance.service-now.com/api/now/table/incident
```

### Step 2: Test Lambda Function Locally

```bash
# Create test event
cat > test-event.json << 'EOF'
{
  "body": {
    "incident_number": "INC0001234",
    "short_description": "Unable to connect to database",
    "description": "Users experiencing connection timeouts",
    "caller_id": "user-id"
  }
}
EOF

# Test locally
aws lambda invoke \
  --function-name servicenow-incident-agent \
  --payload file://test-event.json \
  response.json

# Check response
cat response.json
```

### Step 3: Test API Gateway Endpoint

```bash
# Test API endpoint
curl -X POST \
  -H "Content-Type: application/json" \
  -H "x-api-key: YOUR_API_KEY" \
  -d '{
    "incident_number": "INC0001234",
    "short_description": "Test incident",
    "description": "Testing API integration"
  }' \
  https://your-api-id.execute-api.region.amazonaws.com/prod/incident

# Check CloudWatch logs
aws logs tail /aws/lambda/servicenow-incident-agent --follow
```

### Step 4: Test End-to-End Integration

```bash
# 1. Create incident in ServiceNow
curl -u "servicenow_bedrock_api:YOUR_API_TOKEN" \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "short_description": "E2E test incident",
    "description": "Testing end-to-end integration",
    "caller_id": "your-user-id"
  }' \
  https://your-instance.service-now.com/api/now/table/incident

# 2. Monitor CloudWatch logs for agent invocation
aws logs tail /aws/lambda/servicenow-incident-agent --follow

# 3. Check incident updates in ServiceNow
curl -u "servicenow_bedrock_api:YOUR_API_TOKEN" \
  https://your-instance.service-now.com/api/now/table/incident?sysparm_limit=1&sysparm_query=created_onONTODAY
```

## Production Deployment

### Step 1: Enable VPC Configuration

```bash
# Create VPC endpoint for ServiceNow (if on-premises)
aws ec2 create-vpc-endpoint \
  --vpc-id vpc-XXXXXX \
  --service-name servicenow-endpoint \
  --route-table-ids rtb-XXXXXX

# Update Lambda function to use VPC
aws lambda update-function-configuration \
  --function-name servicenow-incident-agent \
  --vpc-config SubnetIds=subnet-XXXXXX,SecurityGroupIds=sg-XXXXXX
```

### Step 2: Enable Logging and Monitoring

```bash
# Create CloudWatch log groups
aws logs create-log-group --log-group-name /aws/lambda/servicenow-incident-agent
aws logs create-log-group --log-group-name /aws/lambda/servicenow-change-agent
aws logs create-log-group --log-aws-lambda/servicenow-kb-agent

# Configure log retention (30 days)
for log_group in /aws/lambda/servicenow-{incident,change,kb}-agent; do
  aws logs put-retention-policy \
    --log-group-name $log_group \
    --retention-in-days 30
done

# Create custom metrics
aws cloudwatch put-metric-alarm \
  --alarm-name servicenow-agent-errors \
  --alarm-description "Alert on ServiceNow agent errors" \
  --metric-name Errors \
  --namespace AWS/Lambda \
  --statistic Sum \
  --period 300 \
  --threshold 5 \
  --comparison-operator GreaterThanThreshold
```

### Step 3: Configure Auto-Scaling

```bash
# Set up Lambda reserved concurrency
aws lambda put-function-concurrency \
  --function-name servicenow-incident-agent \
  --reserved-concurrent-executions 100

aws lambda put-function-concurrency \
  --function-name servicenow-change-agent \
  --reserved-concurrent-executions 50

aws lambda put-function-concurrency \
  --function-name servicenow-kb-agent \
  --reserved-concurrent-executions 25
```

### Step 4: Implement Blue-Green Deployment

```bash
# Create alias for live traffic
aws lambda create-alias \
  --function-name servicenow-incident-agent \
  --name live \
  --function-version 1

# Create new version
NEW_VERSION=$(aws lambda publish-version \
  --function-name servicenow-incident-agent \
  --query 'Version' --output text)

# Update alias gradually (10% traffic to new version)
aws lambda update-alias \
  --function-name servicenow-incident-agent \
  --name live \
  --function-version $NEW_VERSION \
  --routing-config AdditionalVersionWeight=0.1

# Monitor error rate, then increase traffic
# aws lambda update-alias --routing-config AdditionalVersionWeight=0.5
# aws lambda update-alias --routing-config AdditionalVersionWeight=1.0
```

## Monitoring Setup

### CloudWatch Dashboard

```bash
# Create dashboard for monitoring
aws cloudwatch put-dashboard \
  --dashboard-name ServiceNow-Bedrock-Integration \
  --dashboard-body '{
    "widgets": [
      {
        "type": "metric",
        "properties": {
          "metrics": [
            ["AWS/Lambda", "Invocations", {"stat": "Sum"}],
            ["AWS/Lambda", "Errors", {"stat": "Sum"}],
            ["AWS/Lambda", "Duration", {"stat": "Average"}]
          ],
          "period": 300,
          "stat": "Average",
          "region": "eu-west-2",
          "title": "Lambda Metrics"
        }
      }
    ]
  }'
```

### Alarms Configuration

```bash
# Create alarms for critical metrics
aws cloudwatch put-metric-alarm \
  --alarm-name servicenow-lambda-high-error-rate \
  --alarm-description "Alert when error rate exceeds 5%" \
  --metric-name Errors \
  --namespace AWS/Lambda \
  --statistic Average \
  --period 300 \
  --threshold 0.05 \
  --comparison-operator GreaterThanThreshold \
  --alarm-actions arn:aws:sns:region:account:servicenow-errors

aws cloudwatch put-metric-alarm \
  --alarm-name servicenow-lambda-high-latency \
  --alarm-description "Alert when avg latency exceeds 30s" \
  --metric-name Duration \
  --namespace AWS/Lambda \
  --statistic Average \
  --period 300 \
  --threshold 30000 \
  --comparison-operator GreaterThanThreshold \
  --alarm-actions arn:aws:sns:region:account:servicenow-errors
```

## Rollback Procedures

### Step 1: Immediate Rollback (Lambda)

```bash
# Get previous function version
PREVIOUS_VERSION=$(aws lambda list-versions-by-function \
  --function-name servicenow-incident-agent \
  --query 'Versions[-2].Version' --output text)

# Update alias to point to previous version
aws lambda update-alias \
  --function-name servicenow-incident-agent \
  --name live \
  --function-version $PREVIOUS_VERSION
```

### Step 2: API Gateway Rollback

```bash
# Get previous deployment
PREVIOUS_DEPLOYMENT=$(aws apigateway get-deployments \
  --rest-api-id $API_ID \
  --query 'items[-2].id' --output text)

# Update stage to use previous deployment
aws apigateway update-stage \
  --rest-api-id $API_ID \
  --stage-name prod \
  --patch-operations \
    op=replace,path=/deploymentId,value=$PREVIOUS_DEPLOYMENT
```

### Step 3: ServiceNow Rollback

```bash
# Disable business rules
curl -u "admin:password" \
  -X PATCH \
  -H "Content-Type: application/json" \
  -d '{"active": false}' \
  https://your-instance.service-now.com/api/now/table/sys_business_rule/YOUR_RULE_ID
```

### Step 4: Data Rollback

```bash
# Restore incident data from backup
aws dynamodb batch-write-item \
  --request-items '{
    "servicenow-incident-cache": [
      {
        "PutRequest": {
          "Item": {
            "incidentId": {"S": "INC0001234"},
            "data": {"S": "backup-data"}
          }
        }
      }
    ]
  }'

# Restore from DynamoDB backups (if available)
aws dynamodb restore-table-from-backup \
  --target-table-name servicenow-incident-cache-restored \
  --backup-arn arn:aws:dynamodb:region:account:table/backup
```

## Verification Checklist

After deployment, verify:

- [ ] ServiceNow API connectivity working
- [ ] Lambda functions deployed and tested
- [ ] Secrets Manager credentials accessible
- [ ] DynamoDB tables created and accessible
- [ ] CloudWatch logs showing agent activity
- [ ] API Gateway endpoint responding
- [ ] SNS notifications being sent
- [ ] Business rules triggering correctly
- [ ] Incident agent analyzing new incidents
- [ ] Change agent processing new changes
- [ ] KB agent synchronizing articles
- [ ] Monitoring dashboards showing data
- [ ] Alarms configured and testing successfully
- [ ] Rollback procedures tested

## Support and Troubleshooting

For common issues and troubleshooting steps, refer to the
[TROUBLESHOOTING.md](TROUBLESHOOTING.md) guide.

For detailed API information, see [API_REFERENCE.md](API_REFERENCE.md).

For workflow examples, see [WORKFLOWS.md](WORKFLOWS.md).
