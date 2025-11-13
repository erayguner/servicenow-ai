resource "google_redis_instance" "cache" {
  name                    = var.name
  project                 = var.project_id
  region                  = var.region
  tier                    = var.tier
  memory_size_gb          = var.memory_size_gb
  redis_version           = var.redis_version
  authorized_network      = var.authorized_network
  transit_encryption_mode = "SERVER_AUTHENTICATION"
  auth_enabled            = true
  maintenance_policy {
    weekly_maintenance_window {
      day = "SUNDAY"
      start_time {
        hours   = 5
        minutes = 0
      }
    }
  }
}

output "redis_host" { value = google_redis_instance.cache.host }
output "redis_port" { value = google_redis_instance.cache.port }
output "redis_auth_string" {
  value     = google_redis_instance.cache.auth_string
  sensitive = true
}
