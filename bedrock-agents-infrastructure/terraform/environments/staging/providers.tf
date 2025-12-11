# Staging Environment Provider Configuration

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment        = "staging"
      Project            = "servicenow-ai"
      ManagedBy          = "terraform"
      CostCenter         = "qa-testing"
      Owner              = var.owner_email
      AutoShutdown       = "false"
      BackupRequired     = "true"
      Compliance         = "sox-compliant"
      DataClassification = "confidential"
      TerraformWorkspace = terraform.workspace
      ApprovalRequired   = "true"
    }
  }

  # Assume role for cross-account access (if needed)
  # assume_role {
  #   role_arn     = "arn:aws:iam::ACCOUNT_ID:role/TerraformStagingRole"
  #   session_name = "terraform-staging-session"
  # }
}

# Secondary region for testing multi-region capabilities
provider "aws" {
  alias  = "secondary"
  region = "us-west-2"

  default_tags {
    tags = {
      Environment = "staging"
      Project     = "servicenow-ai"
      ManagedBy   = "terraform"
      CostCenter  = "qa-testing"
      Owner       = var.owner_email
      Region      = "secondary"
    }
  }
}

# Provider for state bucket region
provider "aws" {
  alias  = "state"
  region = "eu-west-2"

  default_tags {
    tags = {
      Purpose     = "terraform-state"
      Environment = "staging"
    }
  }
}

# Provider for DR region (if needed)
provider "aws" {
  alias  = "dr"
  region = "eu-west-1"

  default_tags {
    tags = {
      Environment = "staging"
      Project     = "servicenow-ai"
      ManagedBy   = "terraform"
      Purpose     = "disaster-recovery"
    }
  }
}
