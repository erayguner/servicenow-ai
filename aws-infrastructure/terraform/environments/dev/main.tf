# AWS Development Environment - Cost-Optimized for Testing
# Minimal configuration for feature development and testing

terraform {
  required_version = ">= 1.11.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }

  backend "s3" {
    bucket         = "servicenow-ai-terraform-state"
    key            = "dev/terraform.tfstate"
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
      Environment = "dev"
      ManagedBy   = "Terraform"
      CostCenter  = "development"
    }
  }
}

locals {
  cluster_name = "dev-ai-agent-eks"
  common_tags = {
    Environment = "dev"
    Application = "ai-agent"
    Project     = "servicenow-ai"
  }
}

# KMS Keys (shared across dev resources)
module "kms" {
  source = "../../modules/kms"

  key_prefix = "dev"
  keys = {
    shared = "Shared encryption key for dev" # Single key for cost savings
  }

  enable_multi_region = false
  tags                = local.common_tags
}

# VPC with cost optimization
module "vpc" {
  source = "../../modules/vpc"

  name                 = "dev-core"
  vpc_cidr             = "10.10.0.0/16"
  environment          = "dev"
  enable_nat_gateway   = true
  single_nat_gateway   = true  # COST SAVING: Single NAT Gateway
  enable_flow_logs     = false # COST SAVING: Disabled for dev
  enable_vpc_endpoints = true  # COST SAVING: Avoid NAT Gateway data transfer

  tags = local.common_tags
}

# EKS Cluster with minimal configuration
module "eks" {
  source = "../../modules/eks"

  cluster_name       = local.cluster_name
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids
  kubernetes_version = "1.29"
  environment        = "dev"

  endpoint_private_access = true
  endpoint_public_access  = true
  public_access_cidrs     = var.eks_public_access_cidrs

  # COST SAVING: Minimal logging
  enabled_cluster_log_types = ["api", "audit"]
  log_retention_days        = 7

  # COST SAVING: Small general-purpose nodes
  general_node_group = {
    instance_types = ["t3a.medium"] # Cheaper AMD instances
    capacity_type  = "SPOT"         # COST SAVING: 70% cheaper
    min_size       = 1
    max_size       = 3
    desired_size   = 1
    labels         = {}
  }

  # COST SAVING: No AI node group for dev
  enable_ai_node_group = false

  tags = local.common_tags

  depends_on = [module.vpc]
}

# RDS PostgreSQL - Minimal configuration
module "rds" {
  source = "../../modules/rds"

  identifier                 = "dev-postgres"
  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = module.vpc.database_subnet_ids
  eks_node_security_group_id = module.eks.node_security_group_id
  environment                = "dev"

  engine_version        = "16.1"
  instance_class        = "db.t4g.micro" # COST SAVING: Smallest Graviton instance
  allocated_storage     = 20             # COST SAVING: Minimal storage
  max_allocated_storage = 100

  database_name   = "agentdb"
  master_username = "postgres"
  master_password = var.db_master_password

  multi_az                = false # COST SAVING: Single AZ
  backup_retention_period = 1     # COST SAVING: Minimal backups
  deletion_protection     = false # Allow easy teardown in dev

  monitoring_interval         = 0     # COST SAVING: No enhanced monitoring
  enable_performance_insights = false # COST SAVING: Disabled
  kms_key_arn                 = module.kms.key_arns["shared"]

  create_read_replica = false # COST SAVING: No read replica

  skip_final_snapshot = true # Allow quick deletion in dev

  tags = local.common_tags
}

# DynamoDB Tables - On-Demand billing
module "dynamodb" {
  source = "../../modules/dynamodb"

  environment = "dev"
  kms_key_arn = module.kms.key_arns["shared"]

  tables = [
    {
      name                          = "dev-conversations"
      billing_mode                  = "PAY_PER_REQUEST" # COST SAVING: Only pay for what you use
      hash_key                      = "userId"
      range_key                     = "conversationId"
      enable_point_in_time_recovery = false # COST SAVING: Disabled for dev
      enable_streams                = false # COST SAVING: Disabled unless needed
      ttl_attribute                 = "expiresAt"
      attributes = [
        { name = "userId", type = "S" },
        { name = "conversationId", type = "S" }
      ]
    },
    {
      name                          = "dev-sessions"
      billing_mode                  = "PAY_PER_REQUEST"
      hash_key                      = "sessionId"
      enable_point_in_time_recovery = false
      ttl_attribute                 = "expiresAt"
      attributes = [
        { name = "sessionId", type = "S" }
      ]
    }
  ]

  tags = local.common_tags
}

# S3 Buckets - Minimal configuration
module "s3" {
  source = "../../modules/s3"

  environment = "dev"

  buckets = [
    {
      name                       = "servicenow-ai-knowledge-documents-dev"
      kms_key_arn                = module.kms.key_arns["shared"]
      versioning_enabled         = false # COST SAVING: No versioning for dev
      enable_intelligent_tiering = false # COST SAVING: Manual management
      enable_eventbridge         = false
    },
    {
      name               = "servicenow-ai-user-uploads-dev"
      kms_key_arn        = module.kms.key_arns["shared"]
      versioning_enabled = false
      lifecycle_rules = [
        {
          id              = "delete-old-uploads"
          expiration_days = 7 # COST SAVING: Delete after 7 days
        }
      ]
    }
  ]

  tags = local.common_tags
}

# SNS + SQS - Minimal topics
module "sns_sqs" {
  source = "../../modules/sns-sqs"

  kms_key_arn = module.kms.key_arns["shared"]

  topics = [
    {
      name                      = "dev-test-events"
      message_retention_seconds = 86400 # COST SAVING: 1 day retention
    }
  ]

  tags = local.common_tags
}

# ElastiCache Redis - Smallest configuration
module "elasticache" {
  source = "../../modules/elasticache"

  name                       = "dev-redis"
  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = module.vpc.database_subnet_ids
  eks_node_security_group_id = module.eks.node_security_group_id

  engine_version           = "7.1"
  node_type                = "cache.t4g.micro" # COST SAVING: Smallest Graviton instance
  num_cache_nodes          = 1                 # COST SAVING: Single node
  auth_token               = var.redis_auth_token
  kms_key_arn              = module.kms.key_arns["shared"]
  snapshot_retention_limit = 0 # COST SAVING: No snapshots

  tags = local.common_tags
}

# Secrets Manager - Essential secrets only
module "secrets" {
  source = "../../modules/secrets-manager"

  kms_key_arn = module.kms.key_arns["shared"]

  secrets = [
    { name = "dev/anthropic-api-key", description = "Anthropic API Key" },
    { name = "dev/openai-api-key", description = "OpenAI API Key" },
    { name = "dev/rds-password", description = "RDS Password", recovery_window_in_days = 0 } # Allow immediate deletion
  ]

  tags = local.common_tags
}

# WAF - Minimal rules for dev
module "waf" {
  source = "../../modules/waf"

  name       = "dev-eks"
  scope      = "REGIONAL"
  rate_limit = 5000 # Higher limit for dev testing

  tags = local.common_tags
}

# CloudWatch Log Group for Application
resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/eks/${local.cluster_name}/application"
  retention_in_days = 3 # COST SAVING: Minimal retention
  kms_key_id        = module.kms.key_arns["shared"]

  tags = local.common_tags
}

# Budget Alert - Low threshold for dev
resource "aws_budgets_budget" "monthly" {
  name              = "dev-monthly-budget"
  budget_type       = "COST"
  limit_amount      = "200" # COST ALERT: Low budget for dev
  limit_unit        = "USD"
  time_period_start = "2025-01-01_00:00"
  time_unit         = "MONTHLY"

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
