#!/bin/bash

################################################################################
# Bedrock Agents Infrastructure - Cleanup Script
#
# This script safely cleans up and removes Bedrock agents infrastructure
# including Terraform resources, S3 buckets, and CloudWatch logs.
#
# Usage:
#   ./cleanup.sh [OPTIONS]
#
# Options:
#   -e, --environment ENV           Environment: dev, staging, or prod
#   -a, --all                       Remove all resources (includes data)
#   --tf-destroy                    Destroy Terraform resources
#   --clean-s3                      Empty and remove S3 buckets
#   --clean-logs                    Remove CloudWatch logs
#   --clean-state                   Remove local Terraform state
#   --confirm                       Skip confirmation prompt (DANGER!)
#   --dry-run                       Show what would be deleted
#   -h, --help                      Show this help message
#
# Examples:
#   ./cleanup.sh -e dev --dry-run
#   ./cleanup.sh -e staging --tf-destroy
#   ./cleanup.sh -e prod -a --confirm
#
# WARNING: This script performs destructive operations. Always use --dry-run first!
#
################################################################################

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TERRAFORM_DIR="${PROJECT_ROOT}/terraform"
LOG_DIR="${PROJECT_ROOT}/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/cleanup_${TIMESTAMP}.log"

# Default values
ENVIRONMENT=""
CLEANUP_ALL=false
TF_DESTROY=false
CLEAN_S3=false
CLEAN_LOGS=false
CLEAN_STATE=false
CONFIRM=false
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

log_critical() {
  echo -e "${RED}[CRITICAL]${NC} $*" | tee -a "${LOG_FILE}"
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

  for tool in aws terraform jq; do
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

confirm_action() {
  local message=$1

  if [ "${CONFIRM}" = true ]; then
    log_warning "CONFIRMATION SKIPPED (--confirm flag used)"
    return 0
  fi

  echo ""
  echo -e "${YELLOW}DANGER: This action cannot be undone!${NC}"
  echo -e "${RED}${message}${NC}"
  echo ""

  read -p "Type 'yes' to confirm (or any other input to cancel): " response

  if [ "${response}" = "yes" ]; then
    return 0
  else
    log_info "Action cancelled"
    return 1
  fi
}

print_cleanup_summary() {
  echo ""
  echo -e "${YELLOW}================================${NC}"
  echo -e "${YELLOW}CLEANUP SUMMARY${NC}"
  echo -e "${YELLOW}================================${NC}"
  echo "Environment:      ${ENVIRONMENT}"
  echo "Cleanup All:      ${CLEANUP_ALL}"
  echo "TF Destroy:       ${TF_DESTROY}"
  echo "Clean S3:         ${CLEAN_S3}"
  echo "Clean Logs:       ${CLEAN_LOGS}"
  echo "Clean State:      ${CLEAN_STATE}"
  echo "Dry Run:          ${DRY_RUN}"
  echo "Log File:         ${LOG_FILE}"
  echo -e "${YELLOW}================================${NC}"
}

################################################################################
# Cleanup Functions
################################################################################

cleanup_terraform() {
  log_critical "Starting Terraform resource destruction..."

  if [ ! -d "${TERRAFORM_DIR}" ]; then
    log_warning "Terraform directory not found"
    return 0
  fi

  cd "${TERRAFORM_DIR}"

  # Initialize Terraform
  log_info "Initializing Terraform..."
  terraform init \
    -backend-config="key=bedrock-agents/${ENVIRONMENT}/terraform.tfstate" \
    -upgrade || {
    log_warning "Terraform init had issues, continuing..."
  }

  if [ "${DRY_RUN}" = true ]; then
    log_warning "DRY RUN: Would execute terraform destroy"
    terraform plan -destroy \
      -var-file="environments/${ENVIRONMENT}.tfvars" || true
    return 0
  fi

  # Perform Terraform destroy
  terraform destroy \
    -var-file="environments/${ENVIRONMENT}.tfvars" \
    -auto-approve || {
    log_error "Terraform destroy failed"
    return 1
  }

  log_success "Terraform resources destroyed"
}

cleanup_s3_buckets() {
  log_critical "Starting S3 bucket cleanup..."

  if [ "${DRY_RUN}" = true ]; then
    log_warning "DRY RUN: Would clean S3 buckets for environment: ${ENVIRONMENT}"

    # List buckets that would be cleaned
    aws s3 ls --region us-east-1 | grep "bedrock-${ENVIRONMENT}" | while read -r line; do
      local bucket_name=$(echo "$line" | awk '{print $3}')
      log_info "  Would clean: ${bucket_name}"
      aws s3 ls "s3://${bucket_name}" --recursive --summarize 2>/dev/null | tail -1 || true
    done
    return 0
  fi

  # Find and clean buckets
  local bucket_count=0
  local total_size=0

  aws s3 ls --region us-east-1 | grep "bedrock-${ENVIRONMENT}" | while read -r line; do
    local bucket_name=$(echo "$line" | awk '{print $3}')

    log_info "Cleaning bucket: ${bucket_name}"

    # List bucket size before deletion
    local bucket_size=$(aws s3 ls "s3://${bucket_name}" --recursive --summarize 2>/dev/null | tail -1 | awk '{print $3}' || echo "0")

    # Empty the bucket
    aws s3 rm "s3://${bucket_name}" --recursive || {
      log_warning "Failed to empty bucket: ${bucket_name}"
      return 1
    }

    # Delete the bucket
    aws s3 rb "s3://${bucket_name}" || {
      log_warning "Failed to delete bucket: ${bucket_name}"
      continue
    }

    log_success "Deleted bucket: ${bucket_name}"
    ((bucket_count++))
    ((total_size += bucket_size))
  done

  log_success "S3 cleanup completed: ${bucket_count} buckets removed"
}

cleanup_cloudwatch_logs() {
  log_info "Cleaning CloudWatch logs..."

  if [ "${DRY_RUN}" = true ]; then
    log_warning "DRY RUN: Would clean CloudWatch logs for environment: ${ENVIRONMENT}"

    # List log groups that would be cleaned
    aws logs describe-log-groups \
      --region us-east-1 \
      --query "logGroups[?contains(logGroupName, '${ENVIRONMENT}')].logGroupName" \
      --output text | tr '\t' '\n' | while read -r group; do
      log_info "  Would delete: ${group}"
    done
    return 0
  fi

  local group_count=0

  # Find and delete log groups
  aws logs describe-log-groups \
    --region us-east-1 \
    --query "logGroups[?contains(logGroupName, '${ENVIRONMENT}')].logGroupName" \
    --output text | tr '\t' '\n' | while read -r group; do

    if [ -z "${group}" ]; then
      continue
    fi

    log_info "Deleting log group: ${group}"

    aws logs delete-log-group \
      --log-group-name "${group}" \
      --region us-east-1 || {
      log_warning "Failed to delete log group: ${group}"
      return 1
    }

    log_success "Deleted log group: ${group}"
    ((group_count++))
  done

  log_success "CloudWatch cleanup completed: ${group_count} log groups removed"
}

cleanup_local_state() {
  log_info "Cleaning local Terraform state..."

  if [ "${DRY_RUN}" = true ]; then
    log_warning "DRY RUN: Would remove local state for environment: ${ENVIRONMENT}"
    find "${TERRAFORM_DIR}" -name "*${ENVIRONMENT}*" -type f | sed 's/^/  /'
    return 0
  fi

  local file_count=0

  # Remove state files
  find "${TERRAFORM_DIR}" -name "*${ENVIRONMENT}*" -type f | while read -r file; do
    log_info "Removing state file: ${file}"
    rm -f "${file}"
    ((file_count++))
  done

  log_success "Local state cleaned: ${file_count} files removed"
}

cleanup_lambda_functions() {
  log_info "Cleaning Lambda functions..."

  if [ "${DRY_RUN}" = true ]; then
    log_warning "DRY RUN: Would delete Lambda functions for environment: ${ENVIRONMENT}"

    aws lambda list-functions \
      --region us-east-1 \
      --query "Functions[?Tags.Environment=='${ENVIRONMENT}'].FunctionName" \
      --output text | tr '\t' '\n' | while read -r func; do
      log_info "  Would delete: ${func}"
    done
    return 0
  fi

  local func_count=0

  # Delete Lambda functions
  aws lambda list-functions \
    --region us-east-1 \
    --query "Functions[?Tags.Environment=='${ENVIRONMENT}'].FunctionName" \
    --output text | tr '\t' '\n' | while read -r func; do

    if [ -z "${func}" ]; then
      continue
    fi

    log_info "Deleting Lambda function: ${func}"

    aws lambda delete-function \
      --function-name "${func}" \
      --region us-east-1 || {
      log_warning "Failed to delete Lambda function: ${func}"
      return 1
    }

    log_success "Deleted Lambda function: ${func}"
    ((func_count++))
  done

  log_success "Lambda cleanup completed: ${func_count} functions removed"
}

cleanup_iam_roles() {
  log_info "Cleaning IAM roles and policies..."

  if [ "${DRY_RUN}" = true ]; then
    log_warning "DRY RUN: Would delete IAM roles for environment: ${ENVIRONMENT}"

    aws iam list-roles \
      --query "Roles[?contains(RoleName, 'bedrock-') && contains(RoleName, '${ENVIRONMENT}')].RoleName" \
      --output text | tr '\t' '\n' | while read -r role; do
      log_info "  Would delete: ${role}"
    done
    return 0
  fi

  local role_count=0

  # Delete IAM roles
  aws iam list-roles \
    --query "Roles[?contains(RoleName, 'bedrock-') && contains(RoleName, '${ENVIRONMENT}')].RoleName" \
    --output text | tr '\t' '\n' | while read -r role; do

    if [ -z "${role}" ]; then
      continue
    fi

    log_info "Deleting IAM role: ${role}"

    # Detach all policies first
    aws iam list-attached-role-policies \
      --role-name "${role}" \
      --query 'AttachedPolicies[].PolicyArn' \
      --output text | tr '\t' '\n' | while read -r policy; do
      [ -z "${policy}" ] && continue
      aws iam detach-role-policy --role-name "${role}" --policy-arn "${policy}"
    done

    # Delete inline policies
    aws iam list-role-policies \
      --role-name "${role}" \
      --query 'PolicyNames' \
      --output text | tr '\t' '\n' | while read -r policy; do
      [ -z "${policy}" ] && continue
      aws iam delete-role-policy --role-name "${role}" --policy-name "${policy}"
    done

    # Delete role
    aws iam delete-role --role-name "${role}" || {
      log_warning "Failed to delete IAM role: ${role}"
      return 1
    }

    log_success "Deleted IAM role: ${role}"
    ((role_count++))
  done

  log_success "IAM cleanup completed: ${role_count} roles removed"
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
      -a|--all)
        CLEANUP_ALL=true
        shift
        ;;
      --tf-destroy)
        TF_DESTROY=true
        shift
        ;;
      --clean-s3)
        CLEAN_S3=true
        shift
        ;;
      --clean-logs)
        CLEAN_LOGS=true
        shift
        ;;
      --clean-state)
        CLEAN_STATE=true
        shift
        ;;
      --confirm)
        CONFIRM=true
        shift
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

  # Validate inputs
  if [ -z "${ENVIRONMENT}" ]; then
    log_error "Environment is required (use -e or --environment)"
    exit 1
  fi

  # If --all is specified, enable all cleanup options
  if [ "${CLEANUP_ALL}" = true ]; then
    TF_DESTROY=true
    CLEAN_S3=true
    CLEAN_LOGS=true
    CLEAN_STATE=true
  fi

  # Check at least one cleanup option is specified
  if [ "${TF_DESTROY}" = false ] && [ "${CLEAN_S3}" = false ] && \
     [ "${CLEAN_LOGS}" = false ] && [ "${CLEAN_STATE}" = false ]; then
    log_error "Please specify at least one cleanup operation"
    show_help
    exit 1
  fi

  log_critical "Bedrock Agents Infrastructure Cleanup"
  log_info "Environment: ${ENVIRONMENT}"
  log_info "Log file: ${LOG_FILE}"

  check_prerequisites

  print_cleanup_summary

  # Request confirmation unless this is a dry run
  if [ "${DRY_RUN}" = false ]; then
    confirm_action "This will delete all Bedrock agents infrastructure for environment '${ENVIRONMENT}'" || exit 0
  fi

  # Perform cleanup operations
  [ "${TF_DESTROY}" = true ] && cleanup_terraform
  [ "${CLEAN_S3}" = true ] && cleanup_s3_buckets
  [ "${CLEAN_LOGS}" = true ] && cleanup_cloudwatch_logs
  [ "${CLEAN_STATE}" = true ] && cleanup_local_state
  cleanup_lambda_functions
  cleanup_iam_roles

  log_success "Cleanup completed successfully"

  if [ "${DRY_RUN}" = true ]; then
    log_warning "This was a dry run. No resources were actually deleted."
  else
    log_critical "All specified resources have been removed."
  fi
}

# Execute main function
main "$@"
