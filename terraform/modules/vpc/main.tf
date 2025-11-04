resource "google_compute_network" "vpc" {
  name                    = var.network_name
  auto_create_subnetworks = false
  project                 = var.project_id
  routing_mode            = "GLOBAL"
}

resource "google_compute_subnetwork" "subnets" {
  for_each                 = { for s in var.subnets : s.name => s }
  project                  = var.project_id
  name                     = each.value.name
  ip_cidr_range            = each.value.ip_cidr_range
  region                   = each.value.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = each.value.private_google_access

  secondary_ip_range {
    range_name    = "${each.value.name}-pods"
    ip_cidr_range = each.value.secondary_ip_range_pods
  }
  secondary_ip_range {
    range_name    = "${each.value.name}-services"
    ip_cidr_range = each.value.secondary_ip_range_svc
  }

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_router" "router" {
  count   = var.nat_enabled ? 1 : 0
  name    = var.router_name
  network = google_compute_network.vpc.name
  region  = var.region
  project = var.project_id
}

resource "google_compute_address" "nat_ips" {
  count   = var.nat_enabled && var.nat_ip_count > 0 ? var.nat_ip_count : 0
  name    = "${var.nat_name}-${count.index}"
  project = var.project_id
  region  = var.region
}

resource "google_compute_router_nat" "nat" {
  count                               = var.nat_enabled ? 1 : 0
  name                                = var.nat_name
  router                              = google_compute_router.router[0].name
  region                              = var.region
  project                             = var.project_id
  nat_ip_allocate_option              = length(google_compute_address.nat_ips) > 0 ? "MANUAL_ONLY" : "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat  = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  enable_endpoint_independent_mapping = true
  nat_ips                             = length(google_compute_address.nat_ips) > 0 ? [for ip in google_compute_address.nat_ips : ip.self_link] : null

  log_config {
    enable = true
    filter = "ALL"
  }
}

# Private Service Connection for Cloud SQL
resource "google_compute_global_address" "private_ip_address" {
  name          = "${var.network_name}-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
  project       = var.project_id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

# Default firewall: deny-all, then explicit allows are expected per service
resource "google_compute_firewall" "deny_all_egress" {
  count    = var.create_fw_default_deny ? 1 : 0
  name     = "${var.network_name}-deny-all-egress"
  project  = var.project_id
  network  = google_compute_network.vpc.name
  priority = 65534

  direction = "EGRESS"
  deny {
    protocol = "all"
  }
  destination_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "deny_all_ingress" {
  count    = var.create_fw_default_deny ? 1 : 0
  name     = "${var.network_name}-deny-all-ingress"
  project  = var.project_id
  network  = google_compute_network.vpc.name
  priority = 65534

  direction = "INGRESS"
  deny {
    protocol = "all"
  }
  source_ranges = ["0.0.0.0/0"]
}
