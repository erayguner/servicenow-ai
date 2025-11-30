#!/bin/bash
#
# Workload Identity Audit Script
# Daily automated check for service account keys and Workload Identity compliance
#
# Usage: ./scripts/audit-workload-identity.sh [--project PROJECT_ID] [--slack-webhook URL]
#

set -euo pipefail

# Configuration
PROJECT_ID="${GCP_PROJECT_ID:-}"
SLACK_WEBHOOK="${SLACK_WEBHOOK_URL:-}"
REGION="${GCP_REGION:-europe-west2}"
CLUSTER_NAME="prod-ai-agent-gke"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
  --project)
    PROJECT_ID="$2"
    shift 2
    ;;
  --slack-webhook)
    SLACK_WEBHOOK="$2"
    shift 2
    ;;
  *)
    echo "Unknown option: $1"
    exit 1
    ;;
  esac
done

# Verify prerequisites
if [ -z "$PROJECT_ID" ]; then
  echo -e "${RED}ERROR: GCP_PROJECT_ID not set${NC}"
  exit 1
fi

log_success() {
  echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
  echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
  echo -e "${RED}❌ $1${NC}"
}

notify_slack() {
  local message="$1"
  local severity="${2:-warning}"

  if [ -z "$SLACK_WEBHOOK" ]; then
    return
  fi

  local color="warning"
  local emoji="⚠️"

  case $severity in
  critical)
    color="danger"
    emoji="🚨"
    ;;
  error)
    color="danger"
    emoji="❌"
    ;;
  success)
    color="good"
    emoji="✅"
    ;;
  esac

  curl -X POST "$SLACK_WEBHOOK" \
    -H 'Content-Type: application/json' \
    -d "{
            \"attachments\": [{
                \"color\": \"$color\",
                \"title\": \"${emoji} Workload Identity Audit\",
                \"text\": \"$message\",
                \"footer\": \"Project: $PROJECT_ID\",
                \"ts\": $(date +%s)
            }]
        }" 2>/dev/null || true
}

# Check for user-managed service account keys
check_service_account_keys() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🔍 Checking for Service Account Keys"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  local violations=0

  # Get all service accounts
  local service_accounts=$(gcloud iam service-accounts list \
    --project="$PROJECT_ID" \
    --format="value(email)")

  while IFS= read -r sa_email; do
    # Check for user-managed keys
    local keys=$(gcloud iam service-accounts keys list \
      --iam-account="$sa_email" \
      --project="$PROJECT_ID" \
      --filter="keyType=USER_MANAGED" \
      --format="value(name)" 2>/dev/null || echo "")

    if [ -n "$keys" ]; then
      log_error "User-managed keys found for: $sa_email"
      echo "$keys" | while read -r key; do
        echo "  Key ID: $key"

        # Get key age
        local created=$(gcloud iam service-accounts keys describe "$key" \
          --iam-account="$sa_email" \
          --project="$PROJECT_ID" \
          --format="value(validAfterTime)" 2>/dev/null || echo "unknown")
        echo "  Created: $created"
      done
      violations=$((violations + 1))
    fi
  done <<<"$service_accounts"

  if [ $violations -eq 0 ]; then
    log_success "No user-managed service account keys found"
    return 0
  else
    log_error "$violations service accounts have user-managed keys"
    notify_slack "🚨 CRITICAL: $violations service accounts have user-managed keys! Investigate immediately." "critical"
    return 1
  fi
}

# Verify Workload Identity configuration for GKE
check_gke_workload_identity() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🔍 Checking GKE Workload Identity"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Check if cluster has Workload Identity enabled
  local wi_enabled=$(gcloud container clusters describe "$CLUSTER_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --format="value(workloadIdentityConfig.workloadPool)" 2>/dev/null || echo "")

  if [ -z "$wi_enabled" ]; then
    log_error "Workload Identity not enabled on cluster: $CLUSTER_NAME"
    notify_slack "❌ Workload Identity not enabled on GKE cluster $CLUSTER_NAME" "error"
    return 1
  fi

  log_success "Workload Identity enabled: $wi_enabled"

  # Get cluster credentials
  gcloud container clusters get-credentials "$CLUSTER_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID" 2>/dev/null || {
    log_warning "Could not get cluster credentials"
    return 0
  }

  # Check Kubernetes ServiceAccounts
  local k8s_sa=$(kubectl get serviceaccounts -n production \
    -o json 2>/dev/null | jq -r '.items[] | select(.metadata.annotations["iam.gke.io/gcp-service-account"]) | .metadata.name' || echo "")

  if [ -z "$k8s_sa" ]; then
    log_warning "No Kubernetes ServiceAccounts with Workload Identity annotations found"
    return 0
  fi

  local sa_count=$(echo "$k8s_sa" | wc -l)
  log_success "Found $sa_count Kubernetes ServiceAccounts with Workload Identity"

  # Verify IAM bindings
  echo "$k8s_sa" | while read -r sa_name; do
    local gcp_sa=$(kubectl get serviceaccount "$sa_name" -n production \
      -o jsonpath='{.metadata.annotations.iam\.gke\.io/gcp-service-account}' 2>/dev/null || echo "")

    if [ -n "$gcp_sa" ]; then
      # Check if IAM binding exists
      local binding=$(gcloud iam service-accounts get-iam-policy "$gcp_sa" \
        --project="$PROJECT_ID" \
        --format="value(bindings.members)" 2>/dev/null |
        grep "serviceAccount:${PROJECT_ID}.svc.id.goog\[production/${sa_name}\]" || echo "")

      if [ -n "$binding" ]; then
        log_success "  $sa_name → $gcp_sa (binding exists)"
      else
        log_warning "  $sa_name → $gcp_sa (binding missing!)"
      fi
    fi
  done
}

# Check Workload Identity Federation for GitHub Actions
check_workload_identity_federation() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🔍 Checking Workload Identity Federation"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Check for WIF pool
  local wif_pool=$(gcloud iam workload-identity-pools list \
    --location=global \
    --project="$PROJECT_ID" \
    --format="value(name)" 2>/dev/null | grep "github-actions-pool" || echo "")

  if [ -z "$wif_pool" ]; then
    log_warning "No Workload Identity Federation pool found for GitHub Actions"
    return 0
  fi

  log_success "Workload Identity Federation pool exists: github-actions-pool"

  # Check providers
  local providers=$(gcloud iam workload-identity-pools providers list \
    --location=global \
    --workload-identity-pool=github-actions-pool \
    --project="$PROJECT_ID" \
    --format="value(name)" 2>/dev/null || echo "")

  if [ -n "$providers" ]; then
    log_success "WIF providers configured:"
    echo "$providers" | while read -r provider; do
      echo "  - $provider"
    done
  fi
}

# Check for secrets containing potential keys
check_secret_manager() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🔍 Checking Secret Manager"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  local suspicious_secrets=$(gcloud secrets list \
    --project="$PROJECT_ID" \
    --format="value(name)" 2>/dev/null |
    grep -iE "key|credential|service-account" || echo "")

  if [ -n "$suspicious_secrets" ]; then
    log_warning "Suspicious secret names found (may contain keys):"
    echo "$suspicious_secrets" | while read -r secret; do
      echo "  - $secret"
    done
    log_warning "Verify these secrets don't contain service account keys"
  else
    log_success "No suspicious secret names found"
  fi
}

# Generate audit report
generate_report() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📊 Audit Summary"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Project: $PROJECT_ID"
  echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo ""

  if [ $TOTAL_VIOLATIONS -eq 0 ]; then
    log_success "AUDIT PASSED - No violations found"
    notify_slack "✅ Daily Workload Identity audit passed - No violations" "success"
  else
    log_error "AUDIT FAILED - $TOTAL_VIOLATIONS violations found"
    notify_slack "🚨 AUDIT FAILED: $TOTAL_VIOLATIONS violations found! Review immediately." "critical"
  fi

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Main execution
TOTAL_VIOLATIONS=0

echo "🔐 Workload Identity Security Audit"
echo "Project: $PROJECT_ID"
echo "Date: $(date)"
echo ""

# Run checks
if ! check_service_account_keys; then
  TOTAL_VIOLATIONS=$((TOTAL_VIOLATIONS + 1))
fi

if ! check_gke_workload_identity; then
  TOTAL_VIOLATIONS=$((TOTAL_VIOLATIONS + 1))
fi

check_workload_identity_federation
check_secret_manager

# Generate report
generate_report

# Exit with appropriate code
if [ $TOTAL_VIOLATIONS -gt 0 ]; then
  exit 1
else
  exit 0
fi
