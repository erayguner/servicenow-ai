mock_provider "google" {}

run "plan_cloudsql" {
  command = plan
  variables {
    project_id          = "test-project"
    region              = "europe-west2"
    instance_name       = "test-pg"
    kms_key             = "projects/p/locations/l/keyRings/r/cryptoKeys/k"
    databases           = ["db1"]
    users               = []
    enable_read_replica = false
    replica_region      = null
    replica_tier        = null
  }

  assert {
    condition     = resource.google_sql_database_instance.pg.settings[0].ip_configuration[0].ipv4_enabled == false
    error_message = "Cloud SQL must disable public IPv4"
  }

  assert {
    condition     = resource.google_sql_database_instance.pg.encryption_key_name != null
    error_message = "Cloud SQL must have CMEK set"
  }

  assert {
    condition     = resource.google_sql_database_instance.pg.settings[0].backup_configuration[0].enabled == true
    error_message = "Cloud SQL must have backups enabled"
  }
}

run "plan_cloudsql_with_replica" {
  command = plan
  variables {
    project_id          = "test-project"
    region              = "europe-west2"
    instance_name       = "test-pg-dr"
    kms_key             = "projects/p/locations/l/keyRings/r/cryptoKeys/k"
    databases           = ["db1"]
    users               = []
    enable_read_replica = true
    replica_region      = "europe-west2"
    replica_tier        = "db-n1-standard-2"
  }

  assert {
    condition     = resource.google_sql_database_instance.replica[0].master_instance_name == "test-pg-dr"
    error_message = "Replica must reference correct master instance"
  }

  assert {
    condition     = resource.google_sql_database_instance.replica[0].replica_configuration[0].failover_target == true
    error_message = "Replica must be configured as failover target for DR"
  }

  assert {
    condition     = resource.google_sql_database_instance.replica[0].region == "europe-west2"
    error_message = "Replica region must match configuration"
  }

  assert {
    condition     = resource.google_sql_database_instance.replica[0].encryption_key_name != null
    error_message = "Replica must also have CMEK encryption"
  }
}
