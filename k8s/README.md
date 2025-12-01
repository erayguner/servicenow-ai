# Kubernetes Manifests

This directory contains Kubernetes manifests for deploying the LLM serving infrastructure.

## Directory Structure

```
k8s/
├── deployments/          # Application deployments
├── llm-serving/         # LLM serving infrastructure
│   ├── advanced-optimization.yaml    # Disaggregated serving
│   ├── foundational-models.yaml      # Vertex AI and routing
│   ├── gpu-operator.yaml             # NVIDIA GPU operator config
│   ├── hybrid-routing.yaml           # Hybrid cloud/self-hosted routing
│   ├── kserve-runtime.yaml           # KServe runtime definitions
│   ├── model-registry-integration.yaml  # Model registry integrations
│   └── oci-image-volumes.yaml        # OCI image-based model distribution
└── networking/          # Network policies and ingress

```

## Validation

### kubeconform

Kubernetes manifests are validated using [kubeconform](https://github.com/yannh/kubeconform) in strict mode.

#### Running Validation

```bash
# Via Makefile
make kubeconform

# Directly
kubeconform -strict -summary -skip InferenceService,ServingRuntime,ServiceMonitor,PrometheusRule k8s
```

#### Skipped Custom Resources

The following Custom Resource Definitions (CRDs) are skipped during validation as they require external schemas:

- **InferenceService** (KServe) - ML model serving
- **ServingRuntime** (KServe) - Runtime configuration for model serving
- **ServiceMonitor** (Prometheus Operator) - Service monitoring configuration
- **PrometheusRule** (Prometheus Operator) - Alerting rules

These resources are validated by their respective operators at runtime.

#### CI/CD Integration

kubeconform validation runs automatically in the CI pipeline (`.github/workflows/lint.yml`) for all pull requests and pushes to main/develop branches.

### KubeLinter

Security and best practices are enforced using [KubeLinter](https://github.com/stackrox/kube-linter):

```bash
# Via pre-commit
make pre-commit-k8s

# Directly
kube-linter lint k8s/
```

Configuration: `.kube-linter.yaml`

## Custom Resource Definitions (CRDs)

This project uses the following CRDs:

### KServe

- **InferenceService**: Defines ML model serving endpoints
- **ServingRuntime**: Configures model runtime (vLLM, TorchServe, etc.)

Documentation: https://kserve.github.io/website/

### Prometheus Operator

- **ServiceMonitor**: Configures Prometheus scraping targets
- **PrometheusRule**: Defines alerting and recording rules

Documentation: https://prometheus-operator.dev/

## Best Practices

1. **Resource Limits**: All containers must define CPU and memory requests/limits
2. **Security Context**: All pods and containers must have securityContext configured
3. **Pod Anti-Affinity**: Deployments with 3+ replicas must use podAntiAffinity for high availability
4. **Node Selectors**: Use string values for all nodeSelector fields (e.g., `"1"` not `1`)

## Development

### Prerequisites

- kubectl
- kubeconform (install: `go install github.com/yannh/kubeconform/cmd/kubeconform@latest`)
- kube-linter (install: https://github.com/stackrox/kube-linter#installation)

### Making Changes

1. Edit manifests
2. Run validation: `make kubeconform`
3. Run linting: `make pre-commit-k8s`
4. Test in development cluster
5. Submit PR

## Deployment

Manifests are deployed using kubectl:

```bash
# Apply all manifests
kubectl apply -R -f k8s/

# Apply specific directory
kubectl apply -f k8s/llm-serving/

# Apply specific file
kubectl apply -f k8s/llm-serving/hybrid-routing.yaml
```

See deployment documentation in `/terraform/` for infrastructure provisioning.
