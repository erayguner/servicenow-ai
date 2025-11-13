# Architecture Decision Records (ADRs)

This directory contains Architecture Decision Records (ADRs) for the ServiceNow AI Infrastructure project.

## What is an ADR?

An Architecture Decision Record (ADR) captures an important architectural decision made along with its context and consequences. ADRs help teams:
- Understand why decisions were made
- Avoid revisiting settled decisions
- Onboard new team members
- Learn from past mistakes

## ADR Format

We use the following format for ADRs:
1. **Title:** Brief description of the decision
2. **Status:** Proposed, Accepted, Deprecated, Superseded
3. **Context:** What is the issue we're seeing that motivates this decision?
4. **Decision:** What is the change we're actually proposing or doing?
5. **Consequences:** What becomes easier or harder as a result of this decision?

## Index of ADRs

| ADR | Title | Status | Date |
|-----|-------|--------|------|
| [001](001-adopt-gke-for-kubernetes.md) | Adopt GKE for Kubernetes Orchestration | Accepted | 2024-12-01 |
| [002](002-multi-region-disaster-recovery.md) | Implement Multi-Region Disaster Recovery | Accepted | 2025-01-15 |
| [003](003-observability-stack-opentelemetry.md) | Adopt OpenTelemetry for Observability | Accepted | 2025-01-20 |
| [004](004-automated-secrets-rotation.md) | Implement Automated Secrets Rotation | Accepted | 2025-01-20 |
| [005](005-spot-instances-cost-optimization.md) | Enable Spot Instances for Cost Optimization | Accepted | 2025-01-20 |
| [006](006-ai-governance-framework.md) | Establish AI Governance Framework | Accepted | 2025-01-20 |
| [007](007-multi-cloud-abstraction-strategy.md) | Adopt Multi-Cloud Abstraction Strategy | Accepted | 2025-01-20 |

## Creating a New ADR

1. Copy the [template](000-template.md)
2. Number it sequentially (e.g., `008-my-decision.md`)
3. Fill in all sections
4. Submit for review via pull request
5. Update this index after approval

## ADR Lifecycle

```
Proposed → Accepted → [Deprecated] → [Superseded by ADR-XXX]
```

- **Proposed:** Under discussion, not yet implemented
- **Accepted:** Approved and being implemented
- **Deprecated:** No longer recommended, but not replaced
- **Superseded:** Replaced by a newer ADR
