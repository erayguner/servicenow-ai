# 🤖 Using Foundational Models with Kubernetes LLM Infrastructure

**Status**: ✅ Production-Ready **Last Updated**: 2025-11-04 **Integration**:
Google Vertex AI, AWS Bedrock, OpenAI, Anthropic

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Supported Providers](#supported-providers)
3. [Quick Start](#quick-start)
4. [Provider-Specific Integration](#provider-specific-integration)
5. [Unified LLM Router](#unified-llm-router)
6. [Usage Examples](#usage-examples)
7. [Cost Optimization](#cost-optimization)
8. [Best Practices](#best-practices)

---

## Overview

This guide shows you how to integrate **foundational models** from major AI
providers with your Kubernetes LLM infrastructure. The implementation provides:

✅ **Multi-Provider Support**: Google, AWS, OpenAI, Anthropic, Cohere, Mistral
✅ **Unified API**: OpenAI-compatible endpoints for all providers ✅
**Intelligent Routing**: Automatic model selection based on requirements ✅
**Fallback Chains**: Automatic failover if primary provider fails ✅ **Cost
Optimization**: Route to cheapest model that meets requirements ✅ **Zero
Service Account Keys**: Uses Workload Identity for GCP

---

## Supported Providers

### 1️⃣ Google Vertex AI (Recommended for GCP) ⭐

**Models**:

- **Gemini 1.5 Pro** - 1M token context, best quality
- **Gemini 1.5 Flash** - Fast, cost-effective
- **PaLM 2** - Text, chat, code generation

**Benefits**:

- ✅ No API keys needed (Workload Identity)
- ✅ Lowest latency (same region)
- ✅ 1M token context window (Gemini)
- ✅ Enterprise support

**Pricing** (per 1M tokens):

- Gemini Flash: $0.10 input / $0.30 output
- Gemini Pro: $3.50 input / $10.50 output

### 2️⃣ AWS Bedrock

**Models**:

- **Claude 3 Opus** - Highest intelligence
- **Claude 3 Sonnet** - Balanced performance/cost
- **Claude 3 Haiku** - Fastest, cheapest
- **Llama 3 70B** - Open model
- **Amazon Titan** - AWS native

**Benefits**:

- ✅ Multiple model providers
- ✅ Enterprise contracts
- ✅ Regional availability

### 3️⃣ OpenAI API

**Models**:

- **GPT-4 Turbo** - 128K context
- **GPT-4** - Most capable
- **GPT-3.5 Turbo** - Fast, cost-effective

**Benefits**:

- ✅ Industry standard
- ✅ Best function calling
- ✅ JSON mode

### 4️⃣ Anthropic API

**Models**:

- **Claude 3 Opus** - 200K context
- **Claude 3 Sonnet** - Balanced
- **Claude 3 Haiku** - Fast

**Benefits**:

- ✅ Long context (200K)
- ✅ Strong reasoning
- ✅ Ethical AI focus

---

## Quick Start

### Prerequisites

1. **Kubernetes cluster** with LLM infrastructure deployed
2. **Workload Identity** configured (for GCP)
3. **API credentials** for external providers (if using)

### 1. Deploy Foundational Models Integration

```bash
# Deploy all provider configurations
kubectl apply -f k8s/llm-serving/foundational-models.yaml

# Verify deployment
kubectl get pods -n production | grep -E "(vertex-ai|llm-router)"
```

### 2. Configure Credentials

#### Google Vertex AI (No keys needed!)

```bash
# Already configured via Workload Identity
kubectl get serviceaccount llm-gateway-sa -n production \
  -o jsonpath='{.metadata.annotations.iam\.gke\.io/gcp-service-account}'
```

#### OpenAI API

```bash
kubectl create secret generic openai-api-key \
  --from-literal=api-key=sk-YOUR_OPENAI_API_KEY \
  -n production
```

#### Anthropic API

```bash
kubectl create secret generic anthropic-api-key \
  --from-literal=api-key=sk-ant-YOUR_ANTHROPIC_API_KEY \
  -n production
```

#### AWS Bedrock (Use IRSA in production)

```bash
kubectl create secret generic aws-credentials \
  --from-literal=aws-access-key-id=YOUR_KEY \
  --from-literal=aws-secret-access-key=YOUR_SECRET \
  -n production
```

### 3. Test the Integration

```bash
# Get router service endpoint
ROUTER_URL=$(kubectl get svc llm-router -n production \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test with Gemini (Vertex AI)
curl -X POST http://${ROUTER_URL}/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemini-1.5-pro-001",
    "messages": [
      {"role": "user", "content": "Explain quantum computing in 3 sentences"}
    ],
    "routing_strategy": "quality"
  }'
```

---

## Provider-Specific Integration

### Google Vertex AI Integration

**Deployment**: `vertex-ai-gateway`

**Available Models**:

```yaml
Gemini Models:
  - gemini-1.5-pro-001 # 1M context, best quality
  - gemini-1.5-flash-001 # Fast, cost-effective
  - gemini-ultra # Coming soon

PaLM Models:
  - text-bison@002 # Text generation
  - chat-bison@002 # Chat
  - code-bison@002 # Code generation
```

**Example Usage**:

```bash
# Using Gemini Pro
curl -X POST http://vertex-ai-gateway/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemini-1.5-pro-001",
    "prompt": "Write a Python function to calculate fibonacci numbers",
    "max_tokens": 500,
    "temperature": 0.7
  }'
```

**Benefits**:

- ✅ **Zero API keys**: Uses Workload Identity
- ✅ **1M token context**: Perfect for long documents
- ✅ **Low latency**: Same region as your infrastructure
- ✅ **Cost-effective**: Gemini Flash is very cheap

**Configuration**:

```yaml
env:
  - name: PROJECT_ID
    valueFrom:
      configMapKeyRef:
        name: vertex-ai-config
        key: project-id
  - name: LOCATION
    value: 'europe-west4'
```

### AWS Bedrock Integration

**Models Available**:

```yaml
Anthropic Claude:
  - anthropic.claude-3-opus-20240229-v1:0
  - anthropic.claude-3-sonnet-20240229-v1:0
  - anthropic.claude-3-haiku-20240307-v1:0

Meta Llama:
  - meta.llama2-70b-chat-v1
  - meta.llama3-70b-instruct-v1:0

Amazon Titan:
  - amazon.titan-text-express-v1

AI21 Jurassic:
  - ai21.j2-ultra-v1
```

**Setup with IRSA (Recommended)**:

```yaml
# Create IAM role with Bedrock permissions
# Annotate service account with IAM role
apiVersion: v1
kind: ServiceAccount
metadata:
  name: bedrock-sa
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/bedrock-role
```

### OpenAI Integration

**Models**:

- GPT-4 Turbo: `gpt-4-turbo-preview`
- GPT-4: `gpt-4`
- GPT-3.5 Turbo: `gpt-3.5-turbo`

**Usage**:

```python
import requests

response = requests.post(
    'http://llm-router/v1/chat/completions',
    json={
        'model': 'gpt-4-turbo-preview',
        'messages': [
            {'role': 'system', 'content': 'You are a helpful assistant'},
            {'role': 'user', 'content': 'Explain kubernetes'}
        ],
        'temperature': 0.7
    }
)

print(response.json())
```

---

## Unified LLM Router

The router automatically selects the best model based on your requirements.

### Routing Strategies

#### 1. **Quality** (Default)

Uses highest-quality models:

- Gemini 1.5 Pro (1M context)
- Claude 3 Opus (200K context)
- GPT-4 Turbo (128K context)

```json
{
  "routing_strategy": "quality",
  "messages": [{ "role": "user", "content": "Complex reasoning task" }]
}
```

#### 2. **Fast**

Uses fastest models (<1s latency):

- Gemini Flash
- Claude 3 Haiku
- GPT-3.5 Turbo

```json
{
  "routing_strategy": "fast",
  "messages": [{ "role": "user", "content": "Quick question" }]
}
```

#### 3. **Cost**

Uses cheapest models:

- Gemini Flash ($0.10/1M tokens)
- GPT-3.5 Turbo ($0.50/1M tokens)

```json
{
  "routing_strategy": "cost",
  "messages": [{ "role": "user", "content": "Simple task" }]
}
```

#### 4. **Long Context**

For documents >100K tokens:

- Gemini 1.5 Pro (1M context)
- Claude 3 Opus (200K context)

```json
{
  "routing_strategy": "long_context",
  "requirements": {
    "min_context_window": 200000
  },
  "messages": [
    { "role": "user", "content": "Analyze this 500-page document..." }
  ]
}
```

#### 5. **Code**

Optimized for code generation:

- Code Bison (Vertex AI)
- GPT-4 Turbo

```json
{
  "routing_strategy": "code",
  "messages": [{ "role": "user", "content": "Write a REST API in Python" }]
}
```

### Automatic Fallback

If primary provider fails, router automatically tries fallback chain:

```
Vertex AI → OpenAI → Anthropic → Error
```

**Example**:

```python
# Router will automatically fallback if Vertex AI fails
response = requests.post(
    'http://llm-router/v1/chat/completions',
    json={
        'model': 'gemini-1.5-pro-001',  # Primary
        'messages': [{'role': 'user', 'content': 'Hello'}]
    }
)
# If Vertex AI fails, tries OpenAI GPT-4, then Anthropic Claude
```

---

## Usage Examples

### Example 1: ServiceNow Ticket Summarization

```python
import requests

def summarize_ticket(ticket_description):
    response = requests.post(
        'http://llm-router.production/v1/chat/completions',
        json={
            'routing_strategy': 'fast',  # Quick response
            'messages': [
                {
                    'role': 'system',
                    'content': 'Summarize ServiceNow tickets in 2 sentences'
                },
                {
                    'role': 'user',
                    'content': ticket_description
                }
            ],
            'max_tokens': 100,
            'temperature': 0.3  # Consistent summaries
        }
    )

    return response.json()['choices'][0]['message']['content']

# Usage
summary = summarize_ticket("User cannot access VPN. Error: Authentication failed...")
print(summary)
# Output: "The user is experiencing VPN authentication issues.
#          The error suggests credentials may be incorrect or expired."
```

### Example 2: Knowledge Base Search with Long Context

```python
def search_knowledge_base(query, documents):
    # Combine all documents (up to 1M tokens with Gemini!)
    context = "\n\n".join(documents)

    response = requests.post(
        'http://llm-router.production/v1/chat/completions',
        json={
            'routing_strategy': 'long_context',
            'requirements': {
                'min_context_window': 500000  # Need 500K context
            },
            'messages': [
                {
                    'role': 'system',
                    'content': 'Answer based only on the provided documents'
                },
                {
                    'role': 'user',
                    'content': f"Documents:\n{context}\n\nQuestion: {query}"
                }
            ],
            'temperature': 0.1  # Factual answers
        }
    )

    return response.json()['choices'][0]['message']['content']
```

### Example 3: Code Generation with Fallback

```python
def generate_code(task):
    response = requests.post(
        'http://llm-router.production/v1/chat/completions',
        json={
            'routing_strategy': 'code',
            'messages': [
                {
                    'role': 'user',
                    'content': f"Write production-ready code: {task}"
                }
            ],
            'temperature': 0.2,
            'max_tokens': 2000
        }
    )

    # Router automatically tries:
    # 1. Vertex AI Code Bison
    # 2. Falls back to OpenAI GPT-4
    # 3. Falls back to Anthropic Claude

    return response.json()['choices'][0]['message']['content']
```

### Example 4: Conversation Management

```python
class ConversationManager:
    def __init__(self, strategy='quality'):
        self.router_url = 'http://llm-router.production/v1/chat/completions'
        self.strategy = strategy
        self.conversation_history = []

    def send_message(self, message):
        self.conversation_history.append({
            'role': 'user',
            'content': message
        })

        response = requests.post(
            self.router_url,
            json={
                'routing_strategy': self.strategy,
                'messages': self.conversation_history,
                'temperature': 0.7
            }
        )

        assistant_message = response.json()['choices'][0]['message']['content']

        self.conversation_history.append({
            'role': 'assistant',
            'content': assistant_message
        })

        return assistant_message

# Usage
conversation = ConversationManager(strategy='quality')
response1 = conversation.send_message("What is Kubernetes?")
response2 = conversation.send_message("How do I deploy an app?")
# Maintains context across messages
```

---

## Cost Optimization

### Model Pricing Comparison (per 1M tokens)

| Provider      | Model          | Input  | Output | Context | Use Case       |
| ------------- | -------------- | ------ | ------ | ------- | -------------- |
| **Vertex AI** | Gemini Flash   | $0.10  | $0.30  | 1M      | ⚡ Fast, cheap |
| **Vertex AI** | Gemini Pro     | $3.50  | $10.50 | 1M      | 🎯 Quality     |
| **OpenAI**    | GPT-3.5        | $0.50  | $1.50  | 16K     | ⚡ Fast        |
| **OpenAI**    | GPT-4 Turbo    | $10.00 | $30.00 | 128K    | 🎯 Quality     |
| **Anthropic** | Claude 3 Haiku | $0.25  | $1.25  | 200K    | ⚡ Fast        |
| **Anthropic** | Claude 3 Opus  | $15.00 | $75.00 | 200K    | 🎯🎯 Best      |

### Cost Optimization Strategies

#### 1. Use Routing Strategies

```python
# Cheap for simple tasks
response = call_llm(routing_strategy='cost', ...)

# Quality only when needed
response = call_llm(routing_strategy='quality', ...)
```

#### 2. Token Limits

```python
# Set max_tokens based on use case
response = call_llm(
    max_tokens=100,  # Short summary
    ...
)
```

#### 3. Batch Requests

```python
# Process multiple items in one call
prompts = [f"Summarize: {text}" for text in texts]
combined_prompt = "\n\n".join(prompts)

response = call_llm(messages=[{
    'role': 'user',
    'content': combined_prompt
}])
```

#### 4. Cache Common Prompts

```python
# Use Vertex AI prefix caching (automatic)
# Repeated system prompts are cached

response = call_llm(
    messages=[
        {'role': 'system', 'content': LONG_SYSTEM_PROMPT},  # Cached!
        {'role': 'user', 'content': 'Question 1'}
    ]
)
```

### Cost Monitoring

```bash
# View cost metrics in Prometheus
kubectl port-forward -n production svc/prometheus 9090:9090

# Query:
sum(rate(vertex_tokens_total[1h])) by (model, type)
```

---

## Best Practices

### 1. Choose the Right Model

**Use Gemini Flash** when:

- ✅ Response time is critical (<500ms)
- ✅ Task is straightforward
- ✅ Cost is primary concern
- ✅ Context <1M tokens

**Use Gemini Pro** when:

- ✅ Quality is critical
- ✅ Complex reasoning needed
- ✅ Long context (>100K tokens)
- ✅ Multi-modal (text + images)

**Use GPT-4** when:

- ✅ Function calling needed
- ✅ JSON mode required
- ✅ Industry standard compatibility

**Use Claude 3 Opus** when:

- ✅ Absolute best quality
- ✅ Ethical considerations important
- ✅ Strong reasoning required

### 2. Implement Rate Limiting

```python
from ratelimit import limits, sleep_and_retry

@sleep_and_retry
@limits(calls=100, period=60)  # 100 requests per minute
def call_llm(messages):
    return requests.post(...)
```

### 3. Handle Errors Gracefully

```python
def call_llm_with_retry(messages, max_retries=3):
    for attempt in range(max_retries):
        try:
            response = requests.post(
                'http://llm-router/v1/chat/completions',
                json={'messages': messages},
                timeout=30
            )
            response.raise_for_status()
            return response.json()

        except requests.exceptions.Timeout:
            if attempt == max_retries - 1:
                raise
            time.sleep(2 ** attempt)  # Exponential backoff

        except requests.exceptions.HTTPError as e:
            if e.response.status_code == 429:  # Rate limit
                time.sleep(60)
            else:
                raise
```

### 4. Monitor Performance

```python
import time
from prometheus_client import Histogram

LLM_LATENCY = Histogram('llm_request_duration_seconds', 'LLM latency')

@LLM_LATENCY.time()
def call_llm(messages):
    return requests.post(...)
```

### 5. Optimize Token Usage

```python
# Truncate long inputs
def truncate_to_tokens(text, max_tokens=8000):
    # Rough estimate: 1 token ≈ 4 characters
    max_chars = max_tokens * 4
    if len(text) > max_chars:
        return text[:max_chars] + "..."
    return text

# Use shorter prompts
prompt = "Summarize:"  # Good
# Instead of: "Please provide a comprehensive summary of the following text..."  # Wasteful
```

---

## Deployment Checklist

### Pre-Deployment

- [ ] Workload Identity configured (GCP)
- [ ] API credentials stored in secrets
- [ ] Cost alerts configured
- [ ] Rate limits set

### Deployment

- [ ] `kubectl apply -f k8s/llm-serving/foundational-models.yaml`
- [ ] Verify pods running
- [ ] Test each provider separately
- [ ] Test unified router
- [ ] Test fallback chain

### Post-Deployment

- [ ] Monitor latency metrics
- [ ] Monitor cost metrics
- [ ] Set up alerts
- [ ] Document provider preferences
- [ ] Train team on routing strategies

---

## Troubleshooting

### Issue: "Authentication failed" (Vertex AI)

**Cause**: Workload Identity not configured

**Fix**:

```bash
# Verify service account annotation
kubectl get sa llm-gateway-sa -n production \
  -o jsonpath='{.metadata.annotations}'

# Should show: iam.gke.io/gcp-service-account

# Grant Vertex AI permissions
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:llm-gateway@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/aiplatform.user"
```

### Issue: "API key invalid" (OpenAI/Anthropic)

**Cause**: Incorrect or expired API key

**Fix**:

```bash
# Update secret
kubectl create secret generic openai-api-key \
  --from-literal=api-key=sk-NEW_KEY \
  -n production \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart pods to pick up new secret
kubectl rollout restart deployment/llm-router -n production
```

### Issue: "Rate limit exceeded"

**Cause**: Too many requests

**Fix**:

```python
# Implement client-side rate limiting
from ratelimit import limits

@limits(calls=50, period=60)
def call_llm(messages):
    ...

# Or use router fallback (automatically tries other providers)
```

---

## Summary

You now have a complete foundational models integration with:

✅ **Multi-Provider Support**: Google, AWS, OpenAI, Anthropic ✅ **Intelligent
Routing**: Automatic model selection ✅ **Cost Optimization**: Route to cheapest
suitable model ✅ **High Availability**: Automatic fallback chains ✅
**Production Ready**: Monitoring, metrics, error handling

**Quick Links**:

- Configuration: `k8s/llm-serving/foundational-models.yaml`
- Test Script: `scripts/test-llm-deployment.sh`
- Router Endpoint: `http://llm-router.production/v1/chat/completions`

**Questions?** Contact: ai-infrastructure@company.com

---

**Last Updated**: 2025-11-04 **Version**: 1.0.0
