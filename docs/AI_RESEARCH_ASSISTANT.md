# AI Research Assistant

## Overview

The AI Research Assistant is an internal-only conversational AI system built on Google Cloud Platform. It provides a Perplexity-like chat interface with source-oriented answers, accessible only to internal users through Identity-Aware Proxy (IAP).

## Architecture

### High-Level Design

```
┌─────────────────────────────────────────────────────────────────┐
│                        Google Cloud IAP                          │
│                  (Identity & Access Control)                     │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│            Internal HTTP(S) Load Balancer                        │
└──────────┬──────────────────────────────────┬───────────────────┘
           │                                   │
           ▼                                   ▼
┌─────────────────────┐              ┌─────────────────────┐
│  Frontend Service   │              │  Backend Service    │
│   (Next.js/React)   │─────────────▶│  (Node/TypeScript)  │
│   Cloud Run         │              │   Cloud Run         │
└─────────────────────┘              └──────────┬──────────┘
                                                 │
                    ┌────────────────────────────┼────────────────┐
                    │                            │                │
                    ▼                            ▼                ▼
           ┌─────────────────┐        ┌──────────────┐   ┌──────────────┐
           │   Firestore     │        │ Secret Mgr   │   │ Cloud SQL    │
           │   (AgentDB)     │        │ (API Keys)   │   │ (Optional)   │
           └─────────────────┘        └──────────────┘   └──────────────┘
```

### Components

#### 1. **Frontend** (Next.js/React)
- **Location**: `/frontend`
- **Deployment**: Cloud Run (internal ingress only)
- **Features**:
  - Chat-first interface similar to Perplexity
  - Conversation history management
  - Streaming responses support
  - Source citations display
  - Research mode for deep analysis

#### 2. **Backend API** (Node/TypeScript)
- **Location**: `/backend`
- **Deployment**: Cloud Run (VPC-connected, no public IP)
- **Endpoints**:
  - `POST /api/chat` - Send messages and get AI responses
  - `POST /api/chat/research` - Start research-swarm flows
  - `GET /api/session/conversations` - List user conversations
  - `GET /api/session/conversations/:id` - Get conversation with messages
  - `POST /api/session/conversations` - Create new conversation
  - `GET /api/admin/*` - Admin endpoints (requires admin group)
- **Features**:
  - Claude AI integration via Anthropic SDK
  - AgentDB for conversation persistence (Firestore)
  - Secret Manager integration for API keys
  - Cloud Logging integration
  - Rate limiting
  - IAP authentication

#### 3. **Infrastructure** (Terraform)
- **Location**: `/terraform/modules/cloud_run`, `/terraform/modules/iap`
- **Resources**:
  - Cloud Run services (backend & frontend)
  - IAP configuration
  - Serverless VPC Access Connector
  - Cloud NAT for egress control
  - Internal Load Balancer
  - Service accounts with least-privilege IAM

## Zero-Trust Security Model

### Network Security
- ✅ No public endpoints - all services behind Internal Load Balancer
- ✅ VPC-connected Cloud Run with Serverless VPC Access
- ✅ Cloud NAT for controlled egress (only to model APIs)
- ✅ Default-deny firewall rules

### Identity & Access
- ✅ IAP authentication (Cloud Identity/Google Workspace)
- ✅ Group-based access control:
  - `ai-assist-users@org` - Standard users
  - `ai-assist-admins@org` - Administrators
- ✅ Service accounts with minimal permissions
- ✅ No service account keys (Workload Identity)

### Data Protection
- ✅ All secrets in Secret Manager
- ✅ Customer-managed encryption keys (CMEK) via KMS
- ✅ Private Cloud SQL/Firestore (no public IP)
- ✅ Audit logging enabled

### Observability
- ✅ Cloud Logging for all services
- ✅ Cloud Monitoring dashboards
- ✅ Error Reporting integration
- ✅ Request logging (no sensitive payloads)

## Setup Instructions

### Prerequisites

1. **GCP Project** with billing enabled
2. **APIs enabled**:
   ```bash
   gcloud services enable \
     run.googleapis.com \
     vpcaccess.googleapis.com \
     compute.googleapis.com \
     iap.googleapis.com \
     secretmanager.googleapis.com \
     firestore.googleapis.com
   ```
3. **Required tools**:
   - Terraform >= 1.11.0
   - Node.js >= 20.0.0
   - Docker
   - gcloud CLI

### Step 1: Configure Secrets

Create the required secrets in Secret Manager:

```bash
# Anthropic API Key
echo -n "your-anthropic-api-key" | \
  gcloud secrets create anthropic-api-key --data-file=- \
  --project=YOUR_PROJECT_ID

# OpenAI API Key (optional)
echo -n "your-openai-api-key" | \
  gcloud secrets create openai-api-key --data-file=- \
  --project=YOUR_PROJECT_ID
```

### Step 2: Deploy Infrastructure

```bash
cd terraform/environments/dev

# Create terraform.tfvars
cat > terraform.tfvars <<EOF
project_id      = "your-project-id"
region          = "us-central1"
billing_account = "XXXXXX-XXXXXX-XXXXXX"
gke_master_cidr = "172.16.0.0/28"
EOF

# Initialize and apply
terraform init
terraform plan
terraform apply
```

This creates:
- VPC with Serverless VPC Access Connector
- Cloud NAT for egress
- Cloud Run services (backend & frontend)
- IAP configuration
- Firestore database
- Required service accounts and IAM bindings

### Step 3: Build and Deploy Applications

#### Backend

```bash
cd backend

# Build Docker image
docker build -t gcr.io/YOUR_PROJECT_ID/ai-research-backend:latest .

# Push to GCR
docker push gcr.io/YOUR_PROJECT_ID/ai-research-backend:latest

# Deploy to Cloud Run (handled by Terraform)
```

#### Frontend

```bash
cd frontend

# Build Docker image
docker build -t gcr.io/YOUR_PROJECT_ID/ai-research-frontend:latest .

# Push to GCR
docker push gcr.io/YOUR_PROJECT_ID/ai-research-frontend:latest

# Deploy to Cloud Run (handled by Terraform)
```

### Step 4: Configure IAP Access

```bash
# Add users to IAP access list
gcloud iap web add-iam-policy-binding \
  --resource-type=backend-services \
  --service=ai-research-backend-backend \
  --member=user:user@example.com \
  --role=roles/iap.httpsResourceAccessor

# Add admin users
gcloud iap web add-iam-policy-binding \
  --resource-type=backend-services \
  --service=ai-research-backend-backend \
  --member=group:ai-assist-admins@org \
  --role=roles/iap.httpsResourceAccessor
```

### Step 5: Access the Application

1. Get the Load Balancer IP:
   ```bash
   terraform output load_balancer_ip
   ```

2. Configure internal DNS or use IP directly
3. Access via browser (requires authentication through IAP)

## Usage

### Chat Interface

1. **Start Conversation**: Click "New Conversation" in sidebar
2. **Send Message**: Type message and press Send
3. **View History**: Click on previous conversations in sidebar
4. **Research Mode**: Use `/api/chat/research` endpoint for deep research

### API Examples

#### Send Chat Message

```bash
curl -X POST https://YOUR_LOAD_BALANCER_IP/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Explain quantum computing",
    "model": "claude-3-5-sonnet-20241022"
  }'
```

#### Start Research

```bash
curl -X POST https://YOUR_LOAD_BALANCER_IP/api/chat/research \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Latest developments in quantum computing",
    "depth": "deep"
  }'
```

## Integration with claude-flow, agentdb, research-swarm

### AgentDB

The system uses Firestore as the backend for AgentDB, providing:
- Conversation history storage
- Message persistence
- Document storage for RAG
- Vector search capabilities (via Firestore indexes)

**Usage in code**:
```typescript
import { agentdb } from '@/services/agentdb'

// Create conversation
const conversation = await agentdb.createConversation(userId, title)

// Add message
await agentdb.addMessage({
  conversationId,
  role: 'user',
  content: message,
})

// Store document for RAG
await agentdb.storeDocument({
  title: 'Document Title',
  content: 'Document content...',
  embedding: vectorEmbedding,
})
```

### Research-Swarm Integration

To integrate research-swarm for multi-agent research flows:

1. **Install research-swarm**:
   ```bash
   cd backend
   npm install research-swarm
   ```

2. **Update chat service** (`backend/src/services/claude.ts`):
   ```typescript
   import { ResearchSwarm } from 'research-swarm'

   export async function conductResearch(query: string, depth: string) {
     const swarm = new ResearchSwarm({
       apiKey: await getAnthropicApiKey(),
       model: 'claude-3-5-sonnet-20241022',
     })

     const result = await swarm.research(query, {
       depth,
       maxAgents: 5,
       citeSources: true,
     })

     return result
   }
   ```

### Claude-Flow Integration

To integrate claude-flow for complex orchestration:

1. **Install claude-flow**:
   ```bash
   cd backend
   npx claude-flow@alpha init
   ```

2. **Create flow definitions** in `backend/src/flows/`:
   ```typescript
   // research-flow.ts
   export const researchFlow = {
     name: 'deep-research',
     steps: [
       { name: 'gather', agent: 'researcher' },
       { name: 'analyze', agent: 'analyst' },
       { name: 'synthesize', agent: 'writer' },
     ],
   }
   ```

## Monitoring & Operations

### View Logs

```bash
# Backend logs
gcloud logging read "resource.type=cloud_run_revision \
  AND resource.labels.service_name=ai-research-backend" \
  --limit=50 --format=json

# Frontend logs
gcloud logging read "resource.type=cloud_run_revision \
  AND resource.labels.service_name=ai-research-frontend" \
  --limit=50 --format=json
```

### Monitor Performance

```bash
# View Cloud Run metrics
gcloud monitoring dashboards list

# Get service details
gcloud run services describe ai-research-backend \
  --region=us-central1 --format=json
```

### Update Services

```bash
# Update backend
docker build -t gcr.io/YOUR_PROJECT_ID/ai-research-backend:v2 backend/
docker push gcr.io/YOUR_PROJECT_ID/ai-research-backend:v2
terraform apply

# Update frontend
docker build -t gcr.io/YOUR_PROJECT_ID/ai-research-frontend:v2 frontend/
docker push gcr.io/YOUR_PROJECT_ID/ai-research-frontend:v2
terraform apply
```

## Troubleshooting

### IAP Authentication Issues

```bash
# Verify IAP is enabled
gcloud iap web get-iam-policy \
  --resource-type=backend-services \
  --service=ai-research-backend-backend

# Check user permissions
gcloud projects get-iam-policy YOUR_PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:user@example.com"
```

### Cloud Run Connection Issues

```bash
# Check VPC connector status
gcloud compute networks vpc-access connectors describe \
  dev-cloud-run-connector --region=us-central1

# Test backend health
gcloud run services proxy ai-research-backend \
  --region=us-central1
curl http://localhost:8080/health
```

### Firestore Access Issues

```bash
# Verify service account permissions
gcloud projects get-iam-policy YOUR_PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:ai-research-backend-sa@*"
```

## Cost Optimization

### Development
- Cloud Run: Pay-per-use (scale to zero)
- Firestore: Free tier covers development usage
- VPC Connector: $0.12/hour (~$87/month)
- Cloud NAT: ~$45/month

### Production
- Enable Cloud Run minimum instances for better latency
- Use Cloud CDN for frontend static assets
- Implement request caching
- Monitor and set budget alerts

## Security Best Practices

1. **Regular Security Audits**
   ```bash
   # Run Checkov on Terraform
   checkov -d terraform/

   # Scan container images
   gcloud container images scan gcr.io/PROJECT/IMAGE:TAG
   ```

2. **Rotate Secrets Regularly**
   ```bash
   # Add new secret version
   echo -n "new-api-key" | \
     gcloud secrets versions add anthropic-api-key --data-file=-
   ```

3. **Monitor Audit Logs**
   ```bash
   gcloud logging read "protoPayload.serviceName=iap.googleapis.com" \
     --limit=100 --format=json
   ```

4. **Review IAM Permissions**
   ```bash
   # List service account permissions
   gcloud projects get-iam-policy YOUR_PROJECT_ID \
     --flatten="bindings[].members" \
     --format="table(bindings.role)"
   ```

## Future Enhancements

- [ ] Implement streaming responses in frontend
- [ ] Add vector search with Vertex AI Matching Engine
- [ ] Integrate research-swarm for multi-agent research
- [ ] Add document upload for RAG
- [ ] Implement conversation sharing
- [ ] Add admin analytics dashboard
- [ ] Multi-region deployment for HA
- [ ] Cost tracking per user/conversation

## Support

For issues or questions:
1. Check [troubleshooting](#troubleshooting) section
2. Review Cloud Logging for errors
3. Contact platform team

## References

- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Identity-Aware Proxy](https://cloud.google.com/iap/docs)
- [Anthropic Claude API](https://docs.anthropic.com)
- [Firestore Documentation](https://cloud.google.com/firestore/docs)
