# Production Environment Provider Configuration

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(
      {
        Environment         = "prod"
        Project             = "servicenow-ai"
        ManagedBy           = "terraform"
        CostCenter          = "production-operations"
        Owner               = var.owner_email
        AutoShutdown        = "false"
        BackupRequired      = "true"
        Compliance          = "sox-pci-hipaa"
        DataClassification  = "highly-confidential"
        DisasterRecovery    = "enabled"
        BusinessCriticality = "tier-1"
        TerraformWorkspace  = terraform.workspace
        ChangeApproval      = "required"
      },
      var.cost_allocation_tags
    )
  }

  # Assume role for production account access (cross-account)
  # assume_role {
  #   role_arn     = "arn:aws:iam::PROD_ACCOUNT_ID:role/TerraformProductionRole"
  #   session_name = "terraform-prod-session"
  #   external_id  = "terraform-external-id"
  # }

  # Additional retry configuration for production stability
  retry_mode      = "adaptive"
  max_attempts    = 5
}

# Secondary region provider for high availability
provider "aws" {
  alias  = "secondary"
  region = var.secondary_region

  default_tags {
    tags = merge(
      {
        Environment         = "prod"
        Project             = "servicenow-ai"
        ManagedBy           = "terraform"
        CostCenter          = "production-operations"
        Owner               = var.owner_email
        Region              = "secondary"
        DisasterRecovery    = "enabled"
        BusinessCriticality = "tier-1"
      },
      var.cost_allocation_tags
    )
  }

  # assume_role {
  #   role_arn     = "arn:aws:iam::PROD_ACCOUNT_ID:role/TerraformProductionRole"
  #   session_name = "terraform-prod-secondary-session"
  # }

  retry_mode   = "adaptive"
  max_attempts = 5
}

# Disaster recovery region provider
provider "aws" {
  alias  = "dr"
  region = var.dr_region

  default_tags {
    tags = merge(
      {
        Environment         = "prod"
        Project             = "servicenow-ai"
        ManagedBy           = "terraform"
        CostCenter          = "production-operations"
        Owner               = var.owner_email
        Region              = "dr"
        Purpose             = "disaster-recovery"
        BusinessCriticality = "tier-1"
      },
      var.cost_allocation_tags
    )
  }

  retry_mode   = "adaptive"
  max_attempts = 5
}

# Provider for state bucket management (central region)
provider "aws" {
  alias  = "state"
  region = "us-east-1"

  default_tags {
    tags = {
      Purpose     = "terraform-state"
      Environment = "prod"
      Project     = "servicenow-ai"
    }
  }
}

# Provider for global resources (CloudFront, Route53, IAM)
provider "aws" {
  alias  = "global"
  region = "us-east-1"

  default_tags {
    tags = {
      Scope       = "global"
      Environment = "prod"
      Project     = "servicenow-ai"
    }
  }
}
