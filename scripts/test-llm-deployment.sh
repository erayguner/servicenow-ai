#!/bin/bash
#
# LLM Deployment Test Script
# Comprehensive validation of Kubernetes-based LLM serving infrastructure
#
# Usage: ./scripts/test-llm-deployment.sh [--namespace NAMESPACE] [--skip-gpu-check]
#

set -euo pipefail

# Configuration
NAMESPACE="${NAMESPACE:-production}"
SKIP_GPU_CHECK="${SKIP_GPU_CHECK:-false}"
TIMEOUT=600

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
  --namespace)
    NAMESPACE="$2"
    shift 2
    ;;
  --skip-gpu-check)
    SKIP_GPU_CHECK=true
    shift
    ;;
  *)
    echo "Unknown option: $1"
    exit 1
    ;;
  esac
done

log_success() {
  echo -e "${GREEN}✅ $1${NC}"
}

log_error() {
  echo -e "${RED}❌ $1${NC}"
}

log_warning() {
  echo -e "${YELLOW}⚠️  $1${NC}"
}

log_info() {
  echo -e "${BLUE}ℹ️  $1${NC}"
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 LLM Deployment Test Suite"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Namespace: $NAMESPACE"
echo "Skip GPU Check: $SKIP_GPU_CHECK"
echo ""

# Test 1: Check GPU Nodes
test_gpu_nodes() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "1️⃣  Testing GPU Node Configuration"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  if [ "$SKIP_GPU_CHECK" = "true" ]; then
    log_warning "Skipping GPU node check"
    return 0
  fi

  # Check for GPU nodes
  GPU_NODES=$(kubectl get nodes \
    -l cloud.google.com/gke-accelerator \
    --no-headers 2>/dev/null | wc -l)

  if [ "$GPU_NODES" -gt 0 ]; then
    log_success "Found $GPU_NODES GPU nodes"
    kubectl get nodes -l cloud.google.com/gke-accelerator -o wide
    echo ""

    # Check GPU capacity
    echo "GPU Capacity per node:"
    kubectl get nodes \
      -l cloud.google.com/gke-accelerator \
      -o custom-columns=NAME:.metadata.name,GPU-TYPE:.metadata.labels.cloud\\.google\\.com/gke-accelerator,GPU-COUNT:.status.capacity.nvidia\\.com/gpu
  else
    log_error "No GPU nodes found in cluster"
    log_info "GPU nodes are required for LLM serving"
    return 1
  fi
}

# Test 2: Verify GPU Operator
test_gpu_operator() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "2️⃣  Testing NVIDIA GPU Operator"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  if [ "$SKIP_GPU_CHECK" = "true" ]; then
    log_warning "Skipping GPU Operator check"
    return 0
  fi

  # Check if GPU Operator namespace exists
  if ! kubectl get namespace gpu-operator &>/dev/null; then
    log_warning "GPU Operator namespace not found"
    log_info "GPU Operator may not be installed"
    return 0
  fi

  # Check GPU Operator pods
  OPERATOR_PODS=$(kubectl get pods -n gpu-operator \
    --field-selector=status.phase=Running \
    --no-headers 2>/dev/null | wc -l)

  if [ "$OPERATOR_PODS" -gt 0 ]; then
    log_success "GPU Operator is running ($OPERATOR_PODS pods)"

    # Check critical components
    echo "Critical components:"
    kubectl get pods -n gpu-operator \
      -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName \
      2>/dev/null || log_warning "Could not list GPU Operator pods"
  else
    log_error "GPU Operator not running"
    return 1
  fi
}

# Test 3: Check KServe Installation
test_kserve() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "3️⃣  Testing KServe Installation"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Check if KServe CRDs are installed
  if kubectl get crd inferenceservices.serving.kserve.io &>/dev/null; then
    log_success "KServe CRDs are installed"

    # Check KServe controller
    if kubectl get pods -n kserve -l control-plane=kserve-controller-manager &>/dev/null; then
      KSERVE_PODS=$(kubectl get pods -n kserve \
        -l control-plane=kserve-controller-manager \
        --field-selector=status.phase=Running \
        --no-headers 2>/dev/null | wc -l)

      if [ "$KSERVE_PODS" -gt 0 ]; then
        log_success "KServe controller is running"
      else
        log_error "KServe controller is not running"
        return 1
      fi
    else
      log_warning "Could not check KServe controller status"
    fi
  else
    log_error "KServe CRDs not found"
    log_info "KServe must be installed for LLM serving"
    return 1
  fi
}

# Test 4: Validate Kubernetes Resources
test_k8s_resources() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "4️⃣  Testing Kubernetes Resources"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Check namespace
  if kubectl get namespace "$NAMESPACE" &>/dev/null; then
    log_success "Namespace '$NAMESPACE' exists"
  else
    log_error "Namespace '$NAMESPACE' not found"
    return 1
  fi

  # Check service accounts
  if kubectl get serviceaccount llm-gateway-sa -n "$NAMESPACE" &>/dev/null; then
    log_success "Service account 'llm-gateway-sa' exists"

    # Check Workload Identity annotation
    WI_ANNOTATION=$(kubectl get serviceaccount llm-gateway-sa -n "$NAMESPACE" \
      -o jsonpath='{.metadata.annotations.iam\.gke\.io/gcp-service-account}' 2>/dev/null || echo "")

    if [ -n "$WI_ANNOTATION" ]; then
      log_success "Workload Identity configured: $WI_ANNOTATION"
    else
      log_warning "Workload Identity annotation not found"
    fi
  else
    log_warning "Service account 'llm-gateway-sa' not found"
  fi

  # Check storage class
  if kubectl get storageclass fast-model-storage &>/dev/null; then
    log_success "Storage class 'fast-model-storage' exists"
  else
    log_warning "Storage class 'fast-model-storage' not found"
  fi
}

# Test 5: Deploy Test InferenceService
test_inference_service() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "5️⃣  Testing InferenceService Deployment"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  log_info "Applying KServe runtime configuration..."

  # Check if ServingRuntime exists
  if kubectl get servingruntime vllm-runtime -n "$NAMESPACE" &>/dev/null; then
    log_success "ServingRuntime 'vllm-runtime' already exists"
  else
    log_info "Creating ServingRuntime 'vllm-runtime'..."
    if kubectl apply -f k8s/llm-serving/kserve-runtime.yaml; then
      log_success "ServingRuntime created"
    else
      log_error "Failed to create ServingRuntime"
      return 1
    fi
  fi

  # Check if test InferenceService exists
  if kubectl get inferenceservice llm-service -n "$NAMESPACE" &>/dev/null; then
    log_info "InferenceService 'llm-service' already exists"

    # Get current status
    READY=$(kubectl get inferenceservice llm-service -n "$NAMESPACE" \
      -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")

    if [ "$READY" = "True" ]; then
      log_success "InferenceService is ready"
    else
      log_warning "InferenceService exists but not ready (Status: $READY)"
      log_info "Waiting for InferenceService to become ready (timeout: ${TIMEOUT}s)..."

      if kubectl wait --for=condition=Ready inferenceservice/llm-service \
        -n "$NAMESPACE" --timeout="${TIMEOUT}s" 2>/dev/null; then
        log_success "InferenceService became ready"
      else
        log_error "InferenceService did not become ready within timeout"
        log_info "Check events and pod logs:"
        kubectl describe inferenceservice llm-service -n "$NAMESPACE"
        return 1
      fi
    fi
  else
    log_info "InferenceService not found (expected for first run)"
    log_info "Deploy with: kubectl apply -f k8s/llm-serving/kserve-runtime.yaml"
  fi
}

# Test 6: Check Model Registry Integration
test_model_registry() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "6️⃣  Testing Model Registry Integration"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Check model registry config
  if kubectl get configmap model-registry-config -n "$NAMESPACE" &>/dev/null; then
    log_success "Model registry configuration exists"

    # Show configured registries
    echo "Configured registries:"
    kubectl get configmap model-registry-config -n "$NAMESPACE" \
      -o jsonpath='{.data}' | jq -r 'keys[]' 2>/dev/null || echo "  (Unable to parse)"
  else
    log_warning "Model registry configuration not found"
    log_info "Deploy with: kubectl apply -f k8s/llm-serving/model-registry-integration.yaml"
  fi

  # Check model registry credentials
  if kubectl get secret model-registry-credentials -n "$NAMESPACE" &>/dev/null; then
    log_success "Model registry credentials secret exists"
  else
    log_warning "Model registry credentials not found"
    log_info "Create with credentials for Hugging Face, MLflow, etc."
  fi
}

# Test 7: Verify Monitoring Setup
test_monitoring() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "7️⃣  Testing Monitoring Configuration"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Check ServiceMonitor for GPU metrics
  if kubectl get servicemonitor dcgm-exporter -n gpu-operator &>/dev/null; then
    log_success "DCGM Exporter ServiceMonitor exists"
  else
    log_warning "DCGM Exporter ServiceMonitor not found"
  fi

  # Check ServiceMonitor for LLM metrics
  if kubectl get servicemonitor llm-token-metrics -n "$NAMESPACE" &>/dev/null; then
    log_success "LLM token metrics ServiceMonitor exists"
  else
    log_warning "LLM metrics ServiceMonitor not found"
  fi

  # Check PrometheusRule for alerts
  if kubectl get prometheusrule llm-serving-alerts -n "$NAMESPACE" &>/dev/null; then
    log_success "LLM serving alert rules exist"
  else
    log_warning "LLM alert rules not found"
  fi
}

# Test 8: Performance Check
test_performance() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "8️⃣  Testing Performance Configuration"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Check HPA
  if kubectl get hpa -n "$NAMESPACE" | grep -q llm-; then
    log_success "HorizontalPodAutoscaler(s) configured"
    kubectl get hpa -n "$NAMESPACE" | grep llm- || true
  else
    log_warning "No HorizontalPodAutoscaler found for LLM services"
  fi

  # Check PDB
  if kubectl get pdb -n "$NAMESPACE" | grep -q llm-; then
    log_success "PodDisruptionBudget(s) configured"
    kubectl get pdb -n "$NAMESPACE" | grep llm- || true
  else
    log_warning "No PodDisruptionBudget found for LLM services"
  fi

  # Check resource quotas
  if kubectl get resourcequota gpu-quota -n "$NAMESPACE" &>/dev/null; then
    log_success "GPU resource quota exists"

    echo "GPU quota details:"
    kubectl get resourcequota gpu-quota -n "$NAMESPACE" \
      -o custom-columns=RESOURCE:.spec.hard,USED:.status.used 2>/dev/null || echo "  (Unable to parse)"
  else
    log_warning "GPU resource quota not found"
  fi
}

# Run all tests
FAILED_TESTS=0

test_gpu_nodes || ((FAILED_TESTS++))
test_gpu_operator || ((FAILED_TESTS++))
test_kserve || ((FAILED_TESTS++))
test_k8s_resources || ((FAILED_TESTS++))
test_inference_service || ((FAILED_TESTS++))
test_model_registry || ((FAILED_TESTS++))
test_monitoring || ((FAILED_TESTS++))
test_performance || ((FAILED_TESTS++))

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Test Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $FAILED_TESTS -eq 0 ]; then
  log_success "All tests passed! LLM deployment is ready."
  echo ""
  log_info "Next steps:"
  echo "  1. Deploy InferenceService: kubectl apply -f k8s/llm-serving/kserve-runtime.yaml"
  echo "  2. Test inference endpoint"
  echo "  3. Monitor metrics in Grafana"
  exit 0
else
  log_error "$FAILED_TESTS test(s) failed"
  echo ""
  log_info "Review the errors above and fix the issues"
  echo ""
  log_info "Common fixes:"
  echo "  - Install GPU Operator: helm install gpu-operator nvidia/gpu-operator"
  echo "  - Install KServe: kubectl apply -f https://github.com/kserve/kserve/releases/latest/download/kserve.yaml"
  echo "  - Configure Workload Identity for service accounts"
  exit 1
fi
