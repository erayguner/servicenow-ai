# Workload Identity Federation Module
# Enables GitHub Actions to authenticate to GCP without service account keys

variable "project_id" {
  type = string
}

variable "project_number" {
  type = string
}

variable "github_org" {
  type        = string
  description = "GitHub organization name"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name"
}

# Create Workload Identity Pool for GitHub Actions
resource "google_iam_workload_identity_pool" "github_pool" {
  project                   = var.project_id
  workload_identity_pool_id = "github-actions-pool"
  display_name              = "GitHub Actions"
  description               = "Identity pool for GitHub Actions CI/CD workflows"
  disabled                  = false
}

# Create Workload Identity Provider for GitHub
resource "google_iam_workload_identity_pool_provider" "github_provider" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub Actions Provider"
  description                        = "OIDC provider for GitHub Actions"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.actor"            = "assertion.actor"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
    "attribute.ref"              = "assertion.ref"
    "attribute.aud"              = "assertion.aud"
    "attribute.subject"          = "assertion.sub"
  }

  # Tighten security: validate subject pattern, repo, and refs
  # Note: Using assertion.sub check to satisfy CKV_GCP_125 while maintaining security
  attribute_condition = "assertion.sub.matches('repo:${var.github_org}/${var.github_repo}:ref:refs/(heads/(main|master)|tags/.*)') && assertion.repository == '${var.github_org}/${var.github_repo}' && assertion.aud == 'sts.googleapis.com'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Service account for GitHub Actions CI/CD
resource "google_service_account" "github_actions" {
  account_id   = "github-actions-ci"
  display_name = "GitHub Actions CI/CD Service Account"
  description  = "Service account for GitHub Actions workflows"
  project      = var.project_id
}

# Grant permissions needed for CI/CD
# Note: roles/iam.serviceAccountUser removed from project level for security.
# If service account impersonation is needed, grant it at the specific
# service account level using google_service_account_iam_member
resource "google_project_iam_member" "github_actions_permissions" {
  for_each = toset([
    "roles/container.developer",
    "roles/artifactregistry.writer",
    "roles/storage.objectAdmin",
    "roles/logging.logWriter",
  ])

  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

# Allow GitHub Actions to impersonate the CI/CD service account
resource "google_service_account_iam_binding" "github_actions_workload_identity" {
  service_account_id = google_service_account.github_actions.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_pool.name}/attribute.repository/${var.github_org}/${var.github_repo}"
  ]
}

# Outputs for GitHub Actions workflow configuration
output "workload_identity_provider" {
  description = "Full provider name to use in GitHub Actions workflow"
  value       = "projects/${var.project_number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github_pool.workload_identity_pool_id}/providers/${google_iam_workload_identity_pool_provider.github_provider.workload_identity_pool_provider_id}"
}

output "service_account_email" {
  description = "Service account email to use in GitHub Actions workflow"
  value       = google_service_account.github_actions.email
}

output "github_workflow_example" {
  description = "Example GitHub Actions workflow configuration"
  value       = <<-EOT
    # Add this to your .github/workflows/deploy.yml

    - id: auth
      uses: google-github-actions/auth@v1
      with:
        workload_identity_provider: 'projects/${var.project_number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github_pool.workload_identity_pool_id}/providers/${google_iam_workload_identity_pool_provider.github_provider.workload_identity_pool_provider_id}'
        service_account: '${google_service_account.github_actions.email}'
  EOT
}
