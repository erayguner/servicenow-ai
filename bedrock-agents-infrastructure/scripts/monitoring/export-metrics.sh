#!/bin/bash

################################################################################
# Bedrock Agents - Metrics Export
#
# Exports CloudWatch metrics to CSV for analysis and reporting.
#
# Usage:
#   ./export-metrics.sh [OPTIONS]
#
# Options:
#   -e, --environment ENV      Environment: dev, staging, or prod
#   -m, --metric METRIC        Metric to export (lambda, api, agents, all)
#   -s, --start-time TIME      Start time (default: 24 hours ago)
#   -e, --end-time TIME        End time (default: now)
#   -o, --output FILE          Output CSV file
#   -h, --help                 Show this help message
#
# Examples:
#   ./export-metrics.sh -e dev -m lambda
#   ./export-metrics.sh -e prod -m all -o metrics.csv
#
################################################################################

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
LOG_DIR="${PROJECT_ROOT}/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/metrics_export_${TIMESTAMP}.log"

ENVIRONMENT=""
METRIC="all"
START_TIME=""
END_TIME=""
OUTPUT_FILE="${PROJECT_ROOT}/metrics_${TIMESTAMP}.csv"

mkdir -p "${LOG_DIR}"

log_info() { echo -e "${BLUE}[INFO]${NC} $*" | tee -a "${LOG_FILE}"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "${LOG_FILE}"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" | tee -a "${LOG_FILE}"; }

check_prerequisites() {
  if ! command -v aws &> /dev/null; then
    log_error "AWS CLI required"
    exit 1
  fi

  if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS credentials not configured"
    exit 1
  fi
}

export_lambda_metrics() {
  log_info "Exporting Lambda metrics..."

  local start_time=${START_TIME:-$(date -d '24 hours ago' -u +%Y-%m-%dT%H:%M:%S)}
  local end_time=${END_TIME:-$(date -u +%Y-%m-%dT%H:%M:%S)}

  # Create CSV header
  echo "Timestamp,Metric,Value,Unit" > "${OUTPUT_FILE}"

  # Query metrics
  aws cloudwatch get-metric-statistics \
    --namespace "AWS/Lambda" \
    --metric-name "Duration" \
    --start-time "${start_time}" \
    --end-time "${end_time}" \
    --period 300 \
    --statistics Average,Maximum \
    --region us-east-1 \
    --query 'Datapoints[].{Time:Timestamp,Avg:Average,Max:Maximum}' \
    --output json | jq -r '.[] | "\(.Time),Duration,\(.Avg),ms"' >> "${OUTPUT_FILE}"

  log_success "Lambda metrics exported"
}

export_all_metrics() {
  log_info "Exporting all metrics..."
  export_lambda_metrics
  log_success "Metrics exported to: ${OUTPUT_FILE}"
}

main() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -e|--environment) ENVIRONMENT="$2"; shift 2 ;;
      -m|--metric) METRIC="$2"; shift 2 ;;
      -s|--start-time) START_TIME="$2"; shift 2 ;;
      --end-time) END_TIME="$2"; shift 2 ;;
      -o|--output) OUTPUT_FILE="$2"; shift 2 ;;
      -h|--help) head -n 35 "$0" | tail -n +4; exit 0 ;;
      *) log_error "Unknown option: $1"; exit 1 ;;
    esac
  done

  [ -z "${ENVIRONMENT}" ] && { log_error "Environment required"; exit 1; }

  check_prerequisites

  case "${METRIC}" in
    lambda) export_lambda_metrics ;;
    all) export_all_metrics ;;
    *) log_error "Unknown metric type: ${METRIC}"; exit 1 ;;
  esac
}

main "$@"
