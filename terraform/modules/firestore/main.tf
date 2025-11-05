resource "google_firestore_database" "db" {
  project                           = var.project_id
  name                              = "(default)"
  location_id                       = var.location_id
  type                              = "FIRESTORE_NATIVE"
  concurrency_mode                  = "OPTIMISTIC"
  app_engine_integration_mode       = "DISABLED"
  point_in_time_recovery_enablement = "POINT_IN_TIME_RECOVERY_ENABLED"
}

output "firestore_id" { value = google_firestore_database.db.id }
