# Workload Identity Configuration for Production
# This file configures both GKE Workload Identity and Workload Identity Federation

# GKE Workload Identity - Service accounts for microservices
module "workload_identity" {
  source     = "../../modules/workload_identity"
  project_id = var.project_id
  namespace  = "production"

  services = {
    conversation-manager = {
      display_name = "Conversation Manager Service"
      gcp_roles = [
        "roles/datastore.user",               # Firestore access
        "roles/pubsub.publisher",             # Pub/Sub publish
        "roles/secretmanager.secretAccessor", # Secrets access
      ]
    }

    llm-gateway = {
      display_name = "LLM Gateway Service"
      gcp_roles = [
        "roles/aiplatform.user",              # Vertex AI access
        "roles/secretmanager.secretAccessor", # API keys
        "roles/logging.logWriter",            # Logging
      ]
    }

    knowledge-base = {
      display_name = "Knowledge Base Service"
      gcp_roles = [
        "roles/aiplatform.user",      # Vertex AI Matching Engine
        "roles/storage.objectViewer", # GCS read for documents
        "roles/datastore.user",       # Metadata storage
      ]
    }

    ticket-monitor = {
      display_name = "Ticket Monitor Service"
      gcp_roles = [
        "roles/pubsub.publisher",             # Publish ticket events
        "roles/secretmanager.secretAccessor", # ServiceNow credentials
        "roles/datastore.user",               # State management
      ]
    }

    action-executor = {
      display_name = "Action Executor Service"
      gcp_roles = [
        "roles/pubsub.subscriber",            # Subscribe to action requests
        "roles/secretmanager.secretAccessor", # Credentials
        "roles/datastore.user",               # Audit logging
        "roles/logging.logWriter",            # Logging
      ]
    }

    notification-service = {
      display_name = "Notification Service"
      gcp_roles = [
        "roles/pubsub.subscriber",            # Subscribe to notifications
        "roles/secretmanager.secretAccessor", # Slack credentials
        "roles/logging.logWriter",            # Logging
      ]
    }

    internal-web-ui = {
      display_name = "Internal Web UI Service"
      gcp_roles = [
        "roles/datastore.user",    # Session data
        "roles/logging.logWriter", # Logging
      ]
    }

    api-gateway = {
      display_name = "API Gateway Service"
      gcp_roles = [
        "roles/datastore.user",    # Rate limiting data
        "roles/logging.logWriter", # Logging
      ]
    }

    analytics-service = {
      display_name = "Analytics Service"
      gcp_roles = [
        "roles/datastore.user",      # Read conversation data
        "roles/bigquery.dataEditor", # Write to BigQuery
        "roles/logging.logWriter",   # Logging
      ]
    }

    document-ingestion = {
      display_name = "Document Ingestion Service"
      gcp_roles = [
        "roles/storage.objectAdmin", # GCS read/write
        "roles/aiplatform.user",     # Generate embeddings
        "roles/datastore.user",      # Store metadata
        "roles/pubsub.publisher",    # Publish ingestion events
      ]
    }
  }
}

# Workload Identity Federation - GitHub Actions CI/CD
module "workload_identity_federation" {
  source = "../../modules/workload_identity_federation"

  project_id     = var.project_id
  project_number = data.google_project.project.number
  github_org     = var.github_org
  github_repo    = var.github_repo
}

# Get project number for WIF configuration
data "google_project" "project" {
  project_id = var.project_id
}

# Outputs for Kubernetes configuration
output "workload_identity_service_accounts" {
  description = "GCP service account emails for each microservice"
  value       = module.workload_identity.service_account_emails
  sensitive   = false
}

output "kubernetes_sa_annotations" {
  description = "Annotations to add to Kubernetes ServiceAccounts"
  value       = module.workload_identity.kubernetes_service_account_annotations
  sensitive   = false
}

# Outputs for GitHub Actions configuration
output "github_actions_workload_identity_provider" {
  description = "Workload Identity Provider for GitHub Actions"
  value       = module.workload_identity_federation.workload_identity_provider
  sensitive   = false
}

output "github_actions_service_account" {
  description = "Service account email for GitHub Actions"
  value       = module.workload_identity_federation.service_account_email
  sensitive   = false
}

output "github_workflow_configuration" {
  description = "Copy this to your GitHub Actions workflow"
  value       = module.workload_identity_federation.github_workflow_example
}
