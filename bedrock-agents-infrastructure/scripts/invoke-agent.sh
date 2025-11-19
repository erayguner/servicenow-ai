#!/bin/bash

################################################################################
# Bedrock Agents - Test Invocation Script
#
# Interactive CLI for testing Bedrock agents with session management
# and response formatting.
#
# Usage:
#   ./invoke-agent.sh [OPTIONS]
#
# Options:
#   -e, --environment ENV      Environment: dev, staging, or prod (default: dev)
#   -a, --agent AGENT_NAME     Agent name to invoke
#   -m, --message MESSAGE      User message/prompt
#   --session-id ID            Use specific session ID
#   --new-session              Start a new session
#   --list-agents              List available agents
#   --list-sessions            List active sessions
#   -f, --format FORMAT        Output format: json, text, or table (default: text)
#   --timeout SECONDS          Invocation timeout in seconds (default: 30)
#   -h, --help                 Show this help message
#
# Examples:
#   ./invoke-agent.sh --list-agents
#   ./invoke-agent.sh -a "policy-advisor" -m "What is the return policy?"
#   ./invoke-agent.sh -a "support-agent" --new-session
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
STATE_DIR="${PROJECT_ROOT}/.agent-state"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/agent_invocation_${TIMESTAMP}.log"

# Default values
ENVIRONMENT="dev"
AGENT_NAME=""
USER_MESSAGE=""
SESSION_ID=""
NEW_SESSION=false
LIST_AGENTS=false
LIST_SESSIONS=false
OUTPUT_FORMAT="text"
TIMEOUT=30
INTERACTIVE=false

# Ensure directories exist
mkdir -p "${LOG_DIR}" "${STATE_DIR}"

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
  head -n 35 "$0" | tail -n +4
}

check_prerequisites() {
  local missing_tools=()

  for tool in aws jq python3; do
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

  log_debug "Prerequisites verified"
}

################################################################################
# Session Management
################################################################################

generate_session_id() {
  echo "sess_$(date +%s)_$(openssl rand -hex 4 2>/dev/null || head -c 8 /dev/urandom | od -An -tx1 | tr -d ' ')"
}

get_session_file() {
  local session_id=$1
  echo "${STATE_DIR}/session_${session_id}.json"
}

create_session() {
  if [ "${NEW_SESSION}" = true ] || [ -z "${SESSION_ID}" ]; then
    SESSION_ID=$(generate_session_id)
    log_info "Created new session: ${SESSION_ID}"
  fi

  local session_file=$(get_session_file "${SESSION_ID}")

  # Initialize session file if it doesn't exist
  if [ ! -f "${session_file}" ]; then
    cat > "${session_file}" <<EOF
{
  "session_id": "${SESSION_ID}",
  "agent": "${AGENT_NAME}",
  "environment": "${ENVIRONMENT}",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "last_updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "message_count": 0,
  "messages": []
}
EOF
    log_debug "Session file created: ${session_file}"
  fi
}

list_active_sessions() {
  print_header "Active Agent Sessions"
  print_separator

  if [ ! -d "${STATE_DIR}" ] || [ -z "$(ls -A ${STATE_DIR})" ]; then
    log_info "No active sessions found"
    return
  fi

  echo -e "${CYAN}Session ID${NC}\t\t${CYAN}Agent${NC}\t\t${CYAN}Environment${NC}\t${CYAN}Created${NC}"
  print_separator

  for session_file in "${STATE_DIR}"/session_*.json; do
    if [ -f "${session_file}" ]; then
      local session_data=$(cat "${session_file}")
      local sess_id=$(echo "${session_data}" | jq -r '.session_id')
      local agent=$(echo "${session_data}" | jq -r '.agent')
      local env=$(echo "${session_data}" | jq -r '.environment')
      local created=$(echo "${session_data}" | jq -r '.created_at')

      printf "${sess_id}\t${agent}\t${env}\t${created}\n"
    fi
  done
}

################################################################################
# Agent Operations
################################################################################

list_available_agents() {
  print_header "Available Agents"
  print_separator

  # Get agents from AWS (requires Bedrock to be configured)
  local agents_json=$(aws bedrock-agents list-agents \
    --region us-east-1 \
    --output json 2>/dev/null || echo '{"agentSummaries":[]}')

  local agent_count=$(echo "${agents_json}" | jq '.agentSummaries | length')

  if [ "${agent_count}" -eq 0 ]; then
    log_warning "No agents found in this environment"
    return 1
  fi

  echo "${agents_json}" | jq -r '.agentSummaries[] |
    "\(.agentName)\t\(.agentStatus)\t\(.agentVersion)\t\(.description // "N/A")"' | \
    column -t -s $'\t'

  log_info "Total agents: ${agent_count}"
}

get_agent_info() {
  local agent_name=$1

  log_info "Fetching information for agent: ${agent_name}"

  # This would typically query the actual agent configuration
  # For now, returning a formatted response

  echo -e "${CYAN}Agent Information${NC}"
  print_separator
  echo "Name:        ${agent_name}"
  echo "Environment: ${ENVIRONMENT}"
  echo "Status:      AVAILABLE"
  echo "Version:     1.0.0"
}

invoke_agent() {
  local agent_name=$1
  local message=$2

  log_info "Invoking agent: ${agent_name}"
  log_debug "Message: ${message}"

  # Create session first if needed
  create_session

  # Build the invocation request
  local request=$(cat <<EOF
{
  "agent_name": "${agent_name}",
  "session_id": "${SESSION_ID}",
  "message": "${message}",
  "environment": "${ENVIRONMENT}",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
)

  log_debug "Request: ${request}"

  # Invoke the agent via Lambda or API Gateway
  # This is a placeholder that would call the actual invocation endpoint

  local response=$(invoke_agent_endpoint "${agent_name}" "${message}" "${SESSION_ID}")

  # Update session
  update_session_with_message "${SESSION_ID}" "${message}" "${response}"

  # Format and display response
  display_response "${response}"
}

invoke_agent_endpoint() {
  local agent_name=$1
  local message=$2
  local session_id=$3

  # Construct the API endpoint (would be different based on your setup)
  local api_endpoint="https://api.bedrock.amazonaws.com"

  # Mock response for demonstration
  local response=$(cat <<EOF
{
  "session_id": "${session_id}",
  "agent_name": "${agent_name}",
  "status": "success",
  "response": "This is a response from the ${agent_name} agent regarding: ${message}",
  "confidence": 0.95,
  "processing_time_ms": 245,
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
)

  echo "${response}"
}

update_session_with_message() {
  local session_id=$1
  local user_message=$2
  local agent_response=$3

  local session_file=$(get_session_file "${session_id}")

  if [ ! -f "${session_file}" ]; then
    return
  fi

  # Parse existing session
  local session_data=$(cat "${session_file}")
  local message_count=$(echo "${session_data}" | jq '.message_count')

  # Add new message pair
  local updated_data=$(echo "${session_data}" | jq \
    --arg user_msg "${user_message}" \
    --arg agent_resp "${agent_response}" \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '.messages += [{
      "id": (.message_count + 1),
      "user_message": $user_msg,
      "agent_response": $agent_resp,
      "timestamp": $ts
    }] | .message_count += 1 | .last_updated = $ts')

  echo "${updated_data}" > "${session_file}"

  log_debug "Session updated with message pair"
}

################################################################################
# Response Formatting
################################################################################

display_response() {
  local response_json=$1

  case "${OUTPUT_FORMAT}" in
    json)
      echo "${response_json}" | jq '.'
      ;;
    text)
      display_response_text "${response_json}"
      ;;
    table)
      display_response_table "${response_json}"
      ;;
    *)
      log_error "Unknown output format: ${OUTPUT_FORMAT}"
      ;;
  esac
}

display_response_text() {
  local response_json=$1

  print_header "Agent Response"
  print_separator

  local agent_name=$(echo "${response_json}" | jq -r '.agent_name // "Unknown"')
  local status=$(echo "${response_json}" | jq -r '.status // "Unknown"')
  local response_text=$(echo "${response_json}" | jq -r '.response // "No response"')
  local confidence=$(echo "${response_json}" | jq -r '.confidence // 0')
  local processing_time=$(echo "${response_json}" | jq -r '.processing_time_ms // 0')

  echo -e "${CYAN}Agent:${NC} ${agent_name}"
  echo -e "${CYAN}Status:${NC} ${status}"
  echo -e "${CYAN}Confidence:${NC} ${confidence}"
  echo -e "${CYAN}Processing Time:${NC} ${processing_time}ms"
  print_separator
  echo -e "${CYAN}Response:${NC}"
  echo "${response_text}"
  print_separator
}

display_response_table() {
  local response_json=$1

  # Create a simple table view
  echo "${response_json}" | jq -r '
    "Field\tValue\n" +
    "-----\t-----\n" +
    "Agent\t\(.agent_name // "N/A")\n" +
    "Status\t\(.status // "N/A")\n" +
    "Confidence\t\(.confidence // "N/A")\n" +
    "Processing Time\t\(.processing_time_ms // "N/A")ms"
  ' | column -t -s $'\t'
}

################################################################################
# Interactive Mode
################################################################################

interactive_mode() {
  if [ -z "${AGENT_NAME}" ]; then
    print_header "Bedrock Agent Tester - Interactive Mode"
    print_separator

    log_info "Available agents:"
    list_available_agents || true

    read -p "Enter agent name: " AGENT_NAME

    if [ -z "${AGENT_NAME}" ]; then
      log_error "Agent name cannot be empty"
      return 1
    fi
  fi

  create_session

  print_header "Interactive Session with ${AGENT_NAME}"
  print_separator
  log_info "Session ID: ${SESSION_ID}"
  log_info "Type 'exit' or 'quit' to end the session"
  print_separator

  while true; do
    read -p "${AGENT_NAME}> " user_input

    case "${user_input}" in
      exit|quit)
        log_info "Ending session"
        break
        ;;
      "")
        continue
        ;;
      *)
        invoke_agent_endpoint "${AGENT_NAME}" "${user_input}" "${SESSION_ID}" | display_response_text
        ;;
    esac
  done

  log_success "Session ended"
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
      -a|--agent)
        AGENT_NAME="$2"
        shift 2
        ;;
      -m|--message)
        USER_MESSAGE="$2"
        shift 2
        ;;
      --session-id)
        SESSION_ID="$2"
        shift 2
        ;;
      --new-session)
        NEW_SESSION=true
        shift
        ;;
      --list-agents)
        LIST_AGENTS=true
        shift
        ;;
      --list-sessions)
        LIST_SESSIONS=true
        shift
        ;;
      -f|--format)
        OUTPUT_FORMAT="$2"
        shift 2
        ;;
      --timeout)
        TIMEOUT="$2"
        shift 2
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

  log_info "Bedrock Agent Invocation Tool"
  log_info "Environment: ${ENVIRONMENT}"
  log_info "Log file: ${LOG_FILE}"

  # Check prerequisites
  check_prerequisites

  # Handle list operations
  if [ "${LIST_AGENTS}" = true ]; then
    list_available_agents || true
    exit 0
  fi

  if [ "${LIST_SESSIONS}" = true ]; then
    list_active_sessions
    exit 0
  fi

  # Handle agent invocation
  if [ -n "${AGENT_NAME}" ] && [ -n "${USER_MESSAGE}" ]; then
    invoke_agent "${AGENT_NAME}" "${USER_MESSAGE}"
    log_success "Agent invocation completed"
  elif [ -n "${AGENT_NAME}" ]; then
    # Single agent, interactive mode
    interactive_mode
  else
    # Interactive mode without specified agent
    INTERACTIVE=true
    interactive_mode
  fi
}

# Execute main function
main "$@"
