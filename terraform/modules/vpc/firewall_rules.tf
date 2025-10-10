# Explicit firewall allow rules for GKE cluster
# These are required when default-deny rules are enabled

resource "google_compute_firewall" "allow_gke_internal" {
  count    = var.create_fw_default_deny ? 1 : 0
  name     = "${var.network_name}-allow-gke-internal"
  project  = var.project_id
  network  = google_compute_network.vpc.name
  priority = 1000

  description = "Allow internal GKE node communication"

  allow {
    protocol = "tcp"
    ports    = ["443", "10250", "10255", "8443"]
  }

  allow {
    protocol = "udp"
    ports    = ["53"]
  }

  source_ranges = concat(
    [for s in var.subnets : s.ip_cidr_range],
    [for s in var.subnets : s.secondary_ip_range_pods],
    [for s in var.subnets : s.secondary_ip_range_svc]
  )

  target_tags = ["gke-node"]
}

resource "google_compute_firewall" "allow_gke_webhooks" {
  count    = var.create_fw_default_deny ? 1 : 0
  name     = "${var.network_name}-allow-gke-webhooks"
  project  = var.project_id
  network  = google_compute_network.vpc.name
  priority = 1000

  description = "Allow GKE control plane to access webhooks on nodes"

  allow {
    protocol = "tcp"
    ports    = ["443", "8443", "9443", "15017"]
  }

  # GKE control plane CIDR (must match master_ipv4_cidr_block)
  source_ranges = ["172.16.0.0/28"]
  target_tags   = ["gke-node"]
}

resource "google_compute_firewall" "allow_health_checks" {
  count    = var.create_fw_default_deny ? 1 : 0
  name     = "${var.network_name}-allow-health-checks"
  project  = var.project_id
  network  = google_compute_network.vpc.name
  priority = 1000

  description = "Allow Google Cloud health checks"

  allow {
    protocol = "tcp"
  }

  # Google Cloud health check IP ranges
  source_ranges = [
    "35.191.0.0/16",
    "130.211.0.0/22"
  ]

  target_tags = ["gke-node", "allow-health-check"]
}

resource "google_compute_firewall" "allow_istio" {
  count    = var.create_fw_default_deny ? 1 : 0
  name     = "${var.network_name}-allow-istio"
  project  = var.project_id
  network  = google_compute_network.vpc.name
  priority = 1000

  description = "Allow Istio service mesh communication"

  allow {
    protocol = "tcp"
    ports    = ["15012", "15014", "15017", "15021"]
  }

  source_ranges = [for s in var.subnets : s.secondary_ip_range_pods]
  target_tags   = ["gke-node"]
}

resource "google_compute_firewall" "allow_egress_google_apis" {
  count     = var.create_fw_default_deny ? 1 : 0
  name      = "${var.network_name}-allow-egress-google-apis"
  project   = var.project_id
  network   = google_compute_network.vpc.name
  priority  = 1000
  direction = "EGRESS"

  description = "Allow egress to Google APIs (Private Google Access)"

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  destination_ranges = ["199.36.153.8/30"] # Private Google Access
}

resource "google_compute_firewall" "allow_egress_dns" {
  count     = var.create_fw_default_deny ? 1 : 0
  name      = "${var.network_name}-allow-egress-dns"
  project   = var.project_id
  network   = google_compute_network.vpc.name
  priority  = 1000
  direction = "EGRESS"

  description = "Allow DNS queries"

  allow {
    protocol = "tcp"
    ports    = ["53"]
  }

  allow {
    protocol = "udp"
    ports    = ["53"]
  }

  destination_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_egress_ntp" {
  count     = var.create_fw_default_deny ? 1 : 0
  name      = "${var.network_name}-allow-egress-ntp"
  project   = var.project_id
  network   = google_compute_network.vpc.name
  priority  = 1000
  direction = "EGRESS"

  description = "Allow NTP time synchronization"

  allow {
    protocol = "udp"
    ports    = ["123"]
  }

  destination_ranges = ["0.0.0.0/0"]
}
