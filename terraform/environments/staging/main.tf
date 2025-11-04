module "kms" {
  source       = "../../modules/kms"
  project_id   = var.project_id
  location     = var.region
  keyring_name = "staging-keyring"
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
  network_name           = "staging-core"
  create_fw_default_deny = false
  subnets = [
    {
      name                    = "staging-core-us-central1"
      ip_cidr_range           = "10.40.0.0/20"
      region                  = var.region
      private_google_access   = true
      secondary_ip_range_pods = "10.50.0.0/16"
      secondary_ip_range_svc  = "10.60.0.0/20"
    }
  ]
}

module "gke" {
  source                  = "../../modules/gke"
  project_id              = var.project_id
  region                  = var.region
  network                 = module.vpc.network_self_link
  subnetwork              = values(module.vpc.subnet_self_links)[0]
  subnetwork_name         = "staging-core-us-central1"
  cluster_name            = "staging-ai-agent-gke"
  master_ipv4_cidr_block  = var.gke_master_cidr
  authorized_master_cidrs = []
  general_pool_size       = { min = 2, max = 5 }
  ai_pool_size            = { min = 1, max = 3 }
  vector_pool_size        = { min = 1, max = 3 }
  labels                  = { env = "staging", app = "ai-agent" }
}

module "storage" {
  source     = "../../modules/storage"
  project_id = var.project_id
  location   = var.region
  buckets = [
    { name = "knowledge-documents-staging", kms_key = module.kms.key_ids["storage"] },
    { name = "document-chunks-staging", kms_key = module.kms.key_ids["storage"] },
    { name = "user-uploads-staging", kms_key = module.kms.key_ids["storage"], lifecycle_rules = [{ action = { type = "Delete" }, condition = { age = 30 } }] },
    { name = "backup-staging", kms_key = module.kms.key_ids["storage"] },
    { name = "audit-logs-archive-staging", kms_key = module.kms.key_ids["storage"] }
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
  name               = "staging-redis"
  authorized_network = module.vpc.network_self_link
  memory_size_gb     = 2
}

module "cloudsql" {
  source        = "../../modules/cloudsql"
  project_id    = var.project_id
  region        = var.region
  instance_name = "staging-postgres"
  kms_key       = module.kms.key_ids["cloudsql"]
  databases     = ["users", "audit_logs", "knowledge_metadata", "action_logs"]
  users         = []
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

module "budget" {
  source          = "../../shared/billing_budget"
  billing_account = var.billing_account
  project_id      = var.project_id
  amount_monthly  = 5000
  thresholds      = [0.5, 0.8, 1.0]
}
