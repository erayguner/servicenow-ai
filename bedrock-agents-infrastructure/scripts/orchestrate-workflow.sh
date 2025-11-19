#!/bin/bash

################################################################################
# Bedrock Agents - Step Functions Workflow Orchestration
#
# This script manages Step Functions workflows for orchestrating complex
# multi-agent workflows and monitoring execution progress.
#
# Usage:
#   ./orchestrate-workflow.sh [OPTIONS]
#
# Options:
#   -e, --environment ENV         Environment: dev, staging, or prod (default: dev)
#   -w, --workflow NAME           Workflow name to execute
#   -i, --input FILE              JSON input file for workflow
#   --list-workflows              List available workflows
#   --start-execution             Start a new workflow execution
#   --get-execution EXEC_ID       Get execution details
#   --list-executions             List recent executions
#   --monitor EXEC_ID             Monitor execution in real-time
#   --describe-workflow           Get workflow definition
#   --timeout SECONDS             Execution timeout in seconds (default: 300)
#   --dry-run                     Show execution plan without running
#   -h, --help                    Show this help message
#
# Examples:
#   ./orchestrate-workflow.sh --list-workflows
#   ./orchestrate-workflow.sh -w "multi-agent-support" -i input.json
#   ./orchestrate-workflow.sh --monitor "arn:aws:states:..."
#
################################################################################

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LOG_DIR="${PROJECT_ROOT}/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/workflow_${TIMESTAMP}.log"

# Default values
ENVIRONMENT="dev"
WORKFLOW_NAME=""
INPUT_FILE=""
EXECUTION_ID=""
LIST_WORKFLOWS=false
START_EXECUTION=false
GET_EXECUTION=false
LIST_EXECUTIONS=false
MONITOR=false
DESCRIBE_WORKFLOW=false
TIMEOUT=300
DRY_RUN=false

# Ensure logs directory exists
mkdir -p "${LOG_DIR}"

################################################################################
# Logging Functions
################################################################################

log_info() {
  echo -e "${BLUE}[INFO]${NC} $*" | tee -a "${LOG_FILE}"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "${LOG_FILE}"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $*" | tee -a "${LOG_FILE}"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $*" | tee -a "${LOG_FILE}"
}

log_debug() {
  echo -e "${MAGENTA}[DEBUG]${NC} $*" | tee -a "${LOG_FILE}"
}

print_header() {
  echo -e "${CYAN}$*${NC}"
}

print_separator() {
  echo "=================================================="
}

################################################################################
# Utility Functions
################################################################################

show_help() {
  head -n 40 "$0" | tail -n +4
}

check_prerequisites() {
  log_info "Checking prerequisites..."

  local missing_tools=()

  for tool in aws jq; do
    if ! command -v "$tool" &> /dev/null; then
      missing_tools+=("$tool")
    fi
  done

  if [ ${#missing_tools[@]} -gt 0 ]; then
    log_error "Missing required tools: ${missing_tools[*]}"
    exit 1
  fi

  # Check AWS credentials
  if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS credentials not configured or invalid"
    exit 1
  fi

  log_success "Prerequisites verified"
}

get_state_machine_arn() {
  local workflow_name=$1

  # List state machines and find the one matching our workflow
  local arn=$(aws stepfunctions list-state-machines \
    --region us-east-1 \
    --query "stateMachines[?contains(name, '${workflow_name}')].stateMachineArn" \
    --output text 2>/dev/null | head -1)

  if [ -z "${arn}" ]; then
    log_error "State machine not found for workflow: ${workflow_name}"
    return 1
  fi

  echo "${arn}"
}

################################################################################
# Workflow Management Functions
################################################################################

list_available_workflows() {
  print_header "Available Workflows"
  print_separator

  local workflows=$(aws stepfunctions list-state-machines \
    --region us-east-1 \
    --output json)

  local count=$(echo "${workflows}" | jq '.stateMachines | length')

  if [ "${count}" -eq 0 ]; then
    log_warning "No workflows found"
    return 1
  fi

  echo -e "${CYAN}Workflow Name${NC}\t\t${CYAN}ARN${NC}\t\t${CYAN}Status${NC}\t${CYAN}Created${NC}"
  print_separator

  echo "${workflows}" | jq -r '.stateMachines[] |
    "\(.name)\t\(.stateMachineArn)\t\(.status)\t\(.creationDate)"' | \
    while IFS=$'\t' read -r name arn status created; do
      printf "%-30s %-70s %-10s %s\n" "${name}" "${arn}" "${status}" "${created}"
    done

  log_info "Total workflows: ${count}"
}

describe_workflow() {
  local workflow_name=$1

  log_info "Getting workflow definition for: ${workflow_name}"

  local arn=$(get_state_machine_arn "${workflow_name}") || return 1

  local definition=$(aws stepfunctions describe-state-machine \
    --state-machine-arn "${arn}" \
    --region us-east-1 \
    --output json)

  print_header "Workflow Definition: ${workflow_name}"
  print_separator

  echo "${definition}" | jq '.definition | fromjson' 2>/dev/null || \
    echo "${definition}" | jq '.definition'
}

validate_workflow_input() {
  local input_file=$1

  if [ ! -f "${input_file}" ]; then
    log_error "Input file not found: ${input_file}"
    return 1
  fi

  # Validate JSON format
  if ! jq empty "${input_file}" 2>/dev/null; then
    log_error "Invalid JSON in input file: ${input_file}"
    return 1
  fi

  log_success "Input file validated"
}

start_workflow_execution() {
  local workflow_name=$1
  local input_file=$2

  log_info "Starting workflow execution: ${workflow_name}"

  local arn=$(get_state_machine_arn "${workflow_name}") || return 1

  # Validate input if provided
  local input_json=""
  if [ -n "${input_file}" ]; then
    validate_workflow_input "${input_file}" || return 1
    input_json=$(cat "${input_file}")
  else
    input_json="{}"
  fi

  if [ "${DRY_RUN}" = true ]; then
    log_warning "DRY RUN: Would start execution"
    log_info "Workflow ARN: ${arn}"
    log_info "Input: ${input_json}"
    return 0
  fi

  # Start execution
  local execution_response=$(aws stepfunctions start-execution \
    --state-machine-arn "${arn}" \
    --name "execution-${TIMESTAMP}" \
    --input "${input_json}" \
    --region us-east-1 \
    --output json)

  local execution_arn=$(echo "${execution_response}" | jq -r '.executionArn')

  if [ -z "${execution_arn}" ] || [ "${execution_arn}" = "null" ]; then
    log_error "Failed to start workflow execution"
    return 1
  fi

  log_success "Workflow execution started"
  log_info "Execution ARN: ${execution_arn}"

  echo "${execution_arn}"
}

list_workflow_executions() {
  local workflow_name=$1

  log_info "Listing executions for workflow: ${workflow_name}"

  local arn=$(get_state_machine_arn "${workflow_name}") || return 1

  print_header "Workflow Executions: ${workflow_name}"
  print_separator

  local executions=$(aws stepfunctions list-executions \
    --state-machine-arn "${arn}" \
    --region us-east-1 \
    --max-items 20 \
    --output json)

  local count=$(echo "${executions}" | jq '.executions | length')

  if [ "${count}" -eq 0 ]; then
    log_warning "No executions found"
    return 0
  fi

  echo -e "${CYAN}Execution ID${NC}\t${CYAN}Status${NC}\t${CYAN}Start Time${NC}\t${CYAN}Duration${NC}"
  print_separator

  echo "${executions}" | jq -r '.executions[] |
    "\(.name)\t\(.status)\t\(.startDate)\t\(.executionArn)"' | \
    while IFS=$'\t' read -r name status start_time arn; do
      printf "%-40s %-15s %-20s\n" "${name}" "${status}" "${start_time}"
    done

  log_info "Total executions shown: ${count}"
}

get_execution_details() {
  local execution_arn=$1

  log_info "Getting execution details: ${execution_arn}"

  local execution=$(aws stepfunctions describe-execution \
    --execution-arn "${execution_arn}" \
    --region us-east-1 \
    --output json)

  print_header "Execution Details"
  print_separator

  local status=$(echo "${execution}" | jq -r '.status')
  local start_time=$(echo "${execution}" | jq -r '.startDate')
  local stop_time=$(echo "${execution}" | jq -r '.stopDate // "N/A"')
  local input=$(echo "${execution}" | jq -r '.input')
  local output=$(echo "${execution}" | jq -r '.output // "N/A"')

  echo -e "${CYAN}Status:${NC} ${status}"
  echo -e "${CYAN}Start Time:${NC} ${start_time}"
  echo -e "${CYAN}Stop Time:${NC} ${stop_time}"
  print_separator

  echo -e "${CYAN}Input:${NC}"
  echo "${input}" | jq '.' 2>/dev/null || echo "${input}"

  print_separator
  echo -e "${CYAN}Output:${NC}"
  echo "${output}" | jq '.' 2>/dev/null || echo "${output}"
}

monitor_execution() {
  local execution_arn=$1
  local check_interval=5
  local elapsed=0

  log_info "Monitoring execution: ${execution_arn}"
  print_separator

  while true; do
    local execution=$(aws stepfunctions describe-execution \
      --execution-arn "${execution_arn}" \
      --region us-east-1 \
      --output json)

    local status=$(echo "${execution}" | jq -r '.status')
    local elapsed_display=$(printf "%02d:%02d" $((elapsed/60)) $((elapsed%60)))

    case "${status}" in
      SUCCEEDED)
        log_success "[${elapsed_display}] Execution succeeded"
        echo ""
        get_execution_details "${execution_arn}"
        break
        ;;
      FAILED)
        log_error "[${elapsed_display}] Execution failed"
        local cause=$(echo "${execution}" | jq -r '.cause // "Unknown"')
        local error=$(echo "${execution}" | jq -r '.error // "Unknown"')
        echo -e "${RED}Error:${NC} ${error}"
        echo -e "${RED}Cause:${NC} ${cause}"
        echo ""
        get_execution_details "${execution_arn}"
        break
        ;;
      TIMED_OUT)
        log_error "[${elapsed_display}] Execution timed out"
        break
        ;;
      ABORTED)
        log_warning "[${elapsed_display}] Execution aborted"
        break
        ;;
      RUNNING)
        echo -ne "\r${BLUE}[${elapsed_display}] Execution in progress...${NC}"
        ;;
    esac

    # Check timeout
    if [ ${elapsed} -ge ${TIMEOUT} ]; then
      log_error "Timeout waiting for execution (${TIMEOUT}s)"
      break
    fi

    sleep ${check_interval}
    ((elapsed += check_interval))
  done
}

get_execution_history() {
  local execution_arn=$1

  log_info "Fetching execution history: ${execution_arn}"

  local history=$(aws stepfunctions get-execution-history \
    --execution-arn "${execution_arn}" \
    --region us-east-1 \
    --output json)

  print_header "Execution History"
  print_separator

  echo -e "${CYAN}Event${NC}\t${CYAN}Type${NC}\t${CYAN}Timestamp${NC}\t${CYAN}Details${NC}"
  print_separator

  echo "${history}" | jq -r '.events[] |
    "\(.id)\t\(.type)\t\(.timestamp)\t\(.stateEnteredEventDetails.name // .executionFailedEventDetails.error // "")"' | \
    while IFS=$'\t' read -r id type timestamp details; do
      printf "%-5s %-40s %-25s\n" "${id}" "${type}" "${timestamp}"
      [ -n "${details}" ] && printf "  └─ %s\n" "${details}"
    done
}

################################################################################
# Main Execution
################################################################################

main() {
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -e|--environment)
        ENVIRONMENT="$2"
        shift 2
        ;;
      -w|--workflow)
        WORKFLOW_NAME="$2"
        shift 2
        ;;
      -i|--input)
        INPUT_FILE="$2"
        shift 2
        ;;
      --list-workflows)
        LIST_WORKFLOWS=true
        shift
        ;;
      --start-execution)
        START_EXECUTION=true
        shift
        ;;
      --get-execution)
        GET_EXECUTION=true
        EXECUTION_ID="$2"
        shift 2
        ;;
      --list-executions)
        LIST_EXECUTIONS=true
        shift
        ;;
      --monitor)
        MONITOR=true
        EXECUTION_ID="$2"
        shift 2
        ;;
      --describe-workflow)
        DESCRIBE_WORKFLOW=true
        shift
        ;;
      --timeout)
        TIMEOUT="$2"
        shift 2
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      -h|--help)
        show_help
        exit 0
        ;;
      *)
        log_error "Unknown option: $1"
        show_help
        exit 1
        ;;
    esac
  done

  log_info "Bedrock Agents Workflow Orchestration"
  log_info "Environment: ${ENVIRONMENT}"
  log_info "Log file: ${LOG_FILE}"

  check_prerequisites

  # Handle different operations
  if [ "${LIST_WORKFLOWS}" = true ]; then
    list_available_workflows
  elif [ "${LIST_EXECUTIONS}" = true ]; then
    if [ -z "${WORKFLOW_NAME}" ]; then
      log_error "Workflow name required for listing executions"
      exit 1
    fi
    list_workflow_executions "${WORKFLOW_NAME}"
  elif [ "${DESCRIBE_WORKFLOW}" = true ]; then
    if [ -z "${WORKFLOW_NAME}" ]; then
      log_error "Workflow name required"
      exit 1
    fi
    describe_workflow "${WORKFLOW_NAME}"
  elif [ "${START_EXECUTION}" = true ]; then
    if [ -z "${WORKFLOW_NAME}" ]; then
      log_error "Workflow name required"
      exit 1
    fi
    EXECUTION_ID=$(start_workflow_execution "${WORKFLOW_NAME}" "${INPUT_FILE}") || exit 1

    if [ "${MONITOR}" = false ] && [ "${DRY_RUN}" = false ]; then
      log_success "Execution started. Use --monitor to watch progress"
      log_info "Execution ARN: ${EXECUTION_ID}"
    fi
  elif [ "${GET_EXECUTION}" = true ]; then
    if [ -z "${EXECUTION_ID}" ]; then
      log_error "Execution ID required"
      exit 1
    fi
    get_execution_details "${EXECUTION_ID}"
  elif [ "${MONITOR}" = true ]; then
    if [ -z "${EXECUTION_ID}" ]; then
      log_error "Execution ID required for monitoring"
      exit 1
    fi
    monitor_execution "${EXECUTION_ID}"
  else
    log_warning "No operation specified. Use -h for help"
    show_help
  fi
}

# Execute main function
main "$@"
