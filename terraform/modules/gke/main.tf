resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region
  project  = var.project_id

  network    = var.network
  subnetwork = var.subnetwork

  resource_labels = merge(var.labels, {
    environment = var.environment
    managed_by  = "terraform"
  })

  release_channel {
    channel = var.release_channel
  }

  remove_default_node_pool    = true
  initial_node_count          = 1
  enable_intranode_visibility = true

  ip_allocation_policy {
    # Reference secondary IP ranges created in the VPC module
    cluster_secondary_range_name  = "${var.subnetwork_name}-pods"
    services_secondary_range_name = "${var.subnetwork_name}-services"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  authenticator_groups_config {
    security_group = "gke-security-groups@${var.google_domain}"
  }

  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  enable_shielded_nodes = true

  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.authorized_master_cidrs
      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
  }

  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  addons_config {
    http_load_balancing { disabled = false }
    horizontal_pod_autoscaling { disabled = false }
    gke_backup_agent_config { enabled = true }
  }

  maintenance_policy {
    daily_maintenance_window {
      start_time = "05:00"
    }
  }
}

resource "google_container_node_pool" "general" {
  name       = "general-pool"
  project    = var.project_id
  cluster    = google_container_cluster.primary.name
  location   = var.region
  node_count = var.general_pool_size.min

  autoscaling {
    min_node_count = var.general_pool_size.min
    max_node_count = var.general_pool_size.max
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type = "n2-standard-4"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
    labels       = merge(var.labels, { pool = "general" })
    tags         = concat(var.tags, ["general-pool"])
    disk_size_gb = 50
    disk_type    = "pd-standard" # Use standard disk instead of SSD

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }
}

resource "google_container_node_pool" "ai_inference" {
  name       = "ai-inference-pool"
  project    = var.project_id
  cluster    = google_container_cluster.primary.name
  location   = var.region
  node_count = var.ai_pool_size.min

  autoscaling {
    min_node_count = var.ai_pool_size.min
    max_node_count = var.ai_pool_size.max
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type = "n1-highmem-8"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
    labels = merge(var.labels, { pool = "ai-inference" })
    tags   = concat(var.tags, ["ai-inference"])
    taint {
      key    = "workload"
      value  = "ai-inference"
      effect = "NO_SCHEDULE"
    }
    disk_size_gb = 50
    disk_type    = "pd-ssd" # Keep SSD for AI workloads

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }
}

resource "google_container_node_pool" "vector" {
  name       = "vector-pool"
  project    = var.project_id
  cluster    = google_container_cluster.primary.name
  location   = var.region
  node_count = var.vector_pool_size.min

  autoscaling {
    min_node_count = var.vector_pool_size.min
    max_node_count = var.vector_pool_size.max
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type = "n2-highmem-16"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
    labels       = merge(var.labels, { pool = "vector-db" })
    tags         = concat(var.tags, ["vector-db"])
    disk_size_gb = 50
    disk_type    = "pd-ssd" # Keep SSD for vector DB

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }
}
