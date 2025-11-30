# ADR-003: Adopt OpenTelemetry for Observability

**Date:** 2025-01-20 **Status:** Accepted **Deciders:** CTO, VP Engineering, SRE
Team **Related:** [Future-Proofing Analysis](../FUTURE_PROOFING_ANALYSIS.md),
[SLO Definitions](../../k8s/observability/slo-definitions.yaml)

---

## Context

Our current observability infrastructure is minimal, consisting primarily of:

- **Logs:** Cloud Logging (GCP-native)
- **Metrics:** Basic GKE monitoring (Cloud Monitoring)
- **Tracing:** None
- **Dashboards:** Manual GCP console queries
- **Alerting:** Ad-hoc, no formal SLOs

### Problems with Current State

1. **No Distributed Tracing:** Cannot trace requests across microservices
2. **Vendor Lock-in:** GCP Cloud Monitoring is not portable
3. **Limited Visibility:** Difficult to debug performance issues
4. **No SLO Tracking:** Cannot measure reliability against targets
5. **Manual Operations:** No automated anomaly detection or alerting
6. **Future-Proofing Gap:** Identified in 10-year analysis as critical
   improvement

### Requirements

- **Distributed Tracing:** Track requests across all services
- **Unified Metrics:** Centralized metrics from all sources (K8s, apps,
  infrastructure)
- **Cloud-Agnostic:** Support multi-cloud strategy (ADR-007)
- **Open Standards:** Avoid vendor lock-in
- **SLO Tracking:** Measure availability, latency, error rates against targets
- **Developer-Friendly:** Easy to instrument code
- **Cost-Effective:** Prefer open-source, self-hosted where possible

## Decision

We will adopt **OpenTelemetry** as the standard for observability, with the
following stack:

### Observability Stack Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   Applications                           │
│  (Instrumented with OpenTelemetry SDKs)                 │
└────────────────────┬────────────────────────────────────┘
                     │ OTLP (gRPC/HTTP)
                     ▼
┌─────────────────────────────────────────────────────────┐
│         OpenTelemetry Collector (K8s DaemonSet)         │
│  • Receives: traces, metrics, logs                      │
│  • Processes: batching, filtering, sampling             │
│  • Exports to multiple backends                         │
└─────┬──────────────┬──────────────┬─────────────────────┘
      │              │              │
      ▼              ▼              ▼
  ┌─────────┐  ┌──────────┐  ┌─────────────┐
  │ Jaeger  │  │Prometheus│  │ Cloud Trace │
  │(Tracing)│  │ (Metrics)│  │   (Backup)  │
  └─────────┘  └──────────┘  └─────────────┘
                     │
                     ▼
            ┌──────────────────┐
            │     Grafana      │
            │  (Visualization) │
            └──────────────────┘
```

### Components

#### 1. OpenTelemetry Collector (Core)

**Deployment:** Kubernetes DaemonSet (2 replicas) **Configuration:**

- **Receivers:** OTLP (gRPC + HTTP), Prometheus scraping, K8s metrics
- **Processors:** Batch, memory limiter, resource detection, k8s attributes
- **Exporters:**
  - Prometheus (metrics)
  - Jaeger/Cloud Trace (traces)
  - Loki/Cloud Logging (logs)

**Benefits:**

- Vendor-neutral data collection
- Single agent for traces, metrics, logs
- Centralized configuration
- Multi-backend export (avoid lock-in)

#### 2. Prometheus (Metrics Storage)

**Deployment:** Kubernetes StatefulSet (2 replicas) **Retention:** 30 days
**Configuration:**

- Scrape all K8s services with `prometheus.io/scrape` annotation
- Federate from OpenTelemetry Collector Prometheus exporter
- AlertManager integration for SLO violations

**Why Prometheus:**

- Industry standard for metrics
- Excellent Kubernetes integration
- PromQL query language (powerful)
- Cloud-agnostic
- Self-hosted = cost-effective

#### 3. Grafana (Visualization)

**Deployment:** Kubernetes Deployment (1 replica) **Datasources:**

- Prometheus (primary metrics)
- Jaeger (traces)
- Loki (logs, optional)
- Cloud Monitoring (hybrid, during transition)

**Dashboards:**

- Infrastructure overview (nodes, pods, resources)
- Service-level SLOs (availability, latency, errors)
- LLM performance (token usage, costs, latency)
- Business metrics (requests/sec, active users)

#### 4. Jaeger (Distributed Tracing) - Optional

**Deployment:** Kubernetes (or use Cloud Trace) **Retention:** 7 days
**Sampling:** 1% production, 100% dev/staging

**Alternative:** Use Google Cloud Trace for traces (managed service)

- Pros: Zero maintenance, unlimited retention
- Cons: GCP lock-in
- **Decision:** Start with Cloud Trace, migrate to Jaeger in Phase 2 if needed

### Application Instrumentation

**Supported Languages:**

- Python: `opentelemetry-instrumentation-fastapi`, `opentelemetry-sdk`
- Node.js: `@opentelemetry/sdk-node`, auto-instrumentation
- Go: `go.opentelemetry.io/otel`
- Java: `opentelemetry-javaagent` (auto-instrumentation)

**Auto-Instrumentation Preferred:**

- Reduce developer burden
- Consistent metrics across services
- Faster adoption

**Custom Instrumentation for:**

- Business metrics (user actions, conversions)
- LLM-specific metrics (token usage, costs)
- Custom spans for critical operations

### SLO Definitions

Defined for critical services (see
[slo-definitions.yaml](../../k8s/observability/slo-definitions.yaml)):

**Example SLOs:**

- **LLM Gateway:** 99.95% availability, P99 latency <500ms
- **API Gateway:** 99.95% availability, P99 latency <300ms
- **Knowledge Base:** 99.9% availability, P99 search <200ms

**Error Budget Alerting:**

- Critical: 5% budget consumed in 1 hour → Page
- High: 5% budget consumed in 6 hours → Page
- Medium: 5% budget consumed in 3 days → Ticket

## Consequences

### Positive

✅ **Vendor Independence:** OpenTelemetry is cloud-agnostic ✅ **Unified
Observability:** Single stack for traces, metrics, logs ✅ **SLO Tracking:**
Formal reliability measurement ✅ **Faster Debugging:** Distributed tracing
reveals bottlenecks ✅ **Cost Transparency:** Track LLM costs in real-time ✅
**Future-Proof:** CNCF standard, strong industry adoption ✅ **Multi-Cloud
Ready:** Supports GCP, AWS, Azure exporters ✅ **Developer Productivity:**
Auto-instrumentation reduces friction

### Negative

❌ **Initial Setup Complexity:** Requires Kubernetes expertise

- Mitigation: Use Helm charts, comprehensive documentation

❌ **Resource Overhead:** OpenTelemetry Collector + Prometheus consume resources

- Estimated: ~3 GB RAM, 2 CPU cores
- Mitigation: Right-sizing, resource limits

❌ **Learning Curve:** Team needs to learn PromQL, Grafana, OpenTelemetry
concepts

- Mitigation: Training sessions, runbooks

❌ **Data Volume:** High-cardinality metrics can overwhelm Prometheus

- Mitigation: Sampling, metric filtering, retention policies

❌ **Operational Burden:** Self-hosted Prometheus/Grafana require maintenance

- Mitigation: Managed Grafana Cloud (optional), automated backups

### Neutral

⚖️ **Migration Effort:** Transitioning from Cloud Monitoring requires
application changes

- Timeline: Gradual over 3-6 months
- Hybrid approach during transition

⚖️ **Storage Costs:** Prometheus storage for 30 days ~100GB

- Cost: Negligible with persistent volumes

## Alternatives Considered

### Alternative 1: Google Cloud Operations Suite (Cloud Monitoring + Cloud Trace)

**Rejected:** High vendor lock-in

**Pros:**

- Fully managed, zero operational overhead
- Deep GKE integration
- Automatic instrumentation

**Cons:**

- GCP lock-in (blocks multi-cloud strategy)
- Higher cost at scale
- Limited customization
- Cannot take data to other clouds

**Verdict:** Use Cloud Trace as backup exporter, but not primary

### Alternative 2: Datadog

**Rejected:** Cost prohibitive, SaaS vendor lock-in

**Pros:**

- Excellent UX, powerful features
- Great support and integrations
- Out-of-the-box dashboards

**Cons:**

- $$$$ Very expensive at scale (~$500/host/month)
- Vendor lock-in (proprietary agent)
- Data leaves our infrastructure

**Verdict:** Not aligned with cost-conscious, open-source strategy

### Alternative 3: Elastic Stack (ELK)

**Rejected:** Overkill for current needs

**Pros:**

- Powerful log search (Elasticsearch)
- Rich visualization (Kibana)
- All-in-one solution

**Cons:**

- Resource-intensive (Elasticsearch cluster)
- Complex to operate
- Primarily for logs, not metrics/traces
- Lower OpenTelemetry integration

**Verdict:** Defer until we need advanced log search (2026+)

### Alternative 4: Splunk

**Rejected:** Enterprise cost, license complexity

**Pros:**

- Enterprise-grade features
- Excellent for compliance/security use cases

**Cons:**

- Extremely expensive (data volume pricing)
- Complex licensing
- Overkill for current scale

**Verdict:** Not suitable

## Implementation Plan

### Phase 1: Foundation (Q1 2025) ✅ IN PROGRESS

**Timeline:** 4 weeks **Owner:** SRE Team

Tasks:

- [x] Deploy OpenTelemetry Collector (K8s manifests created)
- [x] Deploy Prometheus + Grafana (K8s manifests created)
- [x] Define SLOs for critical services (completed)
- [ ] Create initial Grafana dashboards (infrastructure overview)
- [ ] Set up alerting rules (SLO burn rate)
- [ ] Document instrumentation guide for developers

### Phase 2: Application Instrumentation (Q2 2025)

**Timeline:** 8 weeks **Owner:** Engineering Team

Tasks:

- [ ] Instrument LLM Gateway (Python/FastAPI)
- [ ] Instrument Conversation Manager
- [ ] Instrument Knowledge Base
- [ ] Instrument API Gateway
- [ ] Add custom metrics for business KPIs
- [ ] Enable distributed tracing

### Phase 3: SLO Operationalization (Q3 2025)

**Timeline:** 4 weeks **Owner:** SRE Team

Tasks:

- [ ] Create SLO dashboards (all services)
- [ ] Implement error budget tracking
- [ ] Set up PagerDuty integration
- [ ] Monthly SLO reviews (establish process)
- [ ] Incident postmortems with SLO impact

### Phase 4: Advanced Features (Q4 2025)

**Timeline:** Ongoing **Owner:** SRE Team

Tasks:

- [ ] Anomaly detection (Prometheus AlertManager)
- [ ] Cost attribution dashboards (LLM costs by service)
- [ ] Capacity planning dashboards
- [ ] Chaos engineering metrics
- [ ] Multi-cloud metric federation (AWS + GCP)

## Success Metrics

### Adoption Metrics (by Q3 2025)

- [ ] 100% of production services instrumented
- [ ] 10+ SLOs defined and tracked
- [ ] 5+ Grafana dashboards created
- [ ] 20+ alerting rules configured
- [ ] 90%+ team trained on observability stack

### Technical Metrics

- [ ] Mean Time to Detection (MTTD): <5 minutes
- [ ] Mean Time to Resolution (MTTR): <30 minutes
- [ ] Trace completion rate: >95%
- [ ] Metric cardinality: <1M active series (Prometheus)

### Business Metrics

- [ ] SLO compliance: >99% for all critical services
- [ ] Incident response time: -50% (via faster debugging)
- [ ] Customer satisfaction: +10% (via better reliability)

## Cost Analysis

### Infrastructure Costs

**Self-Hosted (Recommended):**

- OpenTelemetry Collector: $0 (open-source, K8s resources already provisioned)
- Prometheus: $50/month (storage ~100GB)
- Grafana: $0 (self-hosted) or $50/month (Grafana Cloud starter)
- Total: $50-100/month

**Managed Alternative (Not Recommended):**

- Datadog: $5,000-10,000/month (50 hosts, APM)
- New Relic: $3,000-7,000/month
- Cloud Monitoring (GCP): $500-1,500/month

**Savings:** $4,900-9,900/month (~$60K-120K/year) by self-hosting

### Operational Costs

- SRE time for setup: 160 hours (1 person, 1 month)
- Ongoing maintenance: 20 hours/month
- Developer training: 40 hours (one-time)

**Total Implementation Cost:** ~$30K (labor + setup) **ROI:** 6-12 months (via
reduced incident costs, avoided Datadog fees)

## Risks & Mitigations

| Risk                          | Likelihood | Impact | Mitigation                               |
| ----------------------------- | ---------- | ------ | ---------------------------------------- |
| Prometheus storage fills disk | Medium     | High   | Automated retention policies, monitoring |
| High cardinality explosion    | High       | Medium | Metric filtering, sampling, limits       |
| Team lacks expertise          | Medium     | Medium | Training, documentation, external help   |
| Performance impact on apps    | Low        | Medium | Sampling, async export, testing          |
| Data loss (Prometheus crash)  | Low        | Low    | Prometheus HA (2 replicas), backups      |

## Monitoring & Alerting

### Meta-Monitoring (Monitoring the Monitors)

**Key Metrics:**

- OpenTelemetry Collector health (liveness, memory usage)
- Prometheus query latency
- Grafana dashboard load time
- Alert delivery success rate

**Alerts:**

- Collector down for >5 minutes
- Prometheus disk >80% full
- Alert delivery failure

## References

- [OpenTelemetry Official Docs](https://opentelemetry.io/docs/)
- [Prometheus Best Practices](https://prometheus.io/docs/practices/naming/)
- [Google SRE Book - SLO Chapter](https://sre.google/sre-book/service-level-objectives/)
- [Future-Proofing Analysis](../FUTURE_PROOFING_ANALYSIS.md)
- [SLO Definitions YAML](../../k8s/observability/slo-definitions.yaml)

## Approval

**Approved By:**

- [x] CTO (2025-01-20)
- [x] VP Engineering (2025-01-20)
- [x] SRE Team Lead (2025-01-20)

**Implementation Start Date:** 2025-01-22 **Target Completion Date:** 2025-Q3

---

**Status:** Accepted **Last Updated:** 2025-01-20
