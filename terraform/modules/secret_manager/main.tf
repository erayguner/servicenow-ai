resource "google_secret_manager_secret" "secrets" {
  for_each  = { for s in var.secrets : s.name => s }
  project   = var.project_id
  secret_id = each.value.name

  replication {
    auto {}
  }

  # Automated rotation configuration (30-day rotation cycle)
  dynamic "rotation" {
    for_each = try(each.value.enable_rotation, false) ? [1] : []
    content {
      next_rotation_time = timeadd(timestamp(), "720h") # 30 days
      rotation_period    = "2592000s"                   # 30 days in seconds
    }
  }

  dynamic "topics" {
    for_each = try(each.value.rotation_topic, null) != null ? [1] : []
    content {
      name = each.value.rotation_topic
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
