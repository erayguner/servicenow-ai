# 🚀 LLM Deployment on Kubernetes - Complete Guide

**Based on**: "Generative AI on Kubernetes: Operationalizing Large Language
Models" by Roland Huß and Daniele Zonca (O'Reilly)

**Status**: ✅ Production-Ready **Last Updated**: 2025-11-04 **Architecture**:
Disaggregated Serving with KServe + vLLM

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Model Storage Formats](#model-storage-formats)
4. [Model Registry Integration](#model-registry-integration)
5. [GPU Management](#gpu-management)
6. [Deployment Strategies](#deployment-strategies)
7. [Performance Optimization](#performance-optimization)
8. [Testing & Validation](#testing--validation)
9. [Monitoring & Observability](#monitoring--observability)
10. [Production Checklist](#production-checklist)

---

## Overview

This implementation provides enterprise-grade LLM serving on Kubernetes with:

- **🎯 KServe Integration**: Industry-standard model serving with storage
  initializers
- **⚡ vLLM Runtime**: Optimized inference engine with PagedAttention
- **🔧 Multiple Model Sources**: Hugging Face Hub, MLflow, Kubeflow, GCS, S3
- **🖥️ GPU Management**: NVIDIA GPU Operator with time-slicing support
- **📦 OCI Image Volumes**: Zero-copy model loading (Kubernetes 1.31+)
- **🚀 Disaggregated Serving**: Separate prefill and decode for optimal resource
  usage
- **📊 Token-Based Metrics**: Comprehensive observability with Prometheus

---

## Architecture

### High-Level Design

```
┌─────────────────────────────────────────────────────────────┐
│                      LLM Service Architecture                │
└─────────────────────────────────────────────────────────────┘

┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│ llm-gateway  │────▶│  llm-router  │────▶│ KServe       │
│ (API Layer)  │     │  (Envoy)     │     │ Inference    │
└──────────────┘     └──────────────┘     │ Service      │
                              │            └──────────────┘
                              │                    │
                              ▼                    ▼
                     ┌─────────────────┐  ┌─────────────────┐
                     │ Prefill Pods    │  │ Decode Pods     │
                     │ (2 GPUs each)   │  │ (1 GPU each)    │
                     │ Compute-bound   │  │ Memory-bound    │
                     └─────────────────┘  └─────────────────┘
                              │                    │
                              └────────┬───────────┘
                                       ▼
                              ┌─────────────────┐
                              │ Model Storage   │
                              │ - Hugging Face  │
                              │ - MLflow        │
                              │ - GCS/S3        │
                              │ - OCI Images    │
                              └─────────────────┘
```

### Key Components

| Component                | Purpose                               | Configuration                   |
| ------------------------ | ------------------------------------- | ------------------------------- |
| **KServe**               | Model serving framework               | `kserve-runtime.yaml`           |
| **vLLM**                 | Inference runtime with PagedAttention | Optimized for throughput        |
| **Storage Initializers** | Download models from registries       | Automatic based on `storageUri` |
| **GPU Operator**         | GPU resource management               | `gpu-operator.yaml`             |
| **Envoy Router**         | LLM-aware request routing             | `advanced-optimization.yaml`    |

---

## Model Storage Formats

### Supported Formats

#### 1. **Safetensors** (Recommended ✅)

**Format**: `.safetensors` **Provider**: Hugging Face **Benefits**:

- ✅ Secure (no pickle vulnerabilities)
- ✅ Fast loading with memory mapping
- ✅ Supports sharding for large models
- ✅ Widely supported

**Structure**:

```
model/
├── model-00001-of-00003.safetensors
├── model-00002-of-00003.safetensors
├── model-00003-of-00003.safetensors
├── tokenizer.json
├── tokenizer_config.json
├── config.json
└── generation_config.json
```

**Example**:

```yaml
storageUri: hf://mistralai/Mistral-7B-Instruct-v0.2
```

#### 2. **GGUF/GGML** (CPU Optimized)

**Format**: `.gguf`, `.ggml` **Provider**: llama.cpp **Benefits**:

- ✅ Optimized for CPU inference
- ✅ Quantized weights (4-bit, 8-bit)
- ✅ Single-file format
- ✅ Reduced memory footprint

**Use Case**: Edge deployments, CPU-only nodes

#### 3. **PyTorch State Dict**

**Format**: `.pt`, `.pth` **Provider**: PyTorch **Benefits**:

- ✅ Native PyTorch format
- ⚠️ Requires architecture definition

#### 4. **OCI Images** (Production ✅)

**Format**: Container images **Benefits**:

- ✅ Immutable, versioned packages
- ✅ Leverages container infrastructure
- ✅ Zero-copy mounting (Kubernetes 1.31+)
- ✅ Efficient layer caching

**Build**:

```bash
# Create Dockerfile
FROM scratch
COPY ./model /models/
LABEL model.format="safetensors"

# Build and push
docker build -t gcr.io/project/llm-models/mistral-7b:v1 .
docker push gcr.io/project/llm-models/mistral-7b:v1
```

---

## Model Registry Integration

### 1. Hugging Face Hub

**Configuration**:

```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: llm-from-huggingface
spec:
  predictor:
    model:
      storageUri: hf://mistralai/Mistral-7B-Instruct-v0.2
      storageInitializer:
        env:
          - name: HF_TOKEN
            valueFrom:
              secretKeyRef:
                name: model-registry-credentials
                key: huggingface-token
```

**Features**:

- ✅ Public and private models
- ✅ Automatic version tracking
- ✅ Community model discovery
- ✅ Built-in authentication

**Private Models**:

```bash
# Create secret
kubectl create secret generic model-registry-credentials \
  --from-literal=huggingface-token=hf_YOUR_TOKEN \
  -n production
```

### 2. MLflow Model Registry

**Configuration**:

```yaml
storageUri: models:/llm-production/1

env:
  - name: MLFLOW_TRACKING_URI
    value: 'https://mlflow.example.com'
```

**Features**:

- ✅ Version management
- ✅ Model lifecycle tracking
- ✅ Experiment tracking
- ✅ Metadata storage

### 3. Kubeflow Model Registry (Kubernetes-Native)

**Configuration**:

```yaml
storageUri: model-registry://llm-production/v1

env:
  - name: MODEL_REGISTRY_BASE_URL
    value: 'http://model-registry-service.kubeflow:8080'
```

**Features**:

- ✅ Kubernetes-native (uses MLMD)
- ✅ Direct KServe integration
- ✅ Multi-tenant support
- ✅ Cloud-agnostic

### 4. Google Cloud Storage (GCS)

**Configuration**:

```yaml
storageUri: gs://my-bucket/models/mistral-7b

# Uses Workload Identity (no credentials needed)
serviceAccountName: llm-gateway-sa
```

**Features**:

- ✅ Keyless authentication via Workload Identity
- ✅ Versioning support
- ✅ Lifecycle policies
- ✅ CMEK encryption

---

## GPU Management

### NVIDIA GPU Operator

**Installation**:

```bash
# Add NVIDIA Helm repo
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
helm repo update

# Install GPU Operator
helm install gpu-operator nvidia/gpu-operator \
  -n gpu-operator \
  --create-namespace \
  --set driver.enabled=false \
  --set toolkit.version=v1.14.3
```

**Features**:

- ✅ Automatic GPU node configuration
- ✅ Device plugin for GPU scheduling
- ✅ DCGM exporter for metrics
- ✅ Node Feature Discovery (NFD)

### GPU Time-Slicing

**Configuration**: `gpu-operator.yaml`

**Benefits**:

- Share single GPU across multiple pods
- 4 pods per GPU (configurable)
- Ideal for development/staging

**Example**:

```yaml
sharing:
  timeSlicing:
    replicas: 4 # 4 pods share each GPU
```

### GPU Resource Quotas

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: gpu-quota
spec:
  hard:
    requests.nvidia.com/gpu: '20'
    limits.nvidia.com/gpu: '20'
```

---

## Deployment Strategies

### 1. Standard Deployment (Default)

**Use Case**: General-purpose LLM serving

**Configuration**: `kserve-runtime.yaml`

**Specs**:

- 2-10 replicas (HPA enabled)
- 1 GPU per pod
- Concurrency: 10 requests per pod
- Scale target: 80% utilization

### 2. Disaggregated Serving (Production ✅)

**Use Case**: High-throughput production workloads

**Configuration**: `advanced-optimization.yaml`

**Architecture**:

```
Prefill Pods:
- 2 GPUs per pod
- 2-8 replicas
- Compute-bound optimization
- Max batched tokens: 32,768

Decode Pods:
- 1 GPU per pod
- 4-20 replicas
- Memory-bound optimization
- Max sequences: 256
```

**Benefits**:

- 🚀 **2.8-4.4x throughput improvement**
- ⚡ **Better GPU utilization** (>85%)
- 🎯 **Independent scaling** of prefill vs decode
- 💰 **Cost optimization** through right-sizing

### 3. OCI Image Volume Mounts (Kubernetes 1.31+)

**Use Case**: Fastest startup time, zero model copying

**Configuration**: `oci-image-volumes.yaml`

**Benefits**:

- ⚡ **10-100x faster startup** (no model download)
- 💾 **No local storage needed** (direct mount)
- 🔒 **Immutable model versions**
- 📦 **Leverages OCI layer caching**

**Example**:

```yaml
volumes:
  - name: model-data
    image: gcr.io/project/llm-models/mistral-7b:v1
    readOnly: true
```

---

## Performance Optimization

### vLLM Runtime Parameters

#### Memory Optimization

```bash
--gpu-memory-utilization=0.90  # Use 90% of GPU memory for KV cache
--max-model-len=8192           # Maximum sequence length
--max-num-batched-tokens=16384 # Batch size for higher throughput
```

**Impact**:

- 📈 **+40% throughput** with higher GPU memory utilization
- 🎯 **Optimal KV cache size** balances requests and memory

#### Parallelization Strategies

```bash
# Tensor Parallelism (split model across GPUs)
--tensor-parallel-size=2  # Use 2 GPUs per model instance

# Pipeline Parallelism (split layers across GPUs)
--pipeline-parallel-size=2  # Use 2 GPUs in pipeline
```

**When to Use**:

- **Tensor Parallel**: Large models that don't fit on single GPU (e.g., 70B+)
- **Pipeline Parallel**: Very large models, better for decode phase

#### Performance Features

```bash
--enable-chunked-prefill       # Process prefill in chunks
--enable-prefix-caching        # Cache common prompt prefixes
--enable-flash-attention       # Use Flash Attention 2
--use-v2-block-manager        # Improved memory management
```

**Impact**:

- ⚡ **Flash Attention**: 2-4x faster attention computation
- 💾 **Prefix Caching**: 5-10x speedup for repeated prompts
- 🎯 **Chunked Prefill**: Better scheduling for mixed workloads

### Quantization (Memory Reduction)

```bash
--quantization=awq       # AWQ, GPTQ, or none
--dtype=auto             # Auto-detect optimal dtype
```

**Memory Savings**: | Quantization | Memory | Accuracy | Speed |
|--------------|--------|----------|-------| | None (FP16) | 100% | ✅ Best | ⚡
Fast | | 8-bit | 50% | ✅ Excellent | ⚡⚡ Faster | | 4-bit (AWQ) | 25% | ✅
Good | ⚡⚡⚡ Fastest |

---

## Testing & Validation

### Test Script

Create `scripts/test-llm-deployment.sh`:

```bash
#!/bin/bash
set -euo pipefail

echo "🧪 Testing LLM Deployment..."

# 1. Check GPU availability
echo "1️⃣ Checking GPU nodes..."
kubectl get nodes -l cloud.google.com/gke-accelerator -o wide

# 2. Verify GPU Operator
echo "2️⃣ Verifying GPU Operator..."
kubectl get pods -n gpu-operator

# 3. Check KServe installation
echo "3️⃣ Checking KServe..."
kubectl get pods -n kserve

# 4. Deploy test InferenceService
echo "4️⃣ Deploying test InferenceService..."
kubectl apply -f k8s/llm-serving/kserve-runtime.yaml

# Wait for ready
kubectl wait --for=condition=Ready inferenceservice/llm-service \
  -n production --timeout=600s

# 5. Test inference
echo "5️⃣ Testing inference..."
INGRESS_HOST=$(kubectl get svc istio-ingressgateway \
  -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

curl -X POST "http://${INGRESS_HOST}/v1/completions" \
  -H "Content-Type: application/json" \
  -H "Host: llm-service.production.example.com" \
  -d '{
    "model": "llm-model",
    "prompt": "Explain Kubernetes in one sentence:",
    "max_tokens": 50,
    "temperature": 0.7
  }'

# 6. Check metrics
echo "6️⃣ Checking metrics..."
kubectl exec -n production deployment/prometheus \
  -- promtool query instant \
  'vllm_request_success_total'

echo "✅ All tests passed!"
```

**Run**:

```bash
chmod +x scripts/test-llm-deployment.sh
./scripts/test-llm-deployment.sh
```

### Performance Benchmarking

```bash
# Install vegeta (load testing tool)
go install github.com/tsenart/vegeta@latest

# Create test data
cat > targets.txt <<EOF
POST http://llm-service.production/v1/completions
Content-Type: application/json
@test-prompts.json
EOF

# Run benchmark
echo "POST http://llm-service/v1/completions" | \
  vegeta attack -duration=60s -rate=10 | \
  vegeta report

# Expected results:
# Requests: 600
# Success rate: 99%+
# Latency p50: <500ms
# Latency p99: <2000ms
```

---

## Monitoring & Observability

### Key Metrics

#### Token-Based Metrics

```promql
# Token throughput (tokens/second)
rate(vllm_request_success_total[5m])

# Average tokens per request
rate(vllm_output_tokens_total[5m]) / rate(vllm_request_success_total[5m])

# Time to first token (TTFT)
histogram_quantile(0.95, vllm_time_to_first_token_seconds)

# Time per output token (TPOT)
histogram_quantile(0.95, vllm_time_per_output_token_seconds)
```

#### GPU Metrics (DCGM)

```promql
# GPU utilization
DCGM_FI_DEV_GPU_UTIL

# GPU memory usage
DCGM_FI_DEV_FB_USED / DCGM_FI_DEV_FB_FREE

# GPU temperature
DCGM_FI_DEV_GPU_TEMP

# KV cache usage
vllm_gpu_cache_usage_perc
```

### Grafana Dashboards

**LLM Serving Dashboard**:

- Token throughput over time
- Request latency percentiles (p50, p95, p99)
- KV cache utilization
- GPU memory and compute usage
- Request queue depth
- Error rates by type

**Import**: `monitoring/grafana-llm-dashboard.json`

---

## Production Checklist

### Pre-Deployment

- [ ] **GPU nodes configured** with NVIDIA drivers
- [ ] **GPU Operator installed** and validated
- [ ] **KServe installed** with Istio/Knative
- [ ] **Model registry** credentials configured
- [ ] **Workload Identity** bound to service accounts
- [ ] **Network policies** allowing LLM traffic
- [ ] **Resource quotas** set for GPU usage

### Deployment

- [ ] **Model downloaded** and cached (optional)
- [ ] **InferenceService deployed** and ready
- [ ] **HPA configured** with appropriate thresholds
- [ ] **PDB set** to maintain availability
- [ ] **Service endpoints** verified
- [ ] **TLS certificates** configured for HTTPS

### Post-Deployment

- [ ] **Inference tested** with sample requests
- [ ] **Metrics flowing** to Prometheus
- [ ] **Alerts configured** for failures/latency
- [ ] **Grafana dashboard** showing live metrics
- [ ] **Load testing** completed successfully
- [ ] **Runbook documented** for incidents
- [ ] **Backup plan** for model registry issues

### Performance Validation

- [ ] **Throughput**: >100 tokens/sec per GPU
- [ ] **Latency p50**: <500ms
- [ ] **Latency p99**: <2000ms
- [ ] **GPU utilization**: >80%
- [ ] **KV cache usage**: <95%
- [ ] **Error rate**: <0.1%

---

## Troubleshooting

### Common Issues

#### 1. GPU Not Detected

```bash
# Check GPU nodes
kubectl get nodes -l cloud.google.com/gke-accelerator

# Check GPU Operator pods
kubectl get pods -n gpu-operator

# Check device plugin
kubectl logs -n gpu-operator \
  -l app=nvidia-device-plugin-daemonset
```

#### 2. OOM Errors

**Symptoms**: `vllm_gpu_oom_total` counter increasing

**Solutions**:

- Reduce `--gpu-memory-utilization` (try 0.85)
- Decrease `--max-num-seqs`
- Enable quantization (`--quantization=awq`)
- Use smaller `--max-model-len`

#### 3. Slow Model Loading

**Solutions**:

- Use OCI image volumes (Kubernetes 1.31+)
- Pre-download models with Job
- Use persistent volume for caching
- Enable parallel downloads

#### 4. Low Throughput

**Check**:

```bash
# Request queue depth
kubectl exec -n production pod/llm-pod -- curl localhost:8080/metrics | grep vllm_num_requests_waiting

# KV cache usage
kubectl exec -n production pod/llm-pod -- curl localhost:8080/metrics | grep vllm_gpu_cache_usage_perc
```

**Solutions**:

- Increase `--max-num-batched-tokens`
- Enable `--enable-chunked-prefill`
- Scale up replicas
- Use disaggregated serving

---

## References

- 📖
  [Generative AI on Kubernetes (O'Reilly)](https://www.oreilly.com/library/view/generative-ai-on/9781098159207/)
- 🚀 [vLLM Documentation](https://docs.vllm.ai/)
- ☸️ [KServe Documentation](https://kserve.github.io/website/)
- 🖥️
  [NVIDIA GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/)
- 🤗 [Hugging Face Hub](https://huggingface.co/docs/hub/)

---

**Document Owner**: AI/ML Team **Last Updated**: 2025-11-04 **Version**: 1.0.0
**Status**: ✅ Production Ready
