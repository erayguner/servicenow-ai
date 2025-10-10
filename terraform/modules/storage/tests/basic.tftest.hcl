mock_provider "google" {}

run "plan_storage" {
  command = plan
  variables {
    project_id = "test-project"
    location   = "europe-west2"
    buckets = [
      {
        name            = "test-bucket"
        kms_key         = "projects/p/locations/l/keyRings/r/cryptoKeys/k"
        lifecycle_rules = []
      }
    ]
  }

  assert {
    condition     = resource.google_storage_bucket.buckets["test-bucket"].name == "test-bucket"
    error_message = "Bucket name mismatch"
  }

  assert {
    condition     = resource.google_storage_bucket.buckets["test-bucket"].encryption[0].default_kms_key_name != ""
    error_message = "Bucket must have CMEK set"
  }
}
