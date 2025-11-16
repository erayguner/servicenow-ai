# Observability Module

This module provides OpenTelemetry instrumentation for the AI backend service.

## Features

- **Auto-instrumentation**: Automatic tracing for Express.js, HTTP, PostgreSQL, and other libraries
- **Custom LLM Telemetry**: Track tokens, costs, latency, and errors for AI operations
- **Distributed Tracing**: W3C Trace Context propagation across services
- **Metrics**: Counters, histograms for key performance indicators
- **Security Events**: Track prompt injection attempts and PII detection

## Usage

### Basic Auto-Instrumentation

Auto-instrumentation is automatically enabled when you import `./instrumentation` at the top of `index.ts`.

All HTTP requests, database queries, and external API calls are automatically traced.

### Custom LLM Tracing

Use the `traceLLMOperation` function to track AI/LLM calls:

```typescript
import { traceLLMOperation } from './observability/llm-telemetry';
import { anthropic } from './services/anthropic';

async function generateCompletion(prompt: string, userId: string) {
  const startTime = Date.now();

  return traceLLMOperation(
    {
      model: 'claude-3-5-sonnet-20241022',
      operation: 'completion',
      userId,
      temperature: 0.7,
      maxTokens: 4096,
    },
    async (span) => {
      const response = await anthropic.messages.create({
        model: 'claude-3-5-sonnet-20241022',
        max_tokens: 4096,
        messages: [{ role: 'user', content: prompt }],
      });

      return {
        data: response,
        metrics: {
          inputTokens: response.usage.input_tokens,
          outputTokens: response.usage.output_tokens,
          totalTokens: response.usage.input_tokens + response.usage.output_tokens,
          latencyMs: Date.now() - startTime,
          success: true,
        },
      };
    }
  );
}
```

### Security Event Tracking

Track prompt injection attempts:

```typescript
import { recordPromptInjectionAttempt } from './observability/llm-telemetry';

if (detectPromptInjection(userInput)) {
  recordPromptInjectionAttempt(userId, sessionId, 'high');
  throw new Error('Prompt injection detected');
}
```

Track PII detection:

```typescript
import { recordPIIDetection } from './observability/llm-telemetry';

const piiTypes = detectPII(userInput); // ['email', 'ssn', 'credit_card']
if (piiTypes.length > 0) {
  recordPIIDetection(userId, sessionId, piiTypes);
  // Redact PII before sending to LLM
}
```

## Metrics Exported

### LLM Metrics

- `llm.tokens.total` - Total tokens consumed (input/output split)
- `llm.cost.usd` - Total cost in USD (calculated from token usage)
- `llm.requests.total` - Total requests (success/error split)
- `llm.latency.ms` - Request latency histogram
- `llm.errors.total` - Total errors by model and type

### Security Metrics

- `llm.security.prompt_injection` - Prompt injection attempts by severity
- `llm.security.pii_detected` - PII detections by type

## Traces

All traces include the following attributes:

### Auto-Instrumented Traces

- `http.method` - HTTP method (GET, POST, etc.)
- `http.url` - Request URL
- `http.status_code` - Response status
- `express.route` - Express route pattern
- `db.system` - Database system (postgresql)
- `db.statement` - SQL query (sanitized)

### Custom LLM Traces

- `llm.model` - Model name (e.g., claude-3-5-sonnet-20241022)
- `llm.operation` - Operation type (completion, embedding, function-call)
- `llm.user_id` - User ID
- `llm.session_id` - Session ID
- `llm.temperature` - Temperature parameter
- `llm.max_tokens` - Max tokens parameter
- `llm.tokens.input` - Input tokens used
- `llm.tokens.output` - Output tokens generated
- `llm.tokens.total` - Total tokens
- `llm.cost.usd` - Calculated cost
- `llm.latency.ms` - Operation latency

## Configuration

Configure via environment variables:

```bash
# OpenTelemetry Collector endpoint (default: K8s service)
OTEL_COLLECTOR_URL=http://opentelemetry-collector.observability:4317

# Service identification
SERVICE_NAME=ai-backend
SERVICE_VERSION=1.0.0
NODE_ENV=production
```

## Viewing Traces and Metrics

### Local Development

1. Start the observability stack:
   ```bash
   kubectl port-forward -n observability svc/grafana 3000:3000
   ```

2. Access Grafana at http://localhost:3000

3. Import dashboards from `/k8s/observability/dashboards/`

### Production

Traces and metrics are exported to:
- **Google Cloud Trace**: Distributed tracing
- **Google Cloud Monitoring**: Metrics and dashboards
- **Prometheus**: Time-series metrics
- **Grafana**: Visualization

## Pricing Model

Token pricing is defined in `llm-telemetry.ts`:

| Model | Input (per 1M tokens) | Output (per 1M tokens) |
|-------|----------------------|------------------------|
| Claude 3.5 Sonnet | $3.00 | $15.00 |
| Claude 3.5 Haiku | $0.80 | $4.00 |
| Claude 3 Opus | $15.00 | $75.00 |

Update these values when Anthropic changes pricing.

## Best Practices

1. **Always trace LLM calls**: Use `traceLLMOperation` for all AI operations
2. **Add context**: Include userId, sessionId for better debugging
3. **Record security events**: Track prompt injection and PII detection
4. **Monitor costs**: Set up alerts on `llm.cost.usd` metric
5. **Set SLOs**: Use P95 latency for LLM operations in SLO definitions

## Troubleshooting

### Traces not appearing

1. Check OTEL_COLLECTOR_URL is correct
2. Verify OTel Collector is running: `kubectl get pods -n observability`
3. Check logs: `kubectl logs -n observability deployment/opentelemetry-collector`

### High latency

1. Check OTel batch processor settings in `instrumentation.ts`
2. Verify network connectivity to collector
3. Consider using async exporters

### Missing metrics

1. Ensure metrics are being recorded in code
2. Check metric export interval (default: 60s)
3. Verify Prometheus is scraping the collector
