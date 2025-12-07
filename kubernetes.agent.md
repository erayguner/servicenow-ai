# Kubernetes Assistant Guide

This guide defines exact Kubernetes patterns for this repository: namespaces,
security, Workload Identity, LLM serving, autoscaling, and validation.

## Manifest Organization

Location: `k8s/`

- deployments/
- services/
- ingress/
- service-accounts/
- network-policies/
- pod-security/
- observability/
- llm-serving/

## Namespaces and Node Pools

- Namespaces: dev, staging, production (separate folders or namespace fields)
- Node pools:
  - General: API, web UI, monitoring
  - AI: LLM inference, embeddings
  - Vector: vector search
    Use `nodeSelector` and tolerations to pin workloads to pools.

## Workload Identity Pattern

Every microservice uses a Kubernetes ServiceAccount annotated with the GCP
service account:

```
apiVersion: v1
kind: ServiceAccount
metadata:
  name: conversation-manager-sa
  namespace: production
  annotations:
    iam.gke.io/gcp-service-account: conversation-manager@PROJECT_ID.iam.gserviceaccount.com
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: conversation-manager
  namespace: production
spec:
  template:
    spec:
      serviceAccountName: conversation-manager-sa
      containers:
        - name: conversation-manager
          image: gcr.io/PROJECT_ID/conversation-manager:latest
```

Terraform side uses the `workload_identity` module.

## Network Policies (Default Deny)

```
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

Add explicit allow lists per service for ingress/egress, including DNS, Cloud
SQL proxy, and inter-service communication.

## Pod Security (Restricted)

- Non-root: `runAsNonRoot: true`, `runAsUser: 1000`, `fsGroup: 1000`,
  `seccompProfile: RuntimeDefault`
- Container security:
  - `allowPrivilegeEscalation: false`
  - `readOnlyRootFilesystem: true`
  - Drop all capabilities
- Resource requests/limits defined
- Health probes: liveness, readiness, startup
- Use `emptyDir` for temporary writes

## Services and Naming

Use `{service-name}-svc` convention; label with app and environment.
ClusterIP for internal services; LoadBalancer/Ingress where required (Cloud
Armor/IAP in front if applicable).

## Config and Secrets

- ConfigMaps for non-sensitive configuration.
- Secrets must be accessed via GCP Secret Manager using Workload Identity (do
  not store secrets in Kubernetes secrets or ConfigMaps in production).

## Health Checks

Implement liveness, readiness, and startup probes on all deployments.

## KServe + vLLM InferenceService

Example for Mistral-7B:

```
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: mistral-7b
  namespace: production
spec:
  predictor:
    serviceAccountName: llm-gateway-sa
    containers:
      - name: vllm
        image: vllm/vllm-openai:latest
        command: ["python3", "-m", "vllm.entrypoints.openai.api_server"]
        args:
          - --model=mistralai/Mistral-7B-Instruct-v0.2
          - --dtype=auto
          - --max-model-len=8192
          - --tensor-parallel-size=1
        resources:
          requests:
            nvidia.com/gpu: 1
            memory: '16Gi'
          limits:
            nvidia.com/gpu: 1
            memory: '16Gi'
        env:
          - name: HUGGING_FACE_HUB_TOKEN
            valueFrom:
              secretKeyRef:
                name: hf-token
                key: token
    nodeSelector:
      cloud.google.com/gke-nodepool: ai-pool
    tolerations:
      - key: 'nvidia.com/gpu'
        operator: 'Exists'
        effect: 'NoSchedule'
```

## Autoscaling

Define HorizontalPodAutoscaler (HPA) per workload with CPU/memory targets and
scale behaviors.

## Validation and Linting

- KubeLinter: `kube-linter lint k8s/`
- Pre-commit integration via `PRE_COMMIT_QUICKSTART.md`
- Required checks:
  - No privileged containers
  - Resource limits defined
  - Non-root user
  - Read-only root filesystem
  - Health checks present
  - Avoid `:latest` tags in production

## Observability

- Use `k8s/observability` for log/metrics configs.
- Ensure structured logs with trace IDs; integrate with Cloud
  Logging/Monitoring.

## LLM Routing Notes

- vLLM for simple/short requests; Vertex AI for long/complex.
- Implement hybrid routing in `llm-gateway` respecting cost/perf policies.

## ServiceNow Integration

- Event routing via Pub/Sub; ensure appropriate egress policies.
- API interactions must use mTLS and authorized endpoints where feasible.
