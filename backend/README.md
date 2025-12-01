# Backend Service

Node.js/TypeScript backend API for the ServiceNow AI Agent system.

## Overview

RESTful API backend built with:
- **Runtime**: Node.js 20+
- **Language**: TypeScript
- **Observability**: OpenTelemetry (see [src/observability/README.md](src/observability/README.md))
- **Authentication**: Service account-based auth
- **Database**: PostgreSQL (CloudSQL), Firestore
- **LLM Integration**: Claude API, Vertex AI

## Architecture

```
backend/
├── src/
│   ├── index.ts                 # Application entry point
│   ├── instrumentation.ts       # OpenTelemetry setup
│   ├── config.ts                # Configuration management
│   │
│   ├── routes/                  # API route handlers
│   │   ├── health.ts            # Health check endpoint
│   │   ├── chat.ts              # Chat/conversation API
│   │   ├── session.ts           # Session management
│   │   └── admin.ts             # Admin endpoints
│   │
│   ├── services/                # Business logic services
│   │   ├── claude.ts            # Claude API integration
│   │   ├── agentdb.ts           # Database operations
│   │   ├── secretManager.ts     # GCP Secret Manager
│   │   └── logger.ts            # Structured logging
│   │
│   ├── middleware/              # Express middleware
│   │   ├── auth.ts              # Authentication
│   │   ├── errorHandler.ts     # Error handling
│   │   └── rateLimiter.ts      # Rate limiting
│   │
│   ├── observability/           # Telemetry and monitoring
│   │   ├── llm-telemetry.ts    # LLM-specific metrics
│   │   └── README.md            # Observability documentation
│   │
│   └── test/                    # Test setup and utilities
│       └── setup.ts             # Jest configuration
│
├── tsconfig.json                # TypeScript configuration
├── package.json                 # Node.js dependencies
├── jest.config.js               # Test configuration
└── .eslintrc.js                 # ESLint rules
```

## Features

### Core Capabilities
- ✅ RESTful API for chat and session management
- ✅ Claude API integration (Anthropic)
- ✅ Vertex AI integration (Gemini models)
- ✅ Hybrid LLM routing (self-hosted + cloud)
- ✅ PostgreSQL persistence (conversation history)
- ✅ Firestore real-time sync (sessions)
- ✅ GCP Secret Manager integration
- ✅ Workload Identity authentication (zero service account keys)

### Observability
- ✅ OpenTelemetry instrumentation
- ✅ Distributed tracing
- ✅ Custom LLM metrics (latency, tokens, cost)
- ✅ Structured JSON logging
- ✅ Prometheus metrics export
- ✅ Health check endpoints

### Security
- ✅ Rate limiting
- ✅ Request validation
- ✅ Error sanitization
- ✅ CORS configuration
- ✅ Helmet.js security headers

## Quick Start

### Prerequisites

```bash
# Node.js 20+
node --version

# Package manager
npm --version  # or pnpm, yarn
```

### Installation

```bash
cd backend

# Install dependencies
npm install

# Configure environment
cp .env.example .env
# Edit .env with your configuration
```

### Environment Variables

```bash
# Application
NODE_ENV=development
PORT=8080
LOG_LEVEL=info

# Database (CloudSQL)
DB_HOST=localhost
DB_PORT=5432
DB_NAME=servicenow_dev
DB_USER=servicenow_user
DB_PASSWORD=<from-secret-manager>

# Firestore
FIRESTORE_PROJECT_ID=your-project-id
FIRESTORE_DATABASE=dev-ai-agent-firestore

# LLM Providers
CLAUDE_API_KEY=<from-secret-manager>
VERTEX_AI_PROJECT=your-project-id
VERTEX_AI_LOCATION=europe-west2

# Observability
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
OTEL_SERVICE_NAME=backend-api
OTEL_SERVICE_VERSION=1.0.0

# ServiceNow
SERVICENOW_INSTANCE_URL=https://dev123456.service-now.com
SERVICENOW_USERNAME=<from-secret-manager>
SERVICENOW_PASSWORD=<from-secret-manager>
```

### Development

```bash
# Run in development mode (with hot reload)
npm run dev

# Build TypeScript
npm run build

# Run production build
npm start

# Run tests
npm test

# Run tests with coverage
npm run test:coverage

# Lint code
npm run lint

# Format code
npm run format
```

### Docker

```bash
# Build image
docker build -t backend-api .

# Run container
docker run -p 8080:8080 --env-file .env backend-api
```

## API Endpoints

### Health Check

```bash
GET /health
```

**Response:**
```json
{
  "status": "healthy",
  "version": "1.0.0",
  "timestamp": "2024-12-01T12:00:00Z",
  "services": {
    "database": "connected",
    "firestore": "connected",
    "claude": "available"
  }
}
```

### Chat API

#### Send Message

```bash
POST /api/v1/chat
Content-Type: application/json

{
  "session_id": "sess_abc123",
  "message": "How do I create an incident in ServiceNow?",
  "model": "claude-3-sonnet",
  "stream": false
}
```

**Response:**
```json
{
  "message_id": "msg_xyz789",
  "session_id": "sess_abc123",
  "response": "To create an incident in ServiceNow...",
  "model": "claude-3-sonnet",
  "tokens_used": {
    "input": 50,
    "output": 150
  },
  "latency_ms": 1250
}
```

#### Stream Message

```bash
POST /api/v1/chat/stream
Content-Type: application/json

{
  "session_id": "sess_abc123",
  "message": "Explain the ITIL framework",
  "model": "claude-3-haiku",
  "stream": true
}
```

**Response:** Server-Sent Events (SSE)

### Session Management

#### Create Session

```bash
POST /api/v1/sessions
Content-Type: application/json

{
  "user_id": "user_123",
  "metadata": {
    "source": "web",
    "department": "IT"
  }
}
```

#### Get Session

```bash
GET /api/v1/sessions/:session_id
```

#### List Sessions

```bash
GET /api/v1/sessions?user_id=user_123&limit=10
```

### Admin Endpoints

```bash
GET /api/admin/metrics         # Prometheus metrics
GET /api/admin/stats           # System statistics
POST /api/admin/cache/clear    # Clear cache
```

## Database Schema

### PostgreSQL (CloudSQL)

**conversations** table:
```sql
CREATE TABLE conversations (
  id UUID PRIMARY KEY,
  session_id VARCHAR(255) NOT NULL,
  user_id VARCHAR(255) NOT NULL,
  message TEXT NOT NULL,
  response TEXT NOT NULL,
  model VARCHAR(100),
  tokens_input INTEGER,
  tokens_output INTEGER,
  latency_ms INTEGER,
  created_at TIMESTAMP DEFAULT NOW(),
  INDEX idx_session (session_id),
  INDEX idx_user (user_id),
  INDEX idx_created (created_at)
);
```

### Firestore

**sessions** collection:
```json
{
  "session_id": "sess_abc123",
  "user_id": "user_123",
  "status": "active",
  "created_at": "2024-12-01T10:00:00Z",
  "updated_at": "2024-12-01T12:00:00Z",
  "metadata": {
    "source": "web",
    "department": "IT"
  },
  "message_count": 5,
  "total_tokens": 1500
}
```

## Testing

```bash
# Unit tests
npm run test:unit

# Integration tests
npm run test:integration

# E2E tests
npm run test:e2e

# Coverage report
npm run test:coverage
```

### Test Structure

```
src/test/
├── setup.ts              # Jest configuration
├── unit/                 # Unit tests
│   ├── services/
│   ├── routes/
│   └── middleware/
├── integration/          # Integration tests
│   ├── database.test.ts
│   └── api.test.ts
└── e2e/                  # End-to-end tests
    └── chat.test.ts
```

## Deployment

### Kubernetes

```bash
# Apply deployment
kubectl apply -f ../k8s/deployments/backend-deployment.yaml

# Check status
kubectl get deployment backend -n production
kubectl get pods -l app=backend -n production

# View logs
kubectl logs -f deployment/backend -n production

# Port forward for local testing
kubectl port-forward deployment/backend 8080:8080 -n production
```

### Environment-Specific Configs

- **Development**: Local PostgreSQL, Firestore emulator
- **Staging**: CloudSQL (zonal), Firestore (regional)
- **Production**: CloudSQL (regional HA), Firestore (multi-region)

## Monitoring

### Metrics

Backend exposes Prometheus metrics at `/api/admin/metrics`:

- `http_requests_total` - Total HTTP requests
- `http_request_duration_seconds` - Request latency histogram
- `llm_requests_total` - LLM API calls
- `llm_tokens_total` - Token usage by model
- `llm_latency_seconds` - LLM response time
- `llm_cost_total` - Estimated cost by model
- `db_connections_active` - Active database connections
- `db_query_duration_seconds` - Database query latency

### Logging

Structured JSON logs are sent to Cloud Logging:

```json
{
  "timestamp": "2024-12-01T12:00:00Z",
  "severity": "INFO",
  "message": "Chat request processed",
  "trace": "projects/PROJECT_ID/traces/TRACE_ID",
  "session_id": "sess_abc123",
  "model": "claude-3-sonnet",
  "latency_ms": 1250,
  "tokens_used": 200
}
```

### Tracing

Distributed traces are exported to Cloud Trace via OpenTelemetry. See [src/observability/README.md](src/observability/README.md).

## Troubleshooting

### Common Issues

#### Cannot connect to database

```bash
# Check Cloud SQL proxy
ps aux | grep cloud_sql_proxy

# Start proxy
cloud_sql_proxy -instances=PROJECT:REGION:INSTANCE=tcp:5432 &

# Test connection
psql "host=localhost port=5432 dbname=servicenow_dev user=servicenow_user"
```

#### Workload Identity errors

```bash
# Verify service account binding
gcloud iam service-accounts get-iam-policy \
  dev-ai-agent-backend-sa@PROJECT_ID.iam.gserviceaccount.com

# Check Kubernetes service account
kubectl get serviceaccount backend-sa -n production -o yaml
```

#### High memory usage

```bash
# Check Node.js memory
kubectl top pods -n production -l app=backend

# Increase memory limit in deployment
kubectl edit deployment backend -n production
# Update: resources.limits.memory: "1Gi" -> "2Gi"
```

## Performance Optimization

- **Connection Pooling**: PostgreSQL connection pool (min: 2, max: 10)
- **Caching**: Redis for session caching
- **Compression**: gzip compression for responses
- **Rate Limiting**: 100 requests/minute per user
- **Async Processing**: Pub/Sub for long-running tasks

## Security Best Practices

- ✅ No hardcoded secrets (use Secret Manager)
- ✅ Workload Identity (zero service account keys)
- ✅ Input validation (joi/zod)
- ✅ SQL injection prevention (parameterized queries)
- ✅ XSS protection (helmet.js)
- ✅ CORS configuration
- ✅ Rate limiting
- ✅ Request size limits

## Contributing

See [../CONTRIBUTING.md](../CONTRIBUTING.md) for development guidelines.

## License

See [../LICENSE](../LICENSE).

## Support

- **Documentation**: See [../README.md](../README.md)
- **Issues**: https://github.com/erayguner/servicenow-ai/issues
- **Observability**: [src/observability/README.md](src/observability/README.md)
