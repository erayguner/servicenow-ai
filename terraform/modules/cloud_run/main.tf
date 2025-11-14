# Cloud Run service for AI research assistant backend and frontend
# Configured for internal-only access with IAP protection

resource "google_cloud_run_v2_service" "service" {
  name     = var.service_name
  project  = var.project_id
  location = var.region
  ingress  = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

  template {
    service_account = var.service_account_email

    vpc_access {
      connector = var.vpc_connector
      egress    = "PRIVATE_RANGES_ONLY"
    }

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    containers {
      image = var.image

      dynamic "env" {
        for_each = var.environment_variables
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = var.secret_environment_variables
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value.secret
              version = env.value.version
            }
          }
        }
      }

      resources {
        limits = {
          cpu    = var.cpu_limit
          memory = var.memory_limit
        }
        cpu_idle = var.cpu_always_allocated
      }

      ports {
        name           = "http1"
        container_port = var.container_port
      }

      startup_probe {
        http_get {
          path = var.health_check_path
        }
        initial_delay_seconds = 10
        timeout_seconds       = 3
        period_seconds        = 10
        failure_threshold     = 3
      }

      liveness_probe {
        http_get {
          path = var.health_check_path
        }
        initial_delay_seconds = 30
        timeout_seconds       = 3
        period_seconds        = 30
        failure_threshold     = 3
      }
    }

    labels = merge(
      var.labels,
      {
        managed-by = "terraform"
      }
    )
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
      client,
      client_version
    ]
  }
}

# IAM policy to allow IAP to invoke Cloud Run
resource "google_cloud_run_service_iam_member" "iap_invoker" {
  count    = var.enable_iap ? 1 : 0
  project  = var.project_id
  location = var.region
  service  = google_cloud_run_v2_service.service.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-iap.iam.gserviceaccount.com"
}

# IAM policy for authenticated users (if not using IAP)
resource "google_cloud_run_service_iam_member" "authenticated_invoker" {
  count    = var.enable_iap ? 0 : 1
  project  = var.project_id
  location = var.region
  service  = google_cloud_run_v2_service.service.name
  role     = "roles/run.invoker"
  member   = var.authenticated_member
}

# Service account for Cloud Run service
resource "google_service_account" "cloud_run_sa" {
  count        = var.create_service_account ? 1 : 0
  project      = var.project_id
  account_id   = "${var.service_name}-sa"
  display_name = "Service account for ${var.service_name}"
}

# Grant Cloud Run SA access to Secret Manager
resource "google_secret_manager_secret_iam_member" "secret_access" {
  for_each = var.secret_environment_variables
  project  = var.project_id
  secret_id = each.value.secret
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.service_account_email}"
}

# Grant Cloud Run SA access to Cloud SQL (if needed)
resource "google_project_iam_member" "cloudsql_client" {
  count   = var.enable_cloud_sql_access ? 1 : 0
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${var.service_account_email}"
}

# Grant Cloud Run SA access to Firestore (if needed)
resource "google_project_iam_member" "firestore_user" {
  count   = var.enable_firestore_access ? 1 : 0
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${var.service_account_email}"
}

# Grant Cloud Run SA access to Cloud Storage (if needed)
resource "google_storage_bucket_iam_member" "storage_access" {
  for_each = var.storage_buckets
  bucket   = each.value
  role     = "roles/storage.objectViewer"
  member   = "serviceAccount:${var.service_account_email}"
}

# Grant Cloud Run SA access to logging
resource "google_project_iam_member" "log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${var.service_account_email}"
}

# Grant Cloud Run SA access to monitoring
resource "google_project_iam_member" "monitoring_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${var.service_account_email}"
}

# Grant Cloud Run SA access to error reporting
resource "google_project_iam_member" "error_reporter" {
  project = var.project_id
  role    = "roles/errorreporting.writer"
  member  = "serviceAccount:${var.service_account_email}"
}

data "google_project" "project" {
  project_id = var.project_id
}
