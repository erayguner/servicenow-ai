# Development Environment Provider Configuration

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment        = "dev"
      Project            = "servicenow-ai"
      ManagedBy          = "terraform"
      CostCenter         = "development"
      Owner              = var.owner_email
      AutoShutdown       = "true"
      BackupRequired     = "false"
      Compliance         = "none"
      TerraformWorkspace = terraform.workspace
    }
  }

  # Assume role for cross-account access (if needed)
  # assume_role {
  #   role_arn     = "arn:aws:iam::ACCOUNT_ID:role/TerraformDevRole"
  #   session_name = "terraform-dev-session"
  # }
}

# Additional provider for multi-region resources (if needed)
provider "aws" {
  alias  = "secondary"
  region = "us-west-2"

  default_tags {
    tags = {
      Environment = "dev"
      Project     = "servicenow-ai"
      ManagedBy   = "terraform"
      CostCenter  = "development"
      Owner       = var.owner_email
    }
  }
}

# Provider for state bucket region (if different)
provider "aws" {
  alias  = "state"
  region = "us-east-1"

  default_tags {
    tags = {
      Purpose     = "terraform-state"
      Environment = "dev"
    }
  }
}
