mock_provider "google" {}

run "plan_gke" {
  command = plan
  variables {
    project_id              = "test-project"
    region                  = "europe-west2"
    network                 = "/projects/test-project/global/networks/test-core"
    subnetwork              = "/projects/test-project/regions/europe-west2/subnetworks/core-euw2"
    subnetwork_name         = "core-euw2"
    cluster_name            = "test-gke"
    master_ipv4_cidr_block  = "172.20.0.0/28"
    authorized_master_cidrs = []
    general_pool_size       = { min = 1, max = 2 }
    ai_pool_size            = { min = 0, max = 1 }
    vector_pool_size        = { min = 0, max = 1 }
    labels                  = { env = "test" }
  }

  assert {
    condition     = resource.google_container_cluster.primary.private_cluster_config[0].enable_private_nodes == true
    error_message = "Cluster must enable private nodes"
  }

  assert {
    condition     = resource.google_container_cluster.primary.workload_identity_config[0].workload_pool == "test-project.svc.id.goog"
    error_message = "Workload Identity pool must be set"
  }

  assert {
    condition     = resource.google_container_cluster.primary.network_policy[0].enabled == true
    error_message = "Network policy must be enabled"
  }
}
