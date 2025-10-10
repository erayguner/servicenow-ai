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
    prevent_destroy = true # Protect encryption keys from accidental deletion
  }
}

