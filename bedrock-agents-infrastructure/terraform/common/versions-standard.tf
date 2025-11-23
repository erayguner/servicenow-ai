# ==============================================================================
# Standard Version Constraints for Bedrock Terraform Modules
# ==============================================================================
# This file contains the standard Terraform and provider version constraints
# used across all bedrock modules. Copy or reference this file in your modules
# to ensure consistency.
#
# Usage: Copy this file to your module's versions.tf or maintain consistency
#        with these version requirements.
# ==============================================================================

terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }
}
