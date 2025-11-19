# ==============================================================================
# Bedrock Security Secrets Module - Version Constraints
# ==============================================================================

terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.80.0"
    }
  }
}
