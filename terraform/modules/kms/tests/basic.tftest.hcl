mock_provider "google" {}

run "plan_kms" {
  command = plan
  variables {
    project_id   = "test-project"
    location     = "europe-west2"
    keyring_name = "test-kr"
    keys = {
      storage  = "7776000s"
      pubsub   = "7776000s"
      cloudsql = "7776000s"
      secrets  = "7776000s"
    }
  }

  assert {
    condition     = resource.google_kms_key_ring.ring.name == "test-kr"
    error_message = "Key ring name mismatch"
  }

  assert {
    condition     = length(resource.google_kms_crypto_key.keys) >= 4
    error_message = "Expected at least 4 KMS keys"
  }
}
