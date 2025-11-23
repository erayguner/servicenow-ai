# ==============================================================================
# Version Constraints with Archive and Local Providers
# ==============================================================================
# This file contains version constraints for modules that require archive
# and local providers in addition to the standard AWS provider.
#
# Used by: bedrock-action-group, monitoring-synthetics
# ==============================================================================

terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}
