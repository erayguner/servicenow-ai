# ==============================================================================
# Terraform Backend Configuration Template
# ==============================================================================
# This file provides a template for S3 backend configuration across environments.
# Copy and customize for each environment (dev, staging, prod).
#
# Key differences between environments:
# - dev:     servicenow-ai-terraform-state-dev
# - staging: servicenow-ai-terraform-state-staging
# - prod:    servicenow-ai-terraform-state-prod
#
# Usage: This is a template file. The actual backend configuration should be
#        in your environment-specific main.tf files.
# ==============================================================================

# Example backend configuration:
# terraform {
#   backend "s3" {
#     bucket         = "servicenow-ai-terraform-state-${ENVIRONMENT}"
#     key            = "bedrock-agents/${ENVIRONMENT}/terraform.tfstate"
#     region         = "us-east-1"
#     encrypt        = true
#     dynamodb_table = "servicenow-ai-terraform-locks-${ENVIRONMENT}"
#     kms_key_id     = "alias/terraform-state-key-${ENVIRONMENT}"
#   }
# }
