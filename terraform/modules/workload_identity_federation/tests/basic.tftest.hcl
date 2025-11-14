mock_provider "google" {}

run "plan_workload_identity_federation" {
  command = plan
  variables {
    project_id     = "test-project"
    project_number = "123456789"
    github_org     = "test-org"
    github_repo    = "test-repo"
  }

  assert {
    condition     = resource.google_iam_workload_identity_pool.github_pool.workload_identity_pool_id == "github-actions-pool"
    error_message = "Workload Identity pool must have correct ID"
  }

  assert {
    condition     = resource.google_iam_workload_identity_pool.github_pool.disabled == false
    error_message = "Workload Identity pool must be enabled"
  }

  assert {
    condition     = resource.google_iam_workload_identity_pool_provider.github_provider.workload_identity_pool_provider_id == "github-provider"
    error_message = "GitHub provider must have correct ID"
  }

  assert {
    condition     = resource.google_iam_workload_identity_pool_provider.github_provider.oidc[0].issuer_uri == "https://token.actions.githubusercontent.com"
    error_message = "Provider must use GitHub OIDC issuer"
  }

  assert {
    condition     = resource.google_iam_workload_identity_pool_provider.github_provider.attribute_condition == "assertion.sub == 'repo:test-org/test-repo:ref:refs/heads/main'"
    error_message = "Provider must restrict to main branch for security"
  }

  assert {
    condition     = resource.google_service_account.github_actions.account_id == "github-actions-ci"
    error_message = "Service account must have correct ID"
  }

  assert {
    condition     = length(resource.google_project_iam_member.github_actions_permissions) == 4
    error_message = "Must grant exactly 4 IAM roles to GitHub Actions SA"
  }

  assert {
    condition     = contains(keys(resource.google_project_iam_member.github_actions_permissions), "roles/container.developer")
    error_message = "Must grant container.developer role for GKE deployments"
  }

  assert {
    condition     = contains(keys(resource.google_project_iam_member.github_actions_permissions), "roles/artifactregistry.writer")
    error_message = "Must grant artifactregistry.writer role for image pushes"
  }

  assert {
    condition     = resource.google_service_account_iam_binding.github_actions_workload_identity.role == "roles/iam.workloadIdentityUser"
    error_message = "Must grant workloadIdentityUser role for federation"
  }
}

run "plan_workload_identity_federation_different_org" {
  command = plan
  variables {
    project_id     = "prod-project"
    project_number = "987654321"
    github_org     = "company-org"
    github_repo    = "infrastructure"
  }

  assert {
    condition     = resource.google_iam_workload_identity_pool_provider.github_provider.attribute_condition == "assertion.sub == 'repo:company-org/infrastructure:ref:refs/heads/main'"
    error_message = "Provider must use correct GitHub org and repo in condition"
  }

  assert {
    condition     = resource.google_service_account.github_actions.project == "prod-project"
    error_message = "Service account must be created in correct project"
  }

  assert {
    condition     = resource.google_iam_workload_identity_pool.github_pool.project == "prod-project"
    error_message = "Workload Identity pool must be in correct project"
  }
}
