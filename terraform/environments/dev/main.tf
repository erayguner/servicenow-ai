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
  source                 = "../../modules/vpc"
  project_id             = var.project_id
  region                 = var.region
  network_name           = "dev-core"
  create_fw_default_deny = false
  subnets = [
    {
      name                    = "dev-core-us-central1"
      ip_cidr_range           = "10.70.0.0/20"
      region                  = var.region
      private_google_access   = true
      secondary_ip_range_pods = "10.80.0.0/16"
      secondary_ip_range_svc  = "10.90.0.0/20"
    }
  ]
}

module "gke" {
  source                  = "../../modules/gke"
  project_id              = var.project_id
  region                  = "europe-west2-a" # Use single zone instead of region for dev
  network                 = module.vpc.network_self_link
  subnetwork              = values(module.vpc.subnet_self_links)[0]
  subnetwork_name         = "dev-core-us-central1"
  cluster_name            = "dev-ai-agent-gke"
  master_ipv4_cidr_block  = var.gke_master_cidr
  authorized_master_cidrs = []
  general_pool_size       = { min = 1, max = 3 }
  ai_pool_size            = { min = 0, max = 1 }
  vector_pool_size        = { min = 0, max = 1 }
  labels                  = { env = "dev", app = "ai-agent" }
}

module "storage" {
  source     = "../../modules/storage"
  project_id = var.project_id
  location   = var.region
  buckets = [
    { name = "${var.project_id}-knowledge-documents-dev", kms_key = module.kms.key_ids["storage"] },
    { name = "${var.project_id}-document-chunks-dev", kms_key = module.kms.key_ids["storage"] },
    { name = "${var.project_id}-user-uploads-dev", kms_key = module.kms.key_ids["storage"], lifecycle_rules = [{ action = { type = "Delete" }, condition = { age = 14 } }] },
    { name = "${var.project_id}-backup-dev", kms_key = module.kms.key_ids["storage"] },
    { name = "${var.project_id}-audit-logs-archive-dev", kms_key = module.kms.key_ids["storage"] }
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
  authorized_network = module.vpc.network_self_link
  memory_size_gb     = 1
}

module "cloudsql" {
  source          = "../../modules/cloudsql"
  project_id      = var.project_id
  region          = var.region
  instance_name   = "dev-postgres"
  kms_key         = module.kms.key_ids["cloudsql"]
  private_network = module.vpc.network_self_link
  disk_size       = 50 # Reduce from 100GB to 50GB for dev
  databases       = ["users", "audit_logs", "knowledge_metadata", "action_logs"]
  users           = []

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

# Billing budget - comment out due to quota project authentication issues
# Create manually in GCP Console: Billing > Budgets & Alerts
# module "budget" {
#   source          = "../../shared/billing_budget"
#   billing_account = var.billing_account
#   project_id      = var.project_id
#   amount_monthly  = 20
#   thresholds      = [0.5, 0.8, 1.0]
# }
