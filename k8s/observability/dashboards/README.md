# Grafana Dashboards

This directory contains Grafana dashboard definitions for monitoring the AI
platform.

## Available Dashboards

### AI/LLM Monitoring Dashboard

**File:** `ai-llm-monitoring.yaml` **UID:** `ai-llm-monitoring`

Comprehensive dashboard for AI/LLM operations monitoring and cost tracking.

#### Panels:

1. **LLM Cost Rate (USD/5min)**

   - Real-time cost tracking by model
   - Shows spending velocity
   - Alerts on high cost rates

2. **Total Cost (Last Hour)**

   - Gauge showing hourly spend
   - Thresholds: Yellow at $100, Red at $500

3. **Total Cost (Last 24h)**

   - Daily spending tracker
   - Thresholds: Yellow at $1000, Red at $5000

4. **Token Consumption Rate (tokens/5min)**

   - Stacked area chart by model
   - Split by input/output tokens
   - Helps identify usage patterns

5. **LLM Latency (P50/P95/P99)**

   - Percentile latency tracking
   - Per-model breakdown
   - SLO monitoring

6. **Request Rate (req/s)**

   - Success vs error rates
   - Per-model breakdown
   - Stacked bar chart

7. **Security Events**

   - Prompt injection attempts by severity
   - PII detections
   - Real-time security monitoring

8. **Model Usage Summary (Last Hour)**
   - Table view of all models
   - Cost, tokens, and request counts
   - Quick comparison

## Deployment

### Automatic Deployment

Dashboards are automatically loaded by Grafana when deployed as ConfigMaps with
the label `grafana_dashboard: '1'`.

```bash
kubectl apply -f k8s/observability/dashboards/
```

### Manual Import

1. Access Grafana:

   ```bash
   kubectl port-forward -n observability svc/grafana 3000:3000
   ```

2. Open http://localhost:3000

3. Navigate to Dashboards → Import

4. Copy the JSON from the ConfigMap data field

5. Click "Load" → "Import"

## Alert Rules

Alert rules for AI cost monitoring are defined in `ai-cost-alerts.yaml`.

### Critical Alerts

- **DailyLLMBudgetExceeded**: Daily spend > $1000
- **HighLLMErrorRate**: Error rate > 5%
- **PromptInjectionDetected**: High-severity prompt injection
- **NoLLMRequests**: Service down (no requests for 10min)

### Warning Alerts

- **HighLLMCostRate**: Hourly spend > $100
- **HighTokenConsumption**: Token rate > 100k/5min
- **HighLLMLatency**: P95 > 5000ms
- **PIIDetectedInPrompts**: > 10 PII detections/5min
- **HighCostPerRequest**: Avg cost > $0.10/request

### Info Alerts

- **ModelUsageImbalance**: > 30% Opus usage (suggest cheaper models)

## Metrics Reference

All metrics are exported by the OpenTelemetry instrumentation in the backend.

### Counter Metrics

- `llm_tokens_total{model, type, operation}` - Total tokens consumed
- `llm_cost_usd_total{model, operation}` - Total cost in USD
- `llm_requests_total{model, operation, status}` - Total requests
- `llm_errors_total{model, operation, error}` - Total errors
- `llm_security_prompt_injection_total{user_id, session_id, severity}` - Prompt
  injection attempts
- `llm_security_pii_detected_total{user_id, session_id, pii_types}` - PII
  detections

### Histogram Metrics

- `llm_latency_ms_bucket{model, operation}` - Latency distribution

## Query Examples

### Cost Analysis

```promql
# Total cost in last 24 hours
sum(increase(llm_cost_usd_total[24h]))

# Cost by model
sum by (model) (increase(llm_cost_usd_total[1h]))

# Cost per request
sum(rate(llm_cost_usd_total[5m])) / sum(rate(llm_requests_total[5m]))
```

### Performance

```promql
# P95 latency by model
histogram_quantile(0.95, rate(llm_latency_ms_bucket[5m])) by (model)

# Request rate by model and status
sum by (model, status) (rate(llm_requests_total[5m]))

# Error rate percentage
sum(rate(llm_requests_total{status='error'}[5m]))
  / sum(rate(llm_requests_total[5m])) * 100
```

### Usage Patterns

```promql
# Token consumption by type
sum by (type) (rate(llm_tokens_total[5m]))

# Most expensive model
topk(1, sum by (model) (increase(llm_cost_usd_total[1h])))

# Request distribution
sum by (model) (rate(llm_requests_total[5m]))
```

### Security

```promql
# Prompt injection attempts
rate(llm_security_prompt_injection_total[5m])

# PII detection rate
rate(llm_security_pii_detected_total[5m])
```

## Setting Up Alerts

### Slack Integration

1. Create Slack webhook in Slack settings

2. Add to Grafana notification channels:

   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: grafana-slack-webhook
     namespace: observability
   stringData:
     url: https://hooks.slack.com/services/YOUR/WEBHOOK/URL
   ```

3. Configure alert channel in Grafana UI

### PagerDuty Integration

1. Create PagerDuty integration key

2. Add to Grafana notification channels

3. Configure routing rules for critical alerts

## Cost Optimization Tips

Based on dashboard data:

1. **High Opus Usage**: Route more requests to Sonnet or Haiku
2. **Large Output Tokens**: Optimize prompts to reduce response length
3. **High Latency**: Consider caching common responses
4. **Token Waste**: Implement prompt compression
5. **Error Rate**: Improve error handling to avoid retry costs

## Maintenance

### Updating Dashboards

1. Edit the ConfigMap YAML
2. Apply changes: `kubectl apply -f ai-llm-monitoring.yaml`
3. Grafana auto-reloads (may take 30-60 seconds)

### Backup

Export dashboard JSON via Grafana UI:

- Settings → JSON Model → Copy

### Versioning

Dashboard definitions are version-controlled in this repository. Always commit
changes to Git before applying to production.

## Troubleshooting

### Dashboard Not Loading

```bash
# Check ConfigMap exists
kubectl get cm -n observability grafana-dashboard-ai-llm

# Check Grafana logs
kubectl logs -n observability deployment/grafana

# Verify label
kubectl get cm -n observability -l grafana_dashboard=1
```

### Missing Metrics

1. Check OpenTelemetry Collector is running:

   ```bash
   kubectl get pods -n observability -l app=opentelemetry-collector
   ```

2. Verify backend is exporting metrics:

   ```bash
   kubectl logs -n production deployment/ai-backend | grep -i otel
   ```

3. Check Prometheus is scraping:

   ```bash
   # Port-forward Prometheus
   kubectl port-forward -n observability svc/prometheus 9090:9090

   # Visit http://localhost:9090/targets
   ```

### Incorrect Cost Calculations

1. Verify pricing in `backend/src/observability/llm-telemetry.ts`
2. Check Anthropic pricing page for updates
3. Update PRICING constant if needed

## References

- Grafana Documentation: https://grafana.com/docs/
- Prometheus Queries:
  https://prometheus.io/docs/prometheus/latest/querying/basics/
- OpenTelemetry Metrics: https://opentelemetry.io/docs/specs/otel/metrics/
- Backend Instrumentation: `backend/src/observability/README.md`
