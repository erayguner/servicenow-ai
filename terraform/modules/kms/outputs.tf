output "keyring_id" {
  description = "The ID of the KMS keyring"
  value       = google_kms_key_ring.ring.id
}

output "keyring_name" {
  description = "The name of the KMS keyring"
  value       = google_kms_key_ring.ring.name
}

output "key_ids" {
  description = "Map of key names to their full resource IDs"
  value       = { for k, v in google_kms_crypto_key.keys : k => v.id }
}

output "key_self_links" {
  description = "Map of key names to their self-links"
  value       = { for k, v in google_kms_crypto_key.keys : k => v.id }
}
