resource "google_kms_key_ring" "ring" {
  name     = var.keyring_name
  project  = var.project_id
  location = var.location
}

resource "google_kms_crypto_key" "keys" {
  for_each        = var.keys
  name            = each.key
  key_ring        = google_kms_key_ring.ring.id
  rotation_period = each.value
  purpose         = "ENCRYPT_DECRYPT"

  lifecycle {
    prevent_destroy = false # Protect encryption keys from accidental deletion
  }
}

# Grant Pub/Sub service account access to pubsub key
resource "google_kms_crypto_key_iam_member" "pubsub_key_encrypter" {
  crypto_key_id = google_kms_crypto_key.keys["pubsub"].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

# Grant Storage service account access to storage key
resource "google_kms_crypto_key_iam_member" "storage_key_encrypter" {
  crypto_key_id = google_kms_crypto_key.keys["storage"].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.project.number}@gs-project-accounts.iam.gserviceaccount.com"
}

# Grant Cloud SQL service account access to cloudsql key
resource "google_kms_crypto_key_iam_member" "cloudsql_key_encrypter" {
  crypto_key_id = google_kms_crypto_key.keys["cloudsql"].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-cloud-sql.iam.gserviceaccount.com"
}

# Get project number
data "google_project" "project" {
  project_id = var.project_id
}
