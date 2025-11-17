#!/bin/bash

################################################################################
# Bedrock Agents - Cost Analysis
#
# Analyzes and reports on AWS resource costs for Bedrock agents infrastructure.
#
# Usage:
#   ./cost-analysis.sh [OPTIONS]
#
# Options:
#   -e, --environment ENV      Environment: dev, staging, or prod
#   -m, --month MONTH          Month to analyze (YYYY-MM)
#   -s, --service SERVICE      Service: bedrock, lambda, s3, all
#   -o, --output FILE          Output file for report
#   -h, --help                 Show this help message
#
# Examples:
#   ./cost-analysis.sh -e prod -m 2024-11
#   ./cost-analysis.sh -e dev -s bedrock
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
LOG_FILE="${LOG_DIR}/cost_analysis_${TIMESTAMP}.log"

ENVIRONMENT=""
MONTH=$(date +%Y-%m)
SERVICE="all"
OUTPUT_FILE="${PROJECT_ROOT}/cost_analysis_${TIMESTAMP}.txt"

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

analyze_lambda_costs() {
  log_info "Analyzing Lambda costs for ${MONTH}..."

  echo "Lambda Cost Analysis - ${MONTH}" >> "${OUTPUT_FILE}"
  echo "======================================" >> "${OUTPUT_FILE}"

  # Get Lambda invocation metrics
  local start_date="${MONTH}-01"
  local end_date=$(date -d "${MONTH}-01 +1 month" +%Y-%m-%d)

  aws lambda list-functions \
    --query "Functions[?Tags.Environment=='${ENVIRONMENT}'].FunctionName" \
    --output text | tr '\t' '\n' | while read -r func; do
    [ -z "${func}" ] && continue

    echo "Function: ${func}" >> "${OUTPUT_FILE}"

    aws cloudwatch get-metric-statistics \
      --namespace "AWS/Lambda" \
      --metric-name "Invocations" \
      --dimensions Name=FunctionName,Value="${func}" \
      --start-time "${start_date}T00:00:00Z" \
      --end-time "${end_date}T00:00:00Z" \
      --period 86400 \
      --statistics Sum \
      --region us-east-1 \
      --query 'Datapoints[0].Sum' \
      --output text >> "${OUTPUT_FILE}"

    echo "" >> "${OUTPUT_FILE}"
  done

  log_success "Lambda costs analyzed"
}

analyze_bedrock_costs() {
  log_info "Analyzing Bedrock API costs for ${MONTH}..."

  echo "Bedrock API Cost Analysis - ${MONTH}" >> "${OUTPUT_FILE}"
  echo "======================================" >> "${OUTPUT_FILE}"
  echo "Note: Detailed costs require AWS Cost Explorer API or Billing API" >> "${OUTPUT_FILE}"
  echo "" >> "${OUTPUT_FILE}"

  log_success "Bedrock costs analyzed"
}

generate_cost_report() {
  log_info "Generating cost analysis report..."

  cat > "${OUTPUT_FILE}" <<EOF
Bedrock Agents - Cost Analysis Report
=====================================
Environment: ${ENVIRONMENT}
Period: ${MONTH}
Generated: $(date)

EOF

  case "${SERVICE}" in
    lambda) analyze_lambda_costs ;;
    bedrock) analyze_bedrock_costs ;;
    all)
      analyze_lambda_costs
      analyze_bedrock_costs
      ;;
  esac

  cat >> "${OUTPUT_FILE}" <<EOF

Summary
=======
- Report generated: $(date)
- Environment: ${ENVIRONMENT}
- Period: ${MONTH}

For detailed cost analysis, use AWS Cost Explorer:
https://console.aws.amazon.com/cost-management/home
EOF

  log_success "Cost report generated: ${OUTPUT_FILE}"
  cat "${OUTPUT_FILE}"
}

main() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -e|--environment) ENVIRONMENT="$2"; shift 2 ;;
      -m|--month) MONTH="$2"; shift 2 ;;
      -s|--service) SERVICE="$2"; shift 2 ;;
      -o|--output) OUTPUT_FILE="$2"; shift 2 ;;
      -h|--help) head -n 35 "$0" | tail -n +4; exit 0 ;;
      *) log_error "Unknown option: $1"; exit 1 ;;
    esac
  done

  [ -z "${ENVIRONMENT}" ] && { log_error "Environment required"; exit 1; }

  check_prerequisites
  generate_cost_report
}

main "$@"
