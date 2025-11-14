module "kms" {
  source       = "../../modules/kms"
  project_id   = var.project_id
  location     = var.region
  keyring_name = "dev-keyring"
  keys = {
    storage  = "7776000s"
    pubsub   = "7776000s"
    cloudsql = "7776000s"
    secrets  = "7776000s"
  }
}

module "vpc" {
  source                             = "../../modules/vpc"
  project_id                         = var.project_id
  region                             = var.region
  network_name                       = "dev-core"
  create_fw_default_deny             = false
  enable_serverless_connector        = true
  serverless_connector_name          = "dev-cloud-run-connector"
  serverless_connector_cidr          = "10.8.0.0/28"
  serverless_connector_min_instances = 0 # Scale to zero for dev cost savings
  serverless_connector_max_instances = 2 # Reduced for minimal test setup
  subnets = [
    {
      name                    = "dev-core-europe-west2"
      ip_cidr_range           = "10.70.0.0/20"
      region                  = var.region
      private_google_access   = true
      secondary_ip_range_pods = "10.80.0.0/16"
      secondary_ip_range_svc  = "10.90.0.0/20"
    }
  ]
}

# checkov:skip=CKV_GCP_21:Labels are configured via merge() - Checkov cannot evaluate Terraform functions during static analysis
module "gke" { # checkov:skip=CKV_GCP_21
  source                  = "../../modules/gke"
  project_id              = var.project_id
  region                  = "europe-west2-a" # Use single zone instead of region for dev
  network                 = module.vpc.network_self_link
  subnetwork              = values(module.vpc.subnet_self_links)[0]
  subnetwork_name         = "dev-core-europe-west2"
  cluster_name            = "dev-ai-agent-gke"
  master_ipv4_cidr_block  = var.gke_master_cidr
  authorized_master_cidrs = []
  general_pool_size       = { min = 1, max = 3 }
  ai_pool_size            = { min = 0, max = 1 }
  vector_pool_size        = { min = 0, max = 1 }
  labels                  = { env = "dev", app = "ai-agent" }
  environment             = "dev"
}

module "storage" {
  source     = "../../modules/storage"
  project_id = var.project_id
  location   = var.region
  buckets = [
    { name = "${var.project_id}-knowledge-documents-dev", kms_key = module.kms.key_ids["storage"], versioning = false },
    { name = "${var.project_id}-document-chunks-dev", kms_key = module.kms.key_ids["storage"], versioning = false },
    { name = "${var.project_id}-user-uploads-dev", kms_key = module.kms.key_ids["storage"], versioning = false, lifecycle_rules = [{ action = { type = "Delete" }, condition = { age = 14 } }] },
    { name = "${var.project_id}-backup-dev", kms_key = module.kms.key_ids["storage"], versioning = false },
    { name = "${var.project_id}-audit-logs-archive-dev", kms_key = module.kms.key_ids["storage"], versioning = false }
  ]
}

module "pubsub" {
  source     = "../../modules/pubsub"
  project_id = var.project_id
  topics = [
    { name = "ticket-events", kms_key = module.kms.key_ids["pubsub"] },
    { name = "notification-requests", kms_key = module.kms.key_ids["pubsub"] },
    { name = "knowledge-updates", kms_key = module.kms.key_ids["pubsub"] },
    { name = "action-requests", kms_key = module.kms.key_ids["pubsub"] },
    { name = "dead-letter-queue", kms_key = module.kms.key_ids["pubsub"] }
  ]
}

module "redis" {
  source             = "../../modules/redis"
  project_id         = var.project_id
  region             = var.region
  name               = "dev-redis"
  tier               = "BASIC" # Non-HA tier for dev cost savings
  authorized_network = module.vpc.network_self_link
  memory_size_gb     = 1
}

module "cloudsql" {
  source            = "../../modules/cloudsql"
  project_id        = var.project_id
  region            = var.region
  instance_name     = "dev-postgres"
  tier              = "db-custom-2-8192" # Smaller instance: 2 vCPU, 8GB RAM for dev
  availability_type = "ZONAL"            # Single-zone (non-HA) for dev cost savings
  kms_key           = module.kms.key_ids["cloudsql"]
  private_network   = module.vpc.network_self_link
  disk_size         = 50 # Reduced from 100GB for dev
  databases         = ["users", "audit_logs", "knowledge_metadata", "action_logs"]
  users             = []

  depends_on = [module.vpc]
}

module "firestore" {
  source      = "../../modules/firestore"
  project_id  = var.project_id
  location_id = "eur3"
}

module "secrets" {
  source     = "../../modules/secret_manager"
  project_id = var.project_id
  secrets = [
    { name = "servicenow-oauth-client-id" },
    { name = "servicenow-oauth-client-secret" },
    { name = "slack-bot-token" },
    { name = "slack-signing-secret" },
    { name = "openai-api-key" },
    { name = "anthropic-api-key" },
    { name = "vertexai-api-key" }
  ]
}

# AI Research Assistant Backend
module "ai_research_backend" {
  source                  = "../../modules/cloud_run"
  project_id              = var.project_id
  region                  = var.region
  service_name            = "ai-research-backend"
  image                   = "gcr.io/${var.project_id}/ai-research-backend:latest"
  vpc_connector           = module.vpc.serverless_connector_id
  create_service_account  = true
  enable_cloud_sql_access = true
  enable_firestore_access = true
  enable_iap              = true
  min_instances           = 0       # Scale to zero for dev cost savings
  max_instances           = 2       # Reduced for minimal test setup
  cpu_limit               = "1"     # Reduced for dev cost savings
  memory_limit            = "512Mi" # Reduced for dev cost savings
  container_port          = 8080
  health_check_path       = "/health"
  labels                  = { env = "dev", app = "ai-research-assistant" }
  environment_variables = {
    NODE_ENV       = "production"
    GCP_PROJECT_ID = var.project_id
    GCP_REGION     = var.region
  }
  secret_environment_variables = {
    ANTHROPIC_API_KEY = {
      secret  = "anthropic-api-key"
      version = "latest"
    }
    OPENAI_API_KEY = {
      secret  = "openai-api-key"
      version = "latest"
    }
  }

  depends_on = [module.vpc, module.secrets]
}

# AI Research Assistant Frontend
module "ai_research_frontend" {
  source                 = "../../modules/cloud_run"
  project_id             = var.project_id
  region                 = var.region
  service_name           = "ai-research-frontend"
  image                  = "gcr.io/${var.project_id}/ai-research-frontend:latest"
  vpc_connector          = module.vpc.serverless_connector_id
  create_service_account = true
  enable_iap             = true
  min_instances          = 0 # Scale to zero for dev cost savings
  max_instances          = 2 # Reduced for minimal test setup
  cpu_limit              = "1"
  memory_limit           = "256Mi" # Reduced for dev cost savings
  container_port         = 3000
  health_check_path      = "/"
  labels                 = { env = "dev", app = "ai-research-assistant" }
  environment_variables = {
    NODE_ENV            = "production"
    NEXT_PUBLIC_API_URL = "https://${module.ai_research_backend.service_url}"
  }

  depends_on = [module.vpc, module.ai_research_backend]
}

# Billing budget - comment out due to quota project authentication issues
# Create manually in GCP Console: Billing > Budgets & Alerts
# module "budget" {
#   source          = "../../shared/billing_budget"
#   billing_account = var.billing_account
#   project_id      = var.project_id
#   amount_monthly  = 20
#   thresholds      = [0.5, 0.8, 1.0]
# }
