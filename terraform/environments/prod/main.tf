module "kms" {
  source       = "../../modules/kms"
  project_id   = var.project_id
  location     = var.region
  keyring_name = "prod-keyring"
  keys = {
    storage  = "7776000s" # 90 days
    pubsub   = "7776000s"
    cloudsql = "7776000s"
    secrets  = "7776000s"
  }
}

module "vpc" {
  source                 = "../../modules/vpc"
  project_id             = var.project_id
  region                 = var.region
  network_name           = "prod-core"
  nat_ip_count           = 2
  create_fw_default_deny = true # Enable zero-trust networking
  subnets = [
    {
      name                    = "prod-core-us-central1"
      ip_cidr_range           = "10.10.0.0/20"
      region                  = var.region
      private_google_access   = true
      secondary_ip_range_pods = "10.20.0.0/16"
      secondary_ip_range_svc  = "10.30.0.0/20"
    }
  ]
}

module "gke" {
  source                  = "../../modules/gke"
  project_id              = var.project_id
  region                  = var.region
  network                 = module.vpc.network_self_link
  subnetwork              = values(module.vpc.subnet_self_links)[0]
  subnetwork_name         = "prod-core-us-central1"
  cluster_name            = "prod-ai-agent-gke"
  master_ipv4_cidr_block  = var.gke_master_cidr
  authorized_master_cidrs = []
  general_pool_size       = { min = 3, max = 20 }
  ai_pool_size            = { min = 2, max = 10 }
  vector_pool_size        = { min = 2, max = 10 }
  labels                  = { env = "prod", app = "ai-agent" }
}

module "storage" {
  source     = "../../modules/storage"
  project_id = var.project_id
  location   = var.region
  buckets = [
    {
      name            = "knowledge-documents-prod"
      kms_key         = module.kms.key_ids["storage"]
      lifecycle_rules = []
    },
    {
      name            = "document-chunks-prod"
      kms_key         = module.kms.key_ids["storage"]
      lifecycle_rules = []
    },
    {
      name    = "user-uploads-prod"
      kms_key = module.kms.key_ids["storage"]
      lifecycle_rules = [
        {
          action    = { type = "Delete" }
          condition = { age = 90 }
        }
      ]
    },
    {
      name    = "backup-prod"
      kms_key = module.kms.key_ids["storage"]
      lifecycle_rules = [
        {
          action    = { type = "SetStorageClass", storage_class = "NEARLINE" }
          condition = { age = 30 }
        },
        {
          action    = { type = "SetStorageClass", storage_class = "ARCHIVE" }
          condition = { age = 180 }
        }
      ]
    },
    {
      name            = "audit-logs-archive-prod"
      kms_key         = module.kms.key_ids["storage"]
      lifecycle_rules = []
    }
  ]
}

module "pubsub" {
  source     = "../../modules/pubsub"
  project_id = var.project_id
  topics = [
    { name = "ticket-events", message_retention_duration = "604800s", kms_key = module.kms.key_ids["pubsub"] },
    { name = "notification-requests", message_retention_duration = "604800s", kms_key = module.kms.key_ids["pubsub"] },
    { name = "knowledge-updates", message_retention_duration = "604800s", kms_key = module.kms.key_ids["pubsub"] },
    { name = "action-requests", message_retention_duration = "604800s", kms_key = module.kms.key_ids["pubsub"] },
    { name = "dead-letter-queue", message_retention_duration = "1209600s", kms_key = module.kms.key_ids["pubsub"] }
  ]
}

module "redis" {
  source             = "../../modules/redis"
  project_id         = var.project_id
  region             = var.region
  name               = "prod-redis"
  authorized_network = module.vpc.network_self_link
  memory_size_gb     = 5
}

module "cloudsql" {
  source          = "../../modules/cloudsql"
  project_id      = var.project_id
  region          = var.region
  instance_name   = "prod-postgres"
  kms_key         = module.kms.key_ids["cloudsql"]
  private_network = module.vpc.network_self_link
  databases       = ["users", "audit_logs", "knowledge_metadata", "action_logs"]
  users           = []
}

module "firestore" {
  source      = "../../modules/firestore"
  project_id  = var.project_id
  location_id = "eur3"
}

module "vertex_ai" {
  source       = "../../modules/vertex_ai"
  project_id   = var.project_id
  region       = "europe-west4" # Vertex AI Matching Engine supported EU region
  display_name = "prod-kb-index"
}

# Cloud Armor Security Policy for GKE Ingress
resource "google_compute_security_policy" "gke_waf" {
  name        = "prod-gke-waf"
  description = "Example Cloud Armor policy with rate limiting"

  rule {
    priority = 200
    action   = "deny(403)"
    match {
      expr {
        expression = <<-EOT
          has(request.headers['user-agent']) && request.headers['user-agent'].contains('jndi:')
          || has(request.headers['referer']) && request.headers['referer'].contains('jndi:')
          || request.path.contains('jndi:')
          || request.query.contains('jndi:')
          || request.path.contains('$${jndi')
          || request.query.contains('$${jndi')
        EOT
      }
    }
    description = "Block Log4j/Log4Shell JNDI exploitation attempts (CVE-2021-44228)"
  }

  rule {
    priority = 1000
    action   = "rate_based_ban"
    match {
      versioned_expr = "SRC_IPS_V1"
      config { src_ip_ranges = ["*"] }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      rate_limit_threshold {
        count        = 600
        interval_sec = 60
      }
      ban_duration_sec = 600
      ban_threshold {
        count        = 1200
        interval_sec = 60
      }
    }
    description = "Basic rate limit across IPs"
  }

  rule {
    priority = 2147483647
    action   = "allow"
    match {
      versioned_expr = "SRC_IPS_V1"
      config { src_ip_ranges = ["*"] }
    }
  }
}

module "addons" {
  source = "../../modules/addons"
  providers = {
    kubernetes = kubernetes.this
    helm       = helm.this
  }
  security_policy_name   = google_compute_security_policy.gke_waf.name
  create_example_ingress = var.enable_example_ingress
  ingress_host           = var.ingress_host
  cluster_issuer         = var.cluster_issuer
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
  amount_monthly  = 15000
  thresholds      = [0.5, 0.8, 1.0]
}
