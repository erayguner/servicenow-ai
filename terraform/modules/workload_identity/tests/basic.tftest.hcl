mock_provider "google" {}

run "plan_workload_identity" {
  command = plan
  variables {
    project_id = "test-project"
    namespace  = "production"
    services = {
      llm-gateway = {
        display_name = "LLM Gateway Service Account"
        gcp_roles = [
          "roles/aiplatform.user",
          "roles/secretmanager.secretAccessor"
        ]
      }
      conversation-manager = {
        display_name = "Conversation Manager Service Account"
        gcp_roles = [
          "roles/cloudsql.client",
          "roles/secretmanager.secretAccessor"
        ]
      }
    }
  }

  assert {
    condition     = length(keys(resource.google_service_account.service_accounts)) == 2
    error_message = "Must create service accounts for all services"
  }

  assert {
    condition     = resource.google_service_account.service_accounts["llm-gateway"].account_id == "llm-gateway"
    error_message = "Service account ID must match service name"
  }

  assert {
    condition     = resource.google_service_account_iam_binding.workload_identity_binding["llm-gateway"].role == "roles/iam.workloadIdentityUser"
    error_message = "Workload Identity binding must use correct role"
  }

  assert {
    condition     = contains(resource.google_service_account_iam_binding.workload_identity_binding["llm-gateway"].members, "serviceAccount:test-project.svc.id.goog[production/llm-gateway-sa]")
    error_message = "Workload Identity binding must reference correct K8s ServiceAccount"
  }

  assert {
    condition     = resource.google_project_iam_member.service_permissions["llm-gateway-roles/aiplatform.user"].role == "roles/aiplatform.user"
    error_message = "IAM bindings must grant correct GCP roles"
  }
}

run "plan_workload_identity_dev_namespace" {
  command = plan
  variables {
    project_id = "test-project"
    namespace  = "development"
    services = {
      test-service = {
        display_name = "Test Service Account"
        gcp_roles    = ["roles/storage.objectViewer"]
      }
    }
  }

  assert {
    condition     = contains(resource.google_service_account_iam_binding.workload_identity_binding["test-service"].members, "serviceAccount:test-project.svc.id.goog[development/test-service-sa]")
    error_message = "Workload Identity must use correct namespace in binding"
  }

  assert {
    condition     = resource.google_service_account.service_accounts["test-service"].project == "test-project"
    error_message = "Service account must be created in correct project"
  }
}
