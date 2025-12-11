#!/bin/bash

################################################################################
# Bedrock Agents - CloudWatch Dashboards Setup
#
# Creates and configures CloudWatch dashboards for monitoring Bedrock agents
# infrastructure and Lambda performance metrics.
#
# Usage:
#   ./setup-dashboards.sh [OPTIONS]
#
# Options:
#   -e, --environment ENV      Environment: dev, staging, or prod
#   -c, --create               Create dashboards
#   -u, --update               Update existing dashboards
#   -l, --list                 List existing dashboards
#   -d, --delete DASHBOARD     Delete specific dashboard
#   --dry-run                  Show what would be created
#   -h, --help                 Show this help message
#
# Examples:
#   ./setup-dashboards.sh -e dev -c
#   ./setup-dashboards.sh -e prod -u
#   ./setup-dashboards.sh -l
#
################################################################################

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
LOG_DIR="${PROJECT_ROOT}/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/dashboards_${TIMESTAMP}.log"

# Defaults
ENVIRONMENT=""
CREATE=false
UPDATE=false
LIST=false
DELETE=""
DRY_RUN=false

mkdir -p "${LOG_DIR}"

################################################################################
# Logging
################################################################################

log_info() { echo -e "${BLUE}[INFO]${NC} $*" | tee -a "${LOG_FILE}"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "${LOG_FILE}"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" | tee -a "${LOG_FILE}"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*" | tee -a "${LOG_FILE}"; }

################################################################################
# Main Functions
################################################################################

check_prerequisites() {
  if ! command -v aws &> /dev/null || ! command -v jq &> /dev/null; then
    log_error "Missing required tools: aws, jq"
    exit 1
  fi

  if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS credentials not configured"
    exit 1
  fi
}

create_dashboards() {
  log_info "Creating CloudWatch dashboards for environment: ${ENVIRONMENT}"

  if [ "${DRY_RUN}" = true ]; then
    log_warning "DRY RUN: Would create dashboards"
    return 0
  fi

  # Create Lambda Performance Dashboard
  local lambda_dashboard=$(cat <<'EOF'
{
  "DashboardName": "bedrock-agents-ENV-lambda-performance",
  "DashboardBody": "{\"widgets\":[{\"type\":\"metric\",\"properties\":{\"metrics\":[[\"AWS/Lambda\",\"Duration\",{\"stat\":\"Average\"}],[\".\",\"Errors\",{\"stat\":\"Sum\"}],[\".\",\"Throttles\",{\"stat\":\"Sum\"}],[\".\",\"ConcurrentExecutions\",{\"stat\":\"Maximum\"}],[\".\",\"Invocations\",{\"stat\":\"Sum\"}]],\"period\":300,\"stat\":\"Average\",\"region\":\"us-east-1\",\"title\":\"Lambda Performance\"}},{\"type\":\"metric\",\"properties\":{\"metrics\":[[\"AWS/Lambda\",\"Duration\",{\"stat\":\"p99\"}],[\".\",\".\",{\"stat\":\"p95\"}],[\".\",\".\",{\"stat\":\"p50\"}]],\"period\":300,\"stat\":\"Average\",\"region\":\"us-east-1\",\"title\":\"Lambda Latency Percentiles\"}}]}"
}
EOF
)

  log_info "Creating Lambda Performance dashboard..."
  local dashboard_name="bedrock-agents-${ENVIRONMENT}-lambda-performance"
  echo "${lambda_dashboard}" | sed "s/ENV/${ENVIRONMENT}/g" > /tmp/dashboard.json

  aws cloudwatch put-dashboard \
    --dashboard-name "${dashboard_name}" \
    --dashboard-body file:///tmp/dashboard.json \
    --region us-east-1 || {
    log_error "Failed to create Lambda dashboard"
    return 1
  }

  log_success "Created dashboard: ${dashboard_name}"

  # Create API Gateway Dashboard
  local api_dashboard_name="bedrock-agents-${ENVIRONMENT}-api-gateway"
  log_info "Creating API Gateway dashboard..."

  aws cloudwatch put-dashboard \
    --dashboard-name "${api_dashboard_name}" \
    --dashboard-body '{"widgets":[{"type":"metric","properties":{"metrics":[["AWS/ApiGateway","Count"],[".",\"4XXError\"],[".","5XXError"],[".",\"Latency"]],"period":300,"stat":"Sum","region":"eu-west-2","title":"API Gateway Metrics"}}]}' \
    --region us-east-1 || {
    log_error "Failed to create API Gateway dashboard"
    return 1
  }

  log_success "Created dashboard: ${api_dashboard_name}"

  # Create Bedrock Agents Dashboard
  local agents_dashboard_name="bedrock-agents-${ENVIRONMENT}-agents"
  log_info "Creating Agents Performance dashboard..."

  aws cloudwatch put-dashboard \
    --dashboard-name "${agents_dashboard_name}" \
    --dashboard-body '{"widgets":[{"type":"metric","properties":{"metrics":[["AWS/BedrockAgents","InvocationCount"],[".",\"InvocationErrors"],[".",\"AverageLatency"]],"period":300,"stat":"Average","region":"eu-west-2","title":"Agent Performance"}}]}' \
    --region us-east-1 || {
    log_error "Failed to create Agents dashboard"
    return 1
  }

  log_success "Created dashboard: ${agents_dashboard_name}"

  log_success "All dashboards created successfully"
}

list_dashboards() {
  log_info "Listing CloudWatch dashboards for environment: ${ENVIRONMENT}"

  local dashboards=$(aws cloudwatch list-dashboards \
    --region us-east-1 \
    --query "DashboardEntries[?contains(DashboardName, '${ENVIRONMENT}')].{Name:DashboardName,LastModified:LastModified}" \
    --output table)

  if [ -z "${dashboards}" ]; then
    log_warning "No dashboards found for environment: ${ENVIRONMENT}"
    return 0
  fi

  echo "${dashboards}"
}

delete_dashboard() {
  local dashboard_name=$1

  log_info "Deleting dashboard: ${dashboard_name}"

  if [ "${DRY_RUN}" = true ]; then
    log_warning "DRY RUN: Would delete dashboard"
    return 0
  fi

  aws cloudwatch delete-dashboards \
    --dashboard-names "${dashboard_name}" \
    --region us-east-1 || {
    log_error "Failed to delete dashboard"
    return 1
  }

  log_success "Dashboard deleted: ${dashboard_name}"
}

################################################################################
# Main
################################################################################

main() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -e|--environment) ENVIRONMENT="$2"; shift 2 ;;
      -c|--create) CREATE=true; shift ;;
      -u|--update) UPDATE=true; shift ;;
      -l|--list) LIST=true; shift ;;
      -d|--delete) DELETE="$2"; shift 2 ;;
      --dry-run) DRY_RUN=true; shift ;;
      -h|--help) head -n 35 "$0" | tail -n +4; exit 0 ;;
      *) log_error "Unknown option: $1"; exit 1 ;;
    esac
  done

  log_info "CloudWatch Dashboards Setup"
  check_prerequisites

  if [ "${LIST}" = true ]; then
    if [ -z "${ENVIRONMENT}" ]; then
      log_error "Environment required for listing"
      exit 1
    fi
    list_dashboards
  elif [ -n "${DELETE}" ]; then
    delete_dashboard "${DELETE}"
  elif [ "${CREATE}" = true ] || [ "${UPDATE}" = true ]; then
    if [ -z "${ENVIRONMENT}" ]; then
      log_error "Environment required"
      exit 1
    fi
    create_dashboards
  else
    log_error "Please specify an action: -c, -u, -l, or -d"
    exit 1
  fi
}

main "$@"
