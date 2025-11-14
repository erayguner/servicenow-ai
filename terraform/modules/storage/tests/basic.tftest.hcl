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

  assert {
    condition     = resource.google_storage_bucket.buckets["test-bucket"].versioning[0].enabled == true
    error_message = "Bucket versioning should be enabled by default"
  }
}

run "plan_storage_without_versioning" {
  command = plan
  variables {
    project_id = "test-project"
    location   = "europe-west2"
    buckets = [
      {
        name            = "test-bucket-no-version"
        kms_key         = "projects/p/locations/l/keyRings/r/cryptoKeys/k"
        versioning      = false
        lifecycle_rules = []
      }
    ]
  }

  assert {
    condition     = resource.google_storage_bucket.buckets["test-bucket-no-version"].versioning[0].enabled == false
    error_message = "Bucket versioning should be disabled when versioning = false"
  }
}
