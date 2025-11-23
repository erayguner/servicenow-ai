# ==============================================================================
# Version Constraints with Additional Providers
# ==============================================================================
# This file contains version constraints for modules that require additional
# providers like random, null, etc.
#
# Used by: bedrock-servicenow
# ==============================================================================

terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}
