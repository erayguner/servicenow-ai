#!/bin/bash

################################################################################
# Bedrock Agents Infrastructure - Main Deployment Script
#
# This script orchestrates the complete deployment process for Bedrock agents
# infrastructure including Terraform, Lambda functions, and agent configuration.
#
# Usage:
#   ./deploy.sh [OPTIONS]
#
# Options:
#   -e, --environment ENV    Environment: dev, staging, or prod (default: dev)
#   -d, --dry-run            Show what would be executed without applying changes
#   -l, --list-resources     List resources in current state
#   --skip-health-check      Skip health checks after deployment
#   --auto-approve           Auto-approve Terraform changes (use with caution)
#   -h, --help               Show this help message
#
# Examples:
#   ./deploy.sh -e dev
#   ./deploy.sh -e prod --auto-approve
#   ./deploy.sh -e staging --dry-run
#
################################################################################

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TERRAFORM_DIR="${PROJECT_ROOT}/terraform"
LOG_DIR="${PROJECT_ROOT}/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/deploy_${TIMESTAMP}.log"

# Default values
ENVIRONMENT="dev"
DRY_RUN=false
LIST_RESOURCES=false
SKIP_HEALTH_CHECK=false
AUTO_APPROVE=false

# Ensure logs directory exists
mkdir -p "${LOG_DIR}"

################################################################################
# Logging Functions
################################################################################

log() {
  local level=$1
  shift
  local message="$@"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

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

################################################################################
# Utility Functions
################################################################################

show_help() {
  head -n 30 "$0" | tail -n +4
}

validate_environment() {
  local env=$1
  case "$env" in
    dev|staging|prod)
      return 0
      ;;
    *)
      log_error "Invalid environment: $env. Must be dev, staging, or prod."
      exit 1
      ;;
  esac
}

check_prerequisites() {
  log_info "Checking prerequisites..."

  local missing_tools=()

  # Check required tools
  for tool in terraform aws python3 jq; do
    if ! command -v "$tool" &> /dev/null; then
      missing_tools+=("$tool")
    fi
  done

  if [ ${#missing_tools[@]} -gt 0 ]; then
    log_error "Missing required tools: ${missing_tools[*]}"
    log_error "Please install: https://docs.aws.amazon.com/bedrock/latest/userguide/getting-started.html"
    exit 1
  fi

  # Check AWS credentials
  if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS credentials not configured or invalid"
    exit 1
  fi

  log_success "All prerequisites met"
}

validate_terraform_config() {
  log_info "Validating Terraform configuration..."

  if [ ! -d "${TERRAFORM_DIR}" ]; then
    log_error "Terraform directory not found: ${TERRAFORM_DIR}"
    exit 1
  fi

  cd "${TERRAFORM_DIR}"
  terraform validate || {
    log_error "Terraform validation failed"
    exit 1
  }

  log_success "Terraform configuration valid"
}

################################################################################
# Deployment Functions
################################################################################

terraform_init() {
  log_info "Initializing Terraform for environment: ${ENVIRONMENT}..."

  cd "${TERRAFORM_DIR}"

  # Initialize Terraform
  terraform init \
    -backend-config="key=bedrock-agents/${ENVIRONMENT}/terraform.tfstate" \
    -upgrade || {
    log_error "Terraform init failed"
    exit 1
  }

  log_success "Terraform initialized"
}

terraform_plan() {
  log_info "Planning Terraform deployment for environment: ${ENVIRONMENT}..."

  cd "${TERRAFORM_DIR}"

  local plan_file="${LOG_DIR}/terraform_${ENVIRONMENT}_${TIMESTAMP}.tfplan"

  terraform plan \
    -var-file="environments/${ENVIRONMENT}.tfvars" \
    -out="${plan_file}" \
    -lock=true || {
    log_error "Terraform plan failed"
    exit 1
  }

  log_success "Terraform plan created: ${plan_file}"
  echo "${plan_file}"
}

terraform_apply() {
  local plan_file=$1

  if [ "${DRY_RUN}" = true ]; then
    log_warning "DRY RUN MODE: Skipping Terraform apply"
    log_info "Plan file available at: ${plan_file}"
    return 0
  fi

  log_info "Applying Terraform changes..."

  cd "${TERRAFORM_DIR}"

  local approve_flag=""
  if [ "${AUTO_APPROVE}" = true ]; then
    approve_flag="-auto-approve"
    log_warning "Auto-approve enabled - applying without confirmation"
  fi

  terraform apply ${approve_flag} "${plan_file}" || {
    log_error "Terraform apply failed"
    exit 1
  }

  log_success "Terraform apply completed"
}

deploy_lambdas() {
  log_info "Building and deploying Lambda functions..."

  local lambda_src="${PROJECT_ROOT}/lambda"

  if [ ! -d "${lambda_src}" ]; then
    log_warning "Lambda source directory not found: ${lambda_src}"
    return 0
  fi

  if [ "${DRY_RUN}" = true ]; then
    log_warning "DRY RUN MODE: Skipping Lambda deployment"
    return 0
  fi

  # Build and package Lambda functions
  for lambda_dir in "${lambda_src}"/*; do
    if [ -d "${lambda_dir}" ]; then
      local function_name=$(basename "${lambda_dir}")
      log_info "Deploying Lambda function: ${function_name}"

      # Build dependencies
      if [ -f "${lambda_dir}/requirements.txt" ]; then
        pip install -r "${lambda_dir}/requirements.txt" -t "${lambda_dir}/package" || {
          log_error "Failed to install dependencies for ${function_name}"
          continue
        }
      fi

      # Create deployment package
      cd "${lambda_dir}"
      zip -r "function.zip" . -x "*.git*" "*.gitignore" || {
        log_error "Failed to create deployment package for ${function_name}"
        continue
      }

      log_success "Built deployment package for ${function_name}"
    fi
  done
}

upload_agent_configs() {
  log_info "Uploading agent configurations..."

  local config_dir="${PROJECT_ROOT}/config/agents"

  if [ ! -d "${config_dir}" ]; then
    log_warning "Agent config directory not found: ${config_dir}"
    return 0
  fi

  if [ "${DRY_RUN}" = true ]; then
    log_warning "DRY RUN MODE: Skipping agent config upload"
    return 0
  fi

  # Get the S3 bucket name from Terraform outputs
  local bucket_name=$(cd "${TERRAFORM_DIR}" && terraform output -raw agent_config_bucket 2>/dev/null || echo "")

  if [ -z "${bucket_name}" ]; then
    log_warning "Could not determine agent config S3 bucket"
    return 0
  fi

  # Upload configurations
  for config_file in "${config_dir}"/*.json; do
    if [ -f "${config_file}" ]; then
      local filename=$(basename "${config_file}")
      log_info "Uploading: ${filename}"

      aws s3 cp "${config_file}" "s3://${bucket_name}/agents/" || {
        log_error "Failed to upload ${filename}"
        continue
      }
    fi
  done

  log_success "Agent configurations uploaded"
}

health_check() {
  if [ "${SKIP_HEALTH_CHECK}" = true ]; then
    log_warning "Skipping health checks"
    return 0
  fi

  log_info "Running health checks..."

  if [ "${DRY_RUN}" = true ]; then
    log_warning "DRY RUN MODE: Skipping health checks"
    return 0
  fi

  cd "${TERRAFORM_DIR}"

  # Check deployed resources
  local check_count=0
  local failed_checks=0

  # Check Lambda functions are accessible
  log_info "Checking Lambda functions..."
  local functions=$(aws lambda list-functions \
    --region us-east-1 \
    --query "Functions[?Tags.Environment=='${ENVIRONMENT}'].FunctionName" \
    --output text)

  if [ -z "${functions}" ]; then
    log_warning "No Lambda functions found for environment: ${ENVIRONMENT}"
  else
    for func in ${functions}; do
      log_info "  - ${func}"
      ((check_count++))
    done
  fi

  # Check API Gateway endpoints
  log_info "Checking API Gateway endpoints..."
  local apis=$(aws apigateway get-rest-apis \
    --region us-east-1 \
    --query "items[?contains(tags.Environment, '${ENVIRONMENT}')].id" \
    --output text)

  if [ -z "${apis}" ]; then
    log_warning "No API Gateway APIs found for environment: ${ENVIRONMENT}"
  else
    for api_id in ${apis}; do
      log_info "  - ${api_id}"
      ((check_count++))
    done
  fi

  if [ ${failed_checks} -eq 0 ]; then
    log_success "Health checks passed (${check_count} resources verified)"
  else
    log_warning "Health checks completed with ${failed_checks} issues"
  fi
}

list_resources() {
  log_info "Listing deployed resources for environment: ${ENVIRONMENT}..."

  cd "${TERRAFORM_DIR}"

  log_info "Terraform Resources:"
  terraform state list 2>/dev/null | sed 's/^/  /'

  log_info ""
  log_info "Lambda Functions:"
  aws lambda list-functions \
    --region us-east-1 \
    --query "Functions[?Tags.Environment=='${ENVIRONMENT}'].{Name:FunctionName,Runtime:Runtime,Memory:MemorySize}" \
    --output table

  log_info ""
  log_info "API Gateway Endpoints:"
  aws apigateway get-rest-apis \
    --region us-east-1 \
    --query "items[?contains(tags.Environment, '${ENVIRONMENT}')].{Name:name,Id:id}" \
    --output table
}

print_summary() {
  log_success "Deployment Summary"
  log_info "==============================================="
  log_info "Environment:        ${ENVIRONMENT}"
  log_info "Dry Run:            ${DRY_RUN}"
  log_info "Auto Approve:       ${AUTO_APPROVE}"
  log_info "Deployment Date:    ${TIMESTAMP}"
  log_info "Log File:           ${LOG_FILE}"
  log_info "==============================================="

  if [ "${DRY_RUN}" = false ]; then
    log_success "Deployment completed successfully!"
  else
    log_warning "This was a dry run. No changes were applied."
  fi
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
      -d|--dry-run)
        DRY_RUN=true
        shift
        ;;
      -l|--list-resources)
        LIST_RESOURCES=true
        shift
        ;;
      --skip-health-check)
        SKIP_HEALTH_CHECK=true
        shift
        ;;
      --auto-approve)
        AUTO_APPROVE=true
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

  # Validate inputs
  validate_environment "${ENVIRONMENT}"

  log_success "Starting deployment for environment: ${ENVIRONMENT}"
  log_info "Log file: ${LOG_FILE}"

  # Check prerequisites
  check_prerequisites

  # Handle list-resources flag
  if [ "${LIST_RESOURCES}" = true ]; then
    list_resources
    exit 0
  fi

  # Validate and initialize Terraform
  validate_terraform_config
  terraform_init

  # Plan and apply
  local plan_file=$(terraform_plan)
  terraform_apply "${plan_file}"

  # Deploy additional components
  deploy_lambdas
  upload_agent_configs

  # Run health checks
  health_check

  # Print summary
  print_summary
}

# Execute main function
main "$@"
