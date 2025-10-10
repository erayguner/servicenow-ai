# Workload Identity Module
# Creates GCP service accounts and IAM bindings for GKE pods

variable "project_id" {
  type = string
}

variable "namespace" {
  type    = string
  default = "production"
}

variable "services" {
  description = "Map of service configurations"
  type = map(object({
    display_name = string
    gcp_roles    = list(string)
  }))
}

# Create GCP Service Accounts for each microservice
resource "google_service_account" "service_accounts" {
  for_each = var.services

  account_id   = each.key
  display_name = each.value.display_name
  project      = var.project_id
}

# Grant GCP permissions to each service account
resource "google_project_iam_member" "service_permissions" {
  for_each = {
    for pair in flatten([
      for service_key, service in var.services : [
        for role in service.gcp_roles : {
          key     = "${service_key}-${role}"
          service = service_key
          role    = role
        }
      ]
    ]) : pair.key => pair
  }

  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.service_accounts[each.value.service].email}"
}

# Allow Kubernetes ServiceAccounts to impersonate GCP ServiceAccounts (Workload Identity)
resource "google_service_account_iam_binding" "workload_identity_binding" {
  for_each = var.services

  service_account_id = google_service_account.service_accounts[each.key].name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[${var.namespace}/${each.key}-sa]"
  ]
}

# Outputs
output "service_account_emails" {
  description = "Map of service names to their GCP service account emails"
  value = {
    for k, v in google_service_account.service_accounts : k => v.email
  }
}

output "kubernetes_service_account_annotations" {
  description = "Annotations to add to Kubernetes ServiceAccounts"
  value = {
    for k, v in google_service_account.service_accounts :
    k => "iam.gke.io/gcp-service-account: ${v.email}"
  }
}
