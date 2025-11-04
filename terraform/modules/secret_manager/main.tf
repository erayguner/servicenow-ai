resource "google_secret_manager_secret" "secrets" {
  for_each  = { for s in var.secrets : s.name => s }
  project   = var.project_id
  secret_id = each.value.name

  replication {
    auto {}
  }

  labels = try(each.value.labels, {})
}

resource "google_secret_manager_secret_iam_member" "access" {
  for_each  = { for k, v in var.accessors : k => v }
  secret_id = google_secret_manager_secret.secrets[each.key].id
  role      = "roles/secretmanager.secretAccessor"
  member    = element(each.value, 0)
}

output "secret_ids" { value = { for k, v in google_secret_manager_secret.secrets : k => v.id } }

