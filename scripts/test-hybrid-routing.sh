#!/bin/bash
#
# Hybrid LLM Router Test Script
# Tests automatic routing between self-hosted and cloud models
#
# Usage: ./scripts/test-hybrid-routing.sh [--router-url URL]
#

set -euo pipefail

# Configuration
ROUTER_URL="${ROUTER_URL:-http://hybrid-llm-router.production/v1/chat/completions}"
NAMESPACE="production"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
  --router-url)
    ROUTER_URL="$2"
    shift 2
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

log_test() {
  echo -e "${MAGENTA}🧪 $1${NC}"
}

log_model() {
  echo -e "${CYAN}🤖 Model Used: $1${NC}"
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔄 Hybrid LLM Router Test Suite"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Router URL: $ROUTER_URL"
echo ""

# Check if we need to port-forward
if [[ "$ROUTER_URL" == *"localhost"* ]] || [[ "$ROUTER_URL" == *"127.0.0.1"* ]]; then
  log_info "Using local endpoint (ensure port-forward is active)"
else
  log_info "Using cluster endpoint"
fi

# Test function
test_request() {
  local test_name="$1"
  local payload="$2"
  local expected_model="$3"

  log_test "$test_name"

  response=$(curl -s -X POST "$ROUTER_URL" \
    -H "Content-Type: application/json" \
    -d "$payload" 2>/dev/null || echo '{"error": "request failed"}')

  if echo "$response" | jq -e '.choices[0].message.content' >/dev/null 2>&1; then
    content=$(echo "$response" | jq -r '.choices[0].message.content')
    model=$(echo "$response" | jq -r '.model // "unknown"')

    log_success "Response received"
    log_model "$model"

    if [[ -n "$expected_model" ]] && [[ "$model" == *"$expected_model"* ]]; then
      log_success "Routed to expected model type: $expected_model"
    elif [[ -n "$expected_model" ]]; then
      log_warning "Expected $expected_model, got $model"
    fi

    echo "Response preview: ${content:0:100}..."
    echo ""
    return 0
  else
    error=$(echo "$response" | jq -r '.error // "unknown error"')
    log_error "Request failed: $error"
    echo ""
    return 1
  fi
}

# Test 1: Auto routing with simple query (should use self-hosted)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 1: Auto Routing - Simple Query"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
test_request \
  "Simple question about Kubernetes" \
  '{
        "model": "auto",
        "messages": [{"role": "user", "content": "What is Kubernetes in one sentence?"}],
        "max_tokens": 100
    }' \
  "mistral"

# Test 2: Fast routing (should use disaggregated self-hosted)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 2: Fast Routing Strategy"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
test_request \
  "Fast response required" \
  '{
        "model": "auto",
        "routing_strategy": "fast",
        "messages": [{"role": "user", "content": "Quick: summarize Docker"}],
        "max_tokens": 50
    }' \
  "mistral"

# Test 3: Cost routing (should prefer self-hosted)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 3: Cost-Optimized Routing"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
test_request \
  "Budget-conscious request" \
  '{
        "model": "auto",
        "routing_strategy": "cost",
        "messages": [{"role": "user", "content": "Translate to Spanish: Hello, how are you?"}],
        "max_tokens": 50
    }' \
  "mistral"

# Test 4: Quality routing (should use premium cloud)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 4: Quality Routing Strategy"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
test_request \
  "Complex reasoning task" \
  '{
        "model": "auto",
        "routing_strategy": "quality",
        "messages": [{"role": "user", "content": "Analyze the pros and cons of microservices vs monolithic architecture"}],
        "max_tokens": 200
    }' \
  "gemini\|claude\|gpt"

# Test 5: Code generation (should use CodeLlama if available)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 5: Code Generation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
test_request \
  "Code generation task" \
  '{
        "model": "auto",
        "messages": [{"role": "user", "content": "Write a Python function to check if a number is prime"}],
        "max_tokens": 150
    }' \
  "codellama\|mistral"

# Test 6: Explicit model selection
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 6: Explicit Model Selection"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
test_request \
  "Force Gemini Flash" \
  '{
        "model": "gemini-1.5-flash",
        "messages": [{"role": "user", "content": "Explain REST APIs"}],
        "max_tokens": 100
    }' \
  "gemini"

# Test 7: Check metrics endpoint
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 7: Metrics Endpoint"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

METRICS_URL="${ROUTER_URL/v1\/chat\/completions/metrics}"
if [[ "$METRICS_URL" == *"localhost"* ]]; then
  METRICS_URL="http://localhost:9090/metrics"
fi

log_info "Checking metrics at: $METRICS_URL"

if curl -s "$METRICS_URL" | grep -q "litellm_request_total"; then
  log_success "Metrics endpoint is working"
  echo ""
  echo "Key metrics:"
  curl -s "$METRICS_URL" | grep "^litellm_request_total\|^litellm_request_duration_seconds" | head -5
else
  log_warning "Could not reach metrics endpoint"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 8: Component Health Checks"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check router deployment
if kubectl get deployment hybrid-llm-router -n "$NAMESPACE" &>/dev/null; then
  READY=$(kubectl get deployment hybrid-llm-router -n "$NAMESPACE" \
    -o jsonpath='{.status.readyReplicas}/{.status.replicas}')
  log_success "Router deployment: $READY pods ready"
else
  log_error "Router deployment not found"
fi

# Check self-hosted models
SELF_HOSTED=$(kubectl get inferenceservice -n "$NAMESPACE" \
  --no-headers 2>/dev/null | wc -l)
if [ "$SELF_HOSTED" -gt 0 ]; then
  log_success "Self-hosted models: $SELF_HOSTED InferenceServices"
else
  log_warning "No self-hosted InferenceServices found"
fi

# Check cloud gateways
CLOUD_GATEWAYS=$(kubectl get pods -n "$NAMESPACE" -l component=llm-gateway \
  --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
if [ "$CLOUD_GATEWAYS" -gt 0 ]; then
  log_success "Cloud gateways: $CLOUD_GATEWAYS pods running"
else
  log_warning "No cloud gateway pods running"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Test Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

log_success "Hybrid routing tests complete!"
echo ""
log_info "Next steps:"
echo "  1. Monitor routing decisions: kubectl logs -n $NAMESPACE -l app=llm-router -f"
echo "  2. View metrics: kubectl port-forward -n $NAMESPACE svc/hybrid-llm-router 9090:9090"
echo "  3. Check costs: Query Prometheus for litellm_request_total_cost"
echo "  4. Tune routing: Edit ConfigMap hybrid-router-config"
echo ""
log_info "Documentation:"
echo "  - Hybrid Routing Guide: HYBRID_ROUTING_GUIDE.md"
echo "  - Quick Start: FOUNDATIONAL_MODELS_QUICKSTART.md"
echo "  - Full LLM Guide: docs/LLM_DEPLOYMENT_GUIDE.md"
