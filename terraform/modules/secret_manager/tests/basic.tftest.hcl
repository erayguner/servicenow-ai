mock_provider "google" {}

run "plan_secrets" {
  command = plan
  variables {
    project_id = "test-project"
    secrets = [
      { name = "s1" },
      { name = "s2" }
    ]
  }

  assert {
    condition     = length(resource.google_secret_manager_secret.secrets) == 2
    error_message = "Expected 2 secrets to be created"
  }
}
