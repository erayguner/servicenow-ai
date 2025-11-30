#!/bin/bash
#
# Security Incident Response Automation
# Handles detection, containment, and response to security incidents
#
# Usage: ./security-incident-response.sh [incident-type] [severity]
#

set -euo pipefail

# Configuration
PROJECT_ID="${GCP_PROJECT_ID:-}"
REGION="${GCP_REGION:-europe-west2}"
CLUSTER_NAME="prod-ai-agent-gke"
SLACK_WEBHOOK="${SLACK_SECURITY_WEBHOOK:-}"
PAGERDUTY_KEY="${PAGERDUTY_INTEGRATION_KEY:-}"

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Logging
log_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Notification functions
notify_slack() {
  local message="$1"
  local severity="${2:-info}"

  if [ -z "$SLACK_WEBHOOK" ]; then
    log_warn "Slack webhook not configured"
    return
  fi

  local color="good"
  case $severity in
  critical) color="danger" ;;
  high) color="danger" ;;
  medium) color="warning" ;;
  esac

  curl -X POST "$SLACK_WEBHOOK" \
    -H 'Content-Type: application/json' \
    -d "{
            \"attachments\": [{
                \"color\": \"$color\",
                \"title\": \"🚨 Security Incident\",
                \"text\": \"$message\",
                \"footer\": \"Security Response Bot\",
                \"ts\": $(date +%s)
            }]
        }" 2>/dev/null || log_warn "Failed to send Slack notification"
}

notify_pagerduty() {
  local message="$1"
  local severity="${2:-high}"

  if [ -z "$PAGERDUTY_KEY" ]; then
    log_warn "PagerDuty key not configured"
    return
  fi

  curl -X POST "https://events.pagerduty.com/v2/enqueue" \
    -H 'Content-Type: application/json' \
    -d "{
            \"routing_key\": \"$PAGERDUTY_KEY\",
            \"event_action\": \"trigger\",
            \"payload\": {
                \"summary\": \"Security Incident: $message\",
                \"severity\": \"$severity\",
                \"source\": \"security-automation\",
                \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
            }
        }" 2>/dev/null || log_warn "Failed to send PagerDuty alert"
}

# Incident detection
detect_prompt_injection() {
  log_info "Detecting prompt injection attempts..."

  local count=$(gcloud logging read \
    "jsonPayload.securityEvent=true AND jsonPayload.type=\"prompt_injection\"" \
    --project="$PROJECT_ID" \
    --format="value(timestamp)" \
    --limit=100 \
    --freshness=5m | wc -l)

  if [ "$count" -gt 10 ]; then
    log_error "CRITICAL: ${count} prompt injection attempts detected in last 5 minutes!"
    return 1
  fi

  log_info "✅ Prompt injection check passed (${count} attempts)"
  return 0
}

detect_rate_limit_abuse() {
  log_info "Detecting rate limit abuse..."

  local abusers=$(gcloud logging read \
    "jsonPayload.securityEvent=true AND jsonPayload.type=\"rate_limit_exceeded\"" \
    --project="$PROJECT_ID" \
    --format="value(jsonPayload.userId)" \
    --limit=1000 \
    --freshness=10m | sort | uniq -c | sort -rn | head -5)

  echo "$abusers" | while read count user; do
    if [ "$count" -gt 50 ]; then
      log_warn "User $user exceeded rate limit $count times"
    fi
  done

  log_info "✅ Rate limit check complete"
}

detect_unauthorized_access() {
  log_info "Detecting unauthorized access attempts..."

  local count=$(gcloud logging read \
    "protoPayload.status.code=7 AND protoPayload.authenticationInfo.principalEmail=~\".*@${PROJECT_ID}.iam.gserviceaccount.com\"" \
    --project="$PROJECT_ID" \
    --format="value(timestamp)" \
    --limit=100 \
    --freshness=5m | wc -l)

  if [ "$count" -gt 20 ]; then
    log_error "WARNING: ${count} permission denied events in last 5 minutes"
    return 1
  fi

  log_info "✅ Unauthorized access check passed"
  return 0
}

# Incident response actions
block_malicious_user() {
  local user_id="$1"

  log_warn "Blocking user: $user_id"

  # Add user to blocklist in Firestore
  gcloud firestore documents create \
    --project="$PROJECT_ID" \
    --collection-id=blocklist \
    --document-id="$user_id" \
    --data="{
            \"blocked_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
            \"reason\": \"Automated security block\",
            \"blocked_by\": \"security-automation\"
        }" 2>/dev/null || log_error "Failed to add user to blocklist"

  log_info "✅ User $user_id blocked"
  notify_slack "User $user_id has been blocked due to malicious activity" "high"
}

isolate_compromised_pod() {
  local pod_name="$1"
  local namespace="${2:-production}"

  log_warn "Isolating compromised pod: $pod_name"

  # Get cluster credentials
  gcloud container clusters get-credentials "$CLUSTER_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID" 2>/dev/null || {
    log_error "Failed to get cluster credentials"
    return 1
  }

  # Apply NetworkPolicy to isolate pod
  kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: isolate-$pod_name
  namespace: $namespace
spec:
  podSelector:
    matchLabels:
      pod-name: $pod_name
  policyTypes:
  - Ingress
  - Egress
  # Deny all traffic
EOF

  log_info "✅ Pod $pod_name isolated"
  notify_slack "Pod $pod_name has been isolated due to security incident" "critical"
}

collect_forensics() {
  local incident_type="$1"
  local timestamp=$(date +%Y%m%d_%H%M%S)
  local forensics_dir="/tmp/forensics_${incident_type}_${timestamp}"

  log_info "Collecting forensic data..."
  mkdir -p "$forensics_dir"

  # Collect security logs
  gcloud logging read \
    "jsonPayload.securityEvent=true" \
    --project="$PROJECT_ID" \
    --format=json \
    --limit=1000 \
    --freshness=1h >"${forensics_dir}/security_logs.json"

  # Collect pod logs
  gcloud container clusters get-credentials "$CLUSTER_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID" 2>/dev/null

  for pod in $(kubectl get pods -n production -o name); do
    pod_name=$(basename "$pod")
    kubectl logs "$pod" -n production --tail=1000 >"${forensics_dir}/${pod_name}.log" 2>/dev/null || true
  done

  # Collect Cloud SQL audit logs
  gcloud sql operations list \
    --instance=prod-postgres \
    --project="$PROJECT_ID" \
    --format=json >"${forensics_dir}/cloudsql_operations.json" 2>/dev/null || true

  # Archive forensics
  tar -czf "${forensics_dir}.tar.gz" -C /tmp "$(basename $forensics_dir)"

  # Upload to Cloud Storage
  gsutil cp "${forensics_dir}.tar.gz" "gs://backup-prod/forensics/" 2>/dev/null || {
    log_warn "Failed to upload forensics to Cloud Storage"
  }

  log_info "✅ Forensics collected: ${forensics_dir}.tar.gz"
  echo "$forensics_dir"
}

rotate_compromised_credentials() {
  log_warn "Rotating potentially compromised credentials..."

  # List all secrets
  local secrets=$(gcloud secrets list \
    --project="$PROJECT_ID" \
    --format="value(name)")

  echo "$secrets" | while read secret; do
    log_info "Generating new version for secret: $secret"

    # Create new secret version (requires manual value input)
    log_warn "Manual action required: Update secret $secret in Secret Manager"
    notify_slack "Action Required: Manually rotate secret $secret" "high"
  done

  log_info "✅ Credential rotation initiated"
}

# Incident response workflows
handle_prompt_injection() {
  log_error "Handling prompt injection incident..."

  # 1. Detect and collect details
  local attackers=$(gcloud logging read \
    "jsonPayload.securityEvent=true AND jsonPayload.type=\"prompt_injection\"" \
    --project="$PROJECT_ID" \
    --format="value(jsonPayload.userId)" \
    --limit=100 \
    --freshness=5m | sort | uniq)

  # 2. Block attackers
  echo "$attackers" | while read user; do
    if [ -n "$user" ]; then
      block_malicious_user "$user"
    fi
  done

  # 3. Collect forensics
  forensics_dir=$(collect_forensics "prompt_injection")

  # 4. Notify security team
  notify_slack "Prompt injection incident handled. Forensics: ${forensics_dir}.tar.gz" "critical"
  notify_pagerduty "Prompt injection attack detected and mitigated" "high"

  log_info "✅ Prompt injection incident resolved"
}

handle_unauthorized_access() {
  log_error "Handling unauthorized access incident..."

  # 1. Identify affected resources
  local affected=$(gcloud logging read \
    "protoPayload.status.code=7" \
    --project="$PROJECT_ID" \
    --format="value(protoPayload.resourceName)" \
    --limit=100 \
    --freshness=10m | sort | uniq)

  log_info "Affected resources:"
  echo "$affected"

  # 2. Collect forensics
  forensics_dir=$(collect_forensics "unauthorized_access")

  # 3. Review IAM policies (manual)
  log_warn "Manual action required: Review IAM policies for affected resources"
  notify_slack "Unauthorized access detected. Manual IAM review required. Forensics: ${forensics_dir}.tar.gz" "high"

  log_info "✅ Unauthorized access incident documented"
}

handle_data_exfiltration() {
  log_error "Handling data exfiltration incident..."

  # 1. Identify suspicious egress
  local egress=$(gcloud logging read \
    "resource.type=\"gce_subnetwork\" AND jsonPayload.connection.dest_ip!~\"10.*\"" \
    --project="$PROJECT_ID" \
    --format="value(jsonPayload.connection.dest_ip)" \
    --limit=1000 \
    --freshness=1h | sort | uniq -c | sort -rn | head -10)

  log_info "Top egress destinations:"
  echo "$egress"

  # 2. Isolate affected pods (if identified)
  log_warn "Manual action required: Identify and isolate compromised pods"

  # 3. Collect forensics
  forensics_dir=$(collect_forensics "data_exfiltration")

  # 4. Alert security team immediately
  notify_slack "🚨 CRITICAL: Potential data exfiltration detected! Forensics: ${forensics_dir}.tar.gz" "critical"
  notify_pagerduty "CRITICAL: Data exfiltration suspected" "critical"

  # 5. Rotate credentials
  rotate_compromised_credentials

  log_error "⚠️  Data exfiltration incident requires immediate manual investigation"
}

# Main incident response coordinator
respond_to_incident() {
  local incident_type="$1"
  local severity="${2:-high}"

  log_info "====================================="
  log_info "Security Incident Response"
  log_info "Type: $incident_type"
  log_info "Severity: $severity"
  log_info "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  log_info "====================================="

  case "$incident_type" in
  prompt_injection)
    handle_prompt_injection
    ;;
  unauthorized_access)
    handle_unauthorized_access
    ;;
  data_exfiltration)
    handle_data_exfiltration
    ;;
  rate_limit_abuse)
    # Collect data but don't auto-block (might be legitimate traffic spike)
    detect_rate_limit_abuse
    forensics_dir=$(collect_forensics "rate_limit_abuse")
    notify_slack "Rate limit abuse detected. Review required. Forensics: ${forensics_dir}.tar.gz" "medium"
    ;;
  *)
    log_error "Unknown incident type: $incident_type"
    log_info "Supported types: prompt_injection, unauthorized_access, data_exfiltration, rate_limit_abuse"
    exit 1
    ;;
  esac

  log_info "====================================="
  log_info "Incident response complete"
  log_info "====================================="
}

# Continuous monitoring
monitor_security() {
  log_info "Starting continuous security monitoring..."

  while true; do
    log_info "Running security checks... ($(date))"

    # Check for prompt injection
    if ! detect_prompt_injection; then
      respond_to_incident "prompt_injection" "critical"
    fi

    # Check for unauthorized access
    if ! detect_unauthorized_access; then
      respond_to_incident "unauthorized_access" "high"
    fi

    # Check for rate limit abuse
    detect_rate_limit_abuse

    # Sleep for 5 minutes
    sleep 300
  done
}

# CLI interface
main() {
  if [ "$#" -eq 0 ]; then
    log_error "Usage: $0 [command] [options]"
    log_info ""
    log_info "Commands:"
    log_info "  respond [incident-type] [severity]  - Respond to specific incident"
    log_info "  monitor                              - Start continuous monitoring"
    log_info "  detect                               - Run one-time security scan"
    log_info "  block [user-id]                      - Block malicious user"
    log_info "  isolate [pod-name] [namespace]       - Isolate compromised pod"
    log_info "  forensics [incident-type]            - Collect forensic data"
    log_info ""
    log_info "Incident Types: prompt_injection, unauthorized_access, data_exfiltration, rate_limit_abuse"
    exit 1
  fi

  command="$1"
  shift

  case "$command" in
  respond)
    respond_to_incident "$@"
    ;;
  monitor)
    monitor_security
    ;;
  detect)
    detect_prompt_injection
    detect_unauthorized_access
    detect_rate_limit_abuse
    ;;
  block)
    block_malicious_user "$@"
    ;;
  isolate)
    isolate_compromised_pod "$@"
    ;;
  forensics)
    collect_forensics "$@"
    ;;
  *)
    log_error "Unknown command: $command"
    exit 1
    ;;
  esac
}

# Verify prerequisites
if [ -z "$PROJECT_ID" ]; then
  log_error "GCP_PROJECT_ID environment variable not set"
  exit 1
fi

main "$@"
