mock_provider "google" {}

run "plan_cloudsql" {
  command = plan
  variables {
    project_id    = "test-project"
    region        = "europe-west2"
    instance_name = "test-pg"
    kms_key       = "projects/p/locations/l/keyRings/r/cryptoKeys/k"
    databases     = ["db1"]
    users         = []
  }

  assert {
    condition     = resource.google_sql_database_instance.pg.settings[0].ip_configuration[0].ipv4_enabled == false
    error_message = "Cloud SQL must disable public IPv4"
  }

  assert {
    condition     = resource.google_sql_database_instance.pg.encryption_key_name != null
    error_message = "Cloud SQL must have CMEK set"
  }
}
