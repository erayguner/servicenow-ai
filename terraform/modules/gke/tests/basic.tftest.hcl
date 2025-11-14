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
    environment             = "dev"
    enable_spot_instances   = false
    spot_instance_pools     = []
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

  assert {
    condition     = resource.google_container_cluster.primary.binary_authorization[0].evaluation_mode == "PROJECT_SINGLETON_POLICY_ENFORCE"
    error_message = "Binary Authorization must be enabled"
  }
}

run "plan_gke_with_spot_instances" {
  command = plan
  variables {
    project_id              = "test-project"
    region                  = "europe-west2"
    network                 = "/projects/test-project/global/networks/test-core"
    subnetwork              = "/projects/test-project/regions/europe-west2/subnetworks/core-euw2"
    subnetwork_name         = "core-euw2"
    cluster_name            = "test-gke-spot"
    master_ipv4_cidr_block  = "172.20.0.0/28"
    authorized_master_cidrs = []
    general_pool_size       = { min = 1, max = 2 }
    ai_pool_size            = { min = 0, max = 1 }
    vector_pool_size        = { min = 0, max = 1 }
    labels                  = { env = "dev" }
    environment             = "dev"
    enable_spot_instances   = true
    spot_instance_pools     = ["general"]
  }

  assert {
    condition     = resource.google_container_node_pool.general.node_config[0].spot == true
    error_message = "General pool should use spot instances when enabled"
  }

  assert {
    condition     = resource.google_container_node_pool.general.node_config[0].preemptible == true
    error_message = "General pool should be preemptible when spot enabled"
  }
}
