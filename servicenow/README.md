# ServiceNow Integration

ServiceNow integration components for the AI Agent system, providing bidirectional communication between ServiceNow and the AI backend.

## Overview

This directory contains ServiceNow-specific code that runs within the ServiceNow platform to enable AI-powered automation and assistance.

### Components

```
servicenow/
├── business_rules/          # Automated workflows triggered by table events
│   └── incident_comment_to_pubsub.js
├── script_includes/         # Reusable server-side code libraries
│   └── AiIntegrationUtils.js
└── scripted_rest/           # REST API endpoints exposed by ServiceNow
    └── incidents.js
```

## Architecture

```
┌─────────────────┐         ┌──────────────────┐         ┌──────────────┐
│   ServiceNow    │  REST   │  Backend API     │  LLM    │ Claude/Gemini│
│   Platform      │ ◄─────► │  (Node.js)       │ ◄─────► │   Models     │
│                 │         │                  │         │              │
│ • Business Rules│         │ • Chat API       │         │              │
│ • Script Inc   │         │ • Session Mgmt   │         │              │
│ • Scripted REST│         │ • LLM Integration│         │              │
└─────────────────┘         └──────────────────┘         └──────────────┘
         │                           │
         │  Pub/Sub                  │
         └───────────────────────────┘
           GCP Pub/Sub Topics
```

## Features

### Business Rules
- ✅ Automated incident enrichment with AI suggestions
- ✅ Real-time comment analysis and classification
- ✅ Pub/Sub event publishing for external processing
- ✅ Trigger-based AI assistant invocation

### Script Includes
- ✅ Reusable AI integration utilities
- ✅ HTTP client for backend API communication
- ✅ Error handling and retry logic
- ✅ Authentication token management

### Scripted REST APIs
- ✅ Incident management endpoints
- ✅ AI suggestion retrieval
- ✅ Webhook receivers for external events
- ✅ Health check and status endpoints

## Installation

### Prerequisites

- ServiceNow instance (Orlando release or newer)
- Admin or elevated developer access
- GCP Pub/Sub topic configured
- Backend API deployed and accessible

### Step 1: Configure External Communications

```javascript
// Navigate to: System Web Services > Outbound > REST Message
// Create new REST Message for Backend API

Name: AI Backend API
Endpoint: https://YOUR_BACKEND_URL/api/v1
Authentication: API Key or OAuth

// HTTP Methods:
// - POST /chat
// - POST /sessions
// - GET /health
```

### Step 2: Install Script Include

1. Navigate to **System Definition > Script Includes**
2. Click **New**
3. Copy content from `script_includes/AiIntegrationUtils.js`
4. Configure:
   - **Name**: `AiIntegrationUtils`
   - **API Name**: `AiIntegrationUtils`
   - **Client Callable**: No (server-side only)
   - **Active**: Yes

### Step 3: Install Business Rules

1. Navigate to **System Definition > Business Rules**
2. Click **New**
3. Copy content from `business_rules/incident_comment_to_pubsub.js`
4. Configure:
   - **Name**: `Incident Comment to Pub/Sub`
   - **Table**: `incident`
   - **When**: After Insert/Update
   - **Filter Conditions**: Comments field changes
   - **Active**: Yes

### Step 4: Install Scripted REST APIs

1. Navigate to **System Web Services > Scripted REST APIs**
2. Click **New**
3. Configure:
   - **Name**: `AI Incident Management API`
   - **API ID**: `ai_incident_api`
   - **Base API path**: `/api/ai/v1`
4. Create resources from `scripted_rest/incidents.js`

### Step 5: Configure Connection Properties

```javascript
// System Properties > New
// Property: x_ai_backend_url
// Type: string
// Value: https://YOUR_BACKEND_URL
// Description: AI Backend API endpoint URL

// Property: x_ai_backend_api_key
// Type: password2
// Value: YOUR_API_KEY
// Description: AI Backend API authentication key

// Property: x_ai_pubsub_topic
// Type: string
// Value: projects/YOUR_PROJECT/topics/YOUR_TOPIC
// Description: GCP Pub/Sub topic for events
```

## Configuration

### Environment Variables (System Properties)

| Property | Description | Required | Example |
|----------|-------------|----------|---------|
| `x_ai_backend_url` | Backend API endpoint | Yes | `https://ai-backend.example.com` |
| `x_ai_backend_api_key` | API authentication key | Yes | `sk-...` |
| `x_ai_pubsub_topic` | GCP Pub/Sub topic path | Yes | `projects/PROJECT/topics/events` |
| `x_ai_enabled` | Enable AI features | No | `true` |
| `x_ai_debug_mode` | Enable debug logging | No | `false` |
| `x_ai_timeout_ms` | API request timeout | No | `30000` |

### Authentication Setup

#### Option 1: API Key

```javascript
// In REST Message
var request = new sn_ws.RESTMessageV2();
request.setEndpoint(gs.getProperty('x_ai_backend_url'));
request.setHttpMethod('POST');
request.setRequestHeader('X-API-Key', gs.getProperty('x_ai_backend_api_key'));
```

#### Option 2: OAuth 2.0

```javascript
// Create OAuth Provider
// System OAuth > Application Registry
// Name: AI Backend OAuth
// Client ID: your_client_id
// Client Secret: your_client_secret
// Token URL: https://YOUR_BACKEND_URL/oauth/token
```

## Usage Examples

### Business Rule: Auto-Enrich Incidents

```javascript
// File: business_rules/incident_comment_to_pubsub.js

(function executeRule(current, previous /*null when async*/) {
    try {
        // Only process when comments field changes
        if (!current.comments.changes()) {
            return;
        }

        var aiUtils = new AiIntegrationUtils();

        // Get AI suggestion for the incident
        var suggestion = aiUtils.getIncidentSuggestion({
            short_description: current.short_description.toString(),
            description: current.description.toString(),
            comments: current.comments.toString()
        });

        // Update work notes with AI suggestion
        if (suggestion && suggestion.recommendation) {
            current.work_notes = 'AI Suggestion: ' + suggestion.recommendation;
            current.update();
        }

        // Publish event to Pub/Sub for further processing
        aiUtils.publishToPubSub({
            event_type: 'incident.comment.added',
            incident_id: current.sys_id.toString(),
            comment: current.comments.toString(),
            timestamp: new GlideDateTime().getValue()
        });

    } catch (e) {
        gs.error('Error in AI incident enrichment: ' + e.message);
    }
})(current, previous);
```

### Script Include: AI Integration Utilities

```javascript
// File: script_includes/AiIntegrationUtils.js

var AiIntegrationUtils = Class.create();
AiIntegrationUtils.prototype = {
    initialize: function() {
        this.backendUrl = gs.getProperty('x_ai_backend_url');
        this.apiKey = gs.getProperty('x_ai_backend_api_key');
        this.timeout = parseInt(gs.getProperty('x_ai_timeout_ms', '30000'));
    },

    /**
     * Get AI suggestion for an incident
     * @param {Object} incidentData - Incident details
     * @returns {Object} AI recommendation
     */
    getIncidentSuggestion: function(incidentData) {
        try {
            var request = new sn_ws.RESTMessageV2();
            request.setEndpoint(this.backendUrl + '/api/v1/chat');
            request.setHttpMethod('POST');
            request.setRequestHeader('Content-Type', 'application/json');
            request.setRequestHeader('X-API-Key', this.apiKey);
            request.setHttpTimeout(this.timeout);

            var payload = {
                message: this._buildPrompt(incidentData),
                session_id: this._getSessionId(),
                model: 'claude-3-sonnet',
                stream: false
            };

            request.setRequestBody(JSON.stringify(payload));

            var response = request.execute();
            var statusCode = response.getStatusCode();

            if (statusCode === 200) {
                var responseBody = JSON.parse(response.getBody());
                return {
                    recommendation: responseBody.response,
                    tokens_used: responseBody.tokens_used,
                    latency_ms: responseBody.latency_ms
                };
            } else {
                gs.error('AI API returned status: ' + statusCode);
                return null;
            }

        } catch (e) {
            gs.error('Error calling AI API: ' + e.message);
            return null;
        }
    },

    /**
     * Publish event to GCP Pub/Sub
     * @param {Object} eventData - Event payload
     * @returns {Boolean} Success status
     */
    publishToPubSub: function(eventData) {
        try {
            var request = new sn_ws.RESTMessageV2();
            request.setEndpoint(this.backendUrl + '/api/v1/pubsub/publish');
            request.setHttpMethod('POST');
            request.setRequestHeader('Content-Type', 'application/json');
            request.setRequestHeader('X-API-Key', this.apiKey);

            var payload = {
                topic: gs.getProperty('x_ai_pubsub_topic'),
                data: eventData
            };

            request.setRequestBody(JSON.stringify(payload));

            var response = request.execute();
            return response.getStatusCode() === 200;

        } catch (e) {
            gs.error('Error publishing to Pub/Sub: ' + e.message);
            return false;
        }
    },

    /**
     * Build prompt for AI from incident data
     * @private
     */
    _buildPrompt: function(incidentData) {
        var prompt = 'Analyze this ServiceNow incident and provide recommendations:\n\n';
        prompt += 'Title: ' + incidentData.short_description + '\n';
        prompt += 'Description: ' + incidentData.description + '\n';
        if (incidentData.comments) {
            prompt += 'Comments: ' + incidentData.comments + '\n';
        }
        prompt += '\nProvide: 1) Root cause analysis 2) Resolution steps 3) Similar incidents';
        return prompt;
    },

    /**
     * Get or create session ID for user
     * @private
     */
    _getSessionId: function() {
        var userId = gs.getUserID();
        return 'sn_' + userId + '_' + new GlideDateTime().getValue();
    },

    type: 'AiIntegrationUtils'
};
```

### Scripted REST API: Incidents Endpoint

```javascript
// File: scripted_rest/incidents.js
// Resource Path: /incidents
// HTTP Method: POST

(function process(/*RESTAPIRequest*/ request, /*RESTAPIResponse*/ response) {

    try {
        var requestBody = request.body.data;

        // Validate input
        if (!requestBody.short_description) {
            response.setStatus(400);
            response.setBody({error: 'short_description is required'});
            return;
        }

        // Create incident
        var incidentGr = new GlideRecord('incident');
        incidentGr.initialize();
        incidentGr.short_description = requestBody.short_description;
        incidentGr.description = requestBody.description || '';
        incidentGr.caller_id = requestBody.caller_id || gs.getUserID();
        incidentGr.category = requestBody.category || 'inquiry';
        incidentGr.urgency = requestBody.urgency || '3';
        incidentGr.impact = requestBody.impact || '3';

        var incidentId = incidentGr.insert();

        if (incidentId) {
            // Get AI suggestion asynchronously
            var aiUtils = new AiIntegrationUtils();
            var suggestion = aiUtils.getIncidentSuggestion({
                short_description: incidentGr.short_description.toString(),
                description: incidentGr.description.toString()
            });

            // Update incident with AI suggestion
            if (suggestion) {
                incidentGr.work_notes = 'AI Analysis: ' + suggestion.recommendation;
                incidentGr.update();
            }

            response.setStatus(201);
            response.setBody({
                incident_id: incidentId,
                number: incidentGr.number.toString(),
                state: incidentGr.state.toString(),
                ai_suggestion: suggestion
            });
        } else {
            response.setStatus(500);
            response.setBody({error: 'Failed to create incident'});
        }

    } catch (e) {
        gs.error('Error in incidents API: ' + e.message);
        response.setStatus(500);
        response.setBody({error: e.message});
    }

})(request, response);
```

## Testing

### Test Business Rule

```javascript
// Test script: Navigate to Scripts - Background
var incident = new GlideRecord('incident');
incident.get('INC0010001');  // Replace with actual incident
incident.comments = 'Test comment for AI processing';
incident.update();

// Check work_notes for AI suggestion
gs.info('AI Suggestion: ' + incident.work_notes);
```

### Test Script Include

```javascript
// Test script: Navigate to Scripts - Background
var aiUtils = new AiIntegrationUtils();
var result = aiUtils.getIncidentSuggestion({
    short_description: 'Email not working',
    description: 'User cannot send or receive emails',
    comments: 'Tried restarting Outlook'
});

gs.info('AI Recommendation: ' + JSON.stringify(result));
```

### Test REST API

```bash
# Use REST API Explorer or curl
curl -X POST https://YOUR_INSTANCE.service-now.com/api/ai/v1/incidents \
  -H "Content-Type: application/json" \
  -H "Authorization: Basic BASE64_CREDENTIALS" \
  -d '{
    "short_description": "Laptop screen flickering",
    "description": "Screen flickers when opening applications",
    "urgency": "2"
  }'
```

## Monitoring

### Logging

```javascript
// Enable debug logging
gs.setProperty('x_ai_debug_mode', 'true');

// View logs
// Navigate to: System Logs > All
// Filter: Source = AI Integration
```

### Metrics

Track AI integration metrics:
- Total AI suggestions generated
- Average response time
- Success/failure rate
- Token usage per incident

## Troubleshooting

### Common Issues

#### Issue: REST API timeouts

```javascript
// Increase timeout in system property
gs.setProperty('x_ai_timeout_ms', '60000');  // 60 seconds

// Or in Script Include
this.timeout = 60000;
```

#### Issue: Authentication failures

```bash
# Verify API key
gs.info('API Key configured: ' + (gs.getProperty('x_ai_backend_api_key') ? 'Yes' : 'No'));

# Test connection
var request = new sn_ws.RESTMessageV2();
request.setEndpoint(gs.getProperty('x_ai_backend_url') + '/health');
request.setHttpMethod('GET');
var response = request.execute();
gs.info('Backend health: ' + response.getStatusCode());
```

#### Issue: Pub/Sub publishing fails

```javascript
// Check Pub/Sub topic configuration
gs.info('Pub/Sub topic: ' + gs.getProperty('x_ai_pubsub_topic'));

// Verify backend Pub/Sub endpoint
// Ensure IAM permissions are configured for ServiceNow service account
```

## Security Best Practices

- ✅ Store API keys in encrypted system properties (password2)
- ✅ Use HTTPS for all external communications
- ✅ Validate all input data
- ✅ Implement rate limiting for AI requests
- ✅ Log all AI interactions for audit
- ✅ Use ServiceNow ACLs to restrict access
- ✅ Sanitize AI responses before displaying

## Performance Optimization

- Use asynchronous processing for AI requests
- Cache frequent AI suggestions
- Implement request queuing for high volume
- Monitor API rate limits
- Use batch processing where possible

## Documentation

- **Backend API**: See [../backend/README.md](../backend/README.md)
- **Architecture**: See [../docs/SERVICENOW_INTEGRATION.md](../docs/SERVICENOW_INTEGRATION.md)
- **Main README**: See [../README.md](../README.md)

## Support

- **Issues**: https://github.com/erayguner/servicenow-ai/issues
- **ServiceNow Community**: https://www.servicenow.com/community/
