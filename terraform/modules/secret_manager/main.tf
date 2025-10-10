resource "google_secret_manager_secret" "secrets" {
  for_each  = { for s in var.secrets : s.name => s }
  project   = var.project_id
  secret_id = each.value.name

  replication {
    dynamic "user_managed" {
      for_each = each.value.replication.automatic ? [] : [1]
      content {
        dynamic "replicas" {
          for_each = toset(try(each.value.replication.locations, []))
          content { location = replicas.value }
        }
      }
    }
    dynamic "automatic" {
      for_each = each.value.replication.automatic ? [1] : []
      content {}
    }
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

