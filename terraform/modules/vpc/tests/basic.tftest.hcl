mock_provider "google" {}

run "plan_vpc" {
  command = plan
  variables {
    project_id   = "test-project"
    region       = "europe-west2"
    network_name = "test-core"
    nat_enabled  = true
    nat_ip_count = 2
    subnets = [
      {
        name                    = "core-euw2"
        ip_cidr_range           = "10.10.0.0/20"
        region                  = "europe-west2"
        private_google_access   = true
        secondary_ip_range_pods = "10.20.0.0/16"
        secondary_ip_range_svc  = "10.30.0.0/20"
      }
    ]
  }

  assert {
    condition     = resource.google_compute_network.vpc.name == "test-core"
    error_message = "VPC name should be test-core"
  }

  assert {
    condition     = resource.google_compute_router_nat.nat[0].nat_ip_allocate_option == "MANUAL_ONLY"
    error_message = "NAT must use MANUAL_ONLY when static IPs are requested"
  }
}
