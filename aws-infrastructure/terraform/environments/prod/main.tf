# AWS Production Environment - 2025 Best Practices
# This is the AWS equivalent of the GCP production environment

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "servicenow-ai-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
    kms_key_id     = "alias/terraform-state"
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "servicenow-ai"
      Environment = "prod"
      ManagedBy   = "Terraform"
    }
  }
}

locals {
  cluster_name = "prod-ai-agent-eks"
  common_tags = {
    Environment = "prod"
    Application = "ai-agent"
    Project     = "servicenow-ai"
  }
}

# KMS Keys
module "kms" {
  source = "../../modules/kms"

  key_prefix = "prod"
  keys = {
    storage     = "Storage encryption"
    rds         = "RDS encryption"
    dynamodb    = "DynamoDB encryption"
    sns-sqs     = "SNS/SQS encryption"
    elasticache = "ElastiCache encryption"
    secrets     = "Secrets Manager encryption"
    eks         = "EKS encryption"
  }

  enable_multi_region = false
  tags                = local.common_tags
}

# VPC
module "vpc" {
  source = "../../modules/vpc"

  name                     = "prod-core"
  vpc_cidr                 = "10.0.0.0/16"
  environment              = "prod"
  enable_nat_gateway       = true
  single_nat_gateway       = false # Use multiple NAT Gateways for HA in production
  enable_flow_logs         = true
  flow_logs_retention_days = 30
  enable_vpc_endpoints     = true # Cost optimization - avoid NAT Gateway costs

  tags = local.common_tags
}

# EKS Cluster
module "eks" {
  source = "../../modules/eks"

  cluster_name       = local.cluster_name
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids
  kubernetes_version = "1.29"
  environment        = "prod"

  endpoint_private_access = true
  endpoint_public_access  = true
  public_access_cidrs     = var.eks_public_access_cidrs

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  log_retention_days        = 30

  general_node_group = {
    instance_types = ["t3.xlarge", "t3a.xlarge"] # Or use Graviton: ["t4g.xlarge"]
    capacity_type  = "ON_DEMAND"
    min_size       = 3
    max_size       = 20
    desired_size   = 3
    labels         = {}
  }

  enable_ai_node_group = true
  ai_node_group = {
    instance_types = ["r6i.2xlarge", "r6a.2xlarge"]
    capacity_type  = "ON_DEMAND"
    min_size       = 2
    max_size       = 10
    desired_size   = 2
    labels         = {}
  }

  tags = local.common_tags

  depends_on = [module.vpc]
}

# RDS PostgreSQL
module "rds" {
  source = "../../modules/rds"

  identifier                 = "prod-postgres"
  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = module.vpc.database_subnet_ids
  eks_node_security_group_id = module.eks.node_security_group_id
  environment                = "prod"

  engine_version        = "16.1"
  instance_class        = "db.r6i.xlarge"
  allocated_storage     = 200
  max_allocated_storage = 1000

  database_name   = "agentdb"
  master_username = "postgres"
  master_password = var.db_master_password # Use AWS Secrets Manager in production

  multi_az                = true
  backup_retention_period = 30
  deletion_protection     = true

  monitoring_interval         = 60
  enable_performance_insights = true
  kms_key_arn                 = module.kms.key_arns["rds"]

  create_read_replica         = var.create_rds_read_replica
  read_replica_instance_class = "db.r6i.large"

  tags = local.common_tags
}

# DynamoDB Tables (Firestore equivalent)
module "dynamodb" {
  source = "../../modules/dynamodb"

  environment = "prod"
  kms_key_arn = module.kms.key_arns["dynamodb"]

  tables = [
    {
      name                          = "prod-conversations"
      billing_mode                  = "PAY_PER_REQUEST"
      hash_key                      = "userId"
      range_key                     = "conversationId"
      enable_point_in_time_recovery = true
      enable_streams                = true
      stream_view_type              = "NEW_AND_OLD_IMAGES"
      attributes = [
        { name = "userId", type = "S" },
        { name = "conversationId", type = "S" },
        { name = "createdAt", type = "N" }
      ]
      global_secondary_indexes = [
        {
          name            = "CreatedAtIndex"
          hash_key        = "userId"
          range_key       = "createdAt"
          projection_type = "ALL"
        }
      ]
    },
    {
      name                          = "prod-sessions"
      billing_mode                  = "PAY_PER_REQUEST"
      hash_key                      = "sessionId"
      enable_point_in_time_recovery = true
      ttl_attribute                 = "expiresAt"
      attributes = [
        { name = "sessionId", type = "S" }
      ]
    }
  ]

  tags = local.common_tags
}

# S3 Buckets
module "s3" {
  source = "../../modules/s3"

  environment = "prod"

  buckets = [
    {
      name                       = "servicenow-ai-knowledge-documents-prod"
      kms_key_arn                = module.kms.key_arns["storage"]
      versioning_enabled         = true
      enable_intelligent_tiering = true
      enable_eventbridge         = true
    },
    {
      name               = "servicenow-ai-document-chunks-prod"
      kms_key_arn        = module.kms.key_arns["storage"]
      versioning_enabled = true
    },
    {
      name               = "servicenow-ai-user-uploads-prod"
      kms_key_arn        = module.kms.key_arns["storage"]
      versioning_enabled = true
      lifecycle_rules = [
        {
          id              = "delete-old-uploads"
          expiration_days = 90
        }
      ]
    },
    {
      name               = "servicenow-ai-backup-prod"
      kms_key_arn        = module.kms.key_arns["storage"]
      versioning_enabled = true
      lifecycle_rules = [
        {
          id = "archive-old-backups"
          transitions = [
            { days = 30, storage_class = "STANDARD_IA" },
            { days = 90, storage_class = "GLACIER_IR" },
            { days = 180, storage_class = "DEEP_ARCHIVE" }
          ]
        }
      ]
    },
    {
      name               = "servicenow-ai-audit-logs-prod"
      kms_key_arn        = module.kms.key_arns["storage"]
      versioning_enabled = true
    }
  ]

  tags = local.common_tags
}

# SNS + SQS (Pub/Sub equivalent)
module "sns_sqs" {
  source = "../../modules/sns-sqs"

  kms_key_arn = module.kms.key_arns["sns-sqs"]

  topics = [
    {
      name                      = "prod-ticket-events"
      message_retention_seconds = 604800
    },
    {
      name                      = "prod-notification-requests"
      message_retention_seconds = 604800
    },
    {
      name                      = "prod-knowledge-updates"
      message_retention_seconds = 604800
    },
    {
      name                      = "prod-action-requests"
      message_retention_seconds = 604800
    }
  ]

  tags = local.common_tags
}

# ElastiCache Redis (Memorystore equivalent)
module "elasticache" {
  source = "../../modules/elasticache"

  name                       = "prod-redis"
  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = module.vpc.database_subnet_ids
  eks_node_security_group_id = module.eks.node_security_group_id

  engine_version           = "7.1"
  node_type                = "cache.r7g.xlarge"
  num_cache_nodes          = 3
  auth_token               = var.redis_auth_token
  kms_key_arn              = module.kms.key_arns["elasticache"]
  snapshot_retention_limit = 7

  tags = local.common_tags
}

# Secrets Manager
module "secrets" {
  source = "../../modules/secrets-manager"

  kms_key_arn = module.kms.key_arns["secrets"]

  secrets = [
    { name = "prod/servicenow-oauth-client-id", description = "ServiceNow OAuth Client ID" },
    { name = "prod/servicenow-oauth-client-secret", description = "ServiceNow OAuth Client Secret" },
    { name = "prod/slack-bot-token", description = "Slack Bot Token" },
    { name = "prod/slack-signing-secret", description = "Slack Signing Secret" },
    { name = "prod/openai-api-key", description = "OpenAI API Key" },
    { name = "prod/anthropic-api-key", description = "Anthropic API Key" },
    {
      name                = "prod/rds-master-password"
      description         = "RDS Master Password"
      enable_rotation     = true
      rotation_lambda_arn = var.rds_rotation_lambda_arn
      rotation_days       = 90
    }
  ]

  tags = local.common_tags
}

# WAF (Cloud Armor equivalent)
module "waf" {
  source = "../../modules/waf"

  name       = "prod-eks"
  scope      = "REGIONAL"
  rate_limit = 2000

  tags = local.common_tags
}

# CloudWatch Log Groups for Application
resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/eks/${local.cluster_name}/application"
  retention_in_days = 30
  kms_key_id        = module.kms.key_arns["eks"]

  tags = local.common_tags
}

# AWS Budgets for Cost Control
resource "aws_budgets_budget" "monthly" {
  name              = "prod-monthly-budget"
  budget_type       = "COST"
  limit_amount      = "15000"
  limit_unit        = "USD"
  time_period_start = "2025-01-01_00:00"
  time_unit         = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_alert_emails
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_alert_emails
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_alert_emails
  }
}
