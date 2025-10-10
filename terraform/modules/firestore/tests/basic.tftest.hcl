mock_provider "google" {}

run "plan_firestore" {
  command = plan
  variables {
    project_id          = "test-project"
    location_id         = "eur3"
    deletion_protection = true
  }

  assert {
    condition     = resource.google_firestore_database.db.location_id == "eur3"
    error_message = "Firestore must be created in eur3"
  }

  assert {
    condition     = resource.google_firestore_database.db.type == "FIRESTORE_NATIVE"
    error_message = "Firestore must be in native mode"
  }
}
