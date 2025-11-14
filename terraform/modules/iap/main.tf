# Identity-Aware Proxy (IAP) configuration for Cloud Run services
# Provides authentication and authorization for internal web UI

# IAP Brand (OAuth consent screen)
resource "google_iap_brand" "project_brand" {
  count             = var.create_brand ? 1 : 0
  project           = var.project_id
  support_email     = var.support_email
  application_title = var.application_title
}

# IAP OAuth Client
resource "google_iap_client" "iap_client" {
  count        = var.create_oauth_client ? 1 : 0
  display_name = var.oauth_client_display_name
  brand        = var.create_brand ? google_iap_brand.project_brand[0].name : var.brand_name
}

# Backend service for Internal Load Balancer
resource "google_compute_backend_service" "default" {
  name                  = "${var.service_name}-backend"
  project               = var.project_id
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 30
  enable_cdn            = false
  load_balancing_scheme = "INTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.cloud_run_neg.id
  }

  iap {
    oauth2_client_id     = var.create_oauth_client ? google_iap_client.iap_client[0].client_id : var.oauth_client_id
    oauth2_client_secret = var.create_oauth_client ? google_iap_client.iap_client[0].secret : var.oauth_client_secret
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

# Network Endpoint Group for Cloud Run
resource "google_compute_region_network_endpoint_group" "cloud_run_neg" {
  name                  = "${var.service_name}-neg"
  project               = var.project_id
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = var.cloud_run_service_name
  }
}

# URL Map for Load Balancer
resource "google_compute_region_url_map" "default" {
  name            = "${var.service_name}-url-map"
  project         = var.project_id
  region          = var.region
  default_service = google_compute_backend_service.default.id
}

# HTTP Target Proxy
resource "google_compute_region_target_http_proxy" "default" {
  name    = "${var.service_name}-http-proxy"
  project = var.project_id
  region  = var.region
  url_map = google_compute_region_url_map.default.id
}

# HTTPS Target Proxy (if SSL certificate provided)
resource "google_compute_region_target_https_proxy" "default" {
  count           = var.ssl_certificate != null ? 1 : 0
  name            = "${var.service_name}-https-proxy"
  project         = var.project_id
  region          = var.region
  url_map         = google_compute_region_url_map.default.id
  ssl_certificates = [var.ssl_certificate]
}

# Forwarding Rule for HTTP
resource "google_compute_forwarding_rule" "http" {
  name                  = "${var.service_name}-http-forwarding-rule"
  project               = var.project_id
  region                = var.region
  ip_protocol           = "TCP"
  load_balancing_scheme = "INTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_region_target_http_proxy.default.id
  network               = var.network
  subnetwork            = var.subnetwork
  network_tier          = "PREMIUM"
}

# Forwarding Rule for HTTPS
resource "google_compute_forwarding_rule" "https" {
  count                 = var.ssl_certificate != null ? 1 : 0
  name                  = "${var.service_name}-https-forwarding-rule"
  project               = var.project_id
  region                = var.region
  ip_protocol           = "TCP"
  load_balancing_scheme = "INTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_region_target_https_proxy.default[0].id
  network               = var.network
  subnetwork            = var.subnetwork
  network_tier          = "PREMIUM"
}

# IAM policy to allow specific users/groups access
resource "google_iap_web_backend_service_iam_binding" "iap_access" {
  project             = var.project_id
  web_backend_service = google_compute_backend_service.default.name
  role                = "roles/iap.httpsResourceAccessor"
  members             = var.iap_access_members
}

# Health check for backend service
resource "google_compute_region_health_check" "default" {
  name    = "${var.service_name}-health-check"
  project = var.project_id
  region  = var.region

  http_health_check {
    port         = 80
    request_path = var.health_check_path
  }

  timeout_sec         = 5
  check_interval_sec  = 10
  healthy_threshold   = 2
  unhealthy_threshold = 3
}
