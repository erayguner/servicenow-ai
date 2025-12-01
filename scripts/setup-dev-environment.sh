#!/usr/bin/env bash
#
# Setup Development Environment
# This script installs and configures all necessary tools for local development
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}ℹ️  ${1}${NC}"
}

log_success() {
    echo -e "${GREEN}✅ ${1}${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  ${1}${NC}"
}

log_error() {
    echo -e "${RED}❌ ${1}${NC}"
}

check_command() {
    if command -v "$1" &> /dev/null; then
        log_success "$1 is installed"
        return 0
    else
        log_warning "$1 is not installed"
        return 1
    fi
}

# Main setup
main() {
    echo ""
    log_info "====================================="
    log_info "Development Environment Setup"
    log_info "====================================="
    echo ""

    # Check prerequisites
    log_info "Checking prerequisites..."

    MISSING_TOOLS=()

    if ! check_command python3; then
        MISSING_TOOLS+=("python3")
    fi

    if ! check_command pip3; then
        MISSING_TOOLS+=("pip3")
    fi

    if ! check_command git; then
        MISSING_TOOLS+=("git")
    fi

    if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
        log_error "Missing required tools: ${MISSING_TOOLS[*]}"
        log_info "Please install them first and re-run this script"
        exit 1
    fi

    echo ""
    log_info "Installing pre-commit..."

    # Install pre-commit
    if command -v pre-commit &> /dev/null; then
        log_success "pre-commit is already installed ($(pre-commit --version))"
    else
        pip3 install --user pre-commit
        log_success "pre-commit installed"
    fi

    echo ""
    log_info "Installing pre-commit hooks..."

    # Install hooks
    pre-commit install
    log_success "Pre-commit hooks installed"

    echo ""
    log_info "Checking Terraform installation..."

    # Check Terraform
    if command -v terraform &> /dev/null; then
        TERRAFORM_VERSION=$(terraform version -json | grep -o '"terraform_version":"[^"]*"' | cut -d'"' -f4)
        log_success "Terraform is installed (version $TERRAFORM_VERSION)"

        if [[ "$TERRAFORM_VERSION" < "1.0.0" ]]; then
            log_warning "Terraform version is older than 1.0.0. Consider upgrading to 1.11.0+"
        fi
    else
        log_warning "Terraform is not installed"
        log_info "Install from: https://developer.hashicorp.com/terraform/downloads"
        log_info "Recommended version: 1.11.0"
    fi

    echo ""
    log_info "Testing pre-commit configuration..."

    # Run pre-commit on README to test
    if pre-commit run --files README.md &> /dev/null; then
        log_success "Pre-commit configuration is valid"
    else
        log_warning "Some pre-commit hooks may need dependencies"
        log_info "Run 'pre-commit run --all-files' to see what's needed"
    fi

    echo ""
    log_info "====================================="
    log_success "Development Environment Setup Complete!"
    log_info "====================================="
    echo ""

    log_info "Quick Reference:"
    echo "  • Format Terraform:       make terraform-fmt"
    echo "  • Validate Terraform:     make terraform-validate"
    echo "  • Run pre-commit:         pre-commit run --all-files"
    echo "  • Run pre-commit (Terraform): pre-commit run terraform_fmt --all-files"
    echo "  • Validate Kubernetes:    make kubeconform"
    echo ""

    log_info "Pre-commit hooks will automatically run before each git commit"
    log_info "To skip hooks (not recommended): git commit --no-verify"
    echo ""
}

# Run main function
main "$@"
