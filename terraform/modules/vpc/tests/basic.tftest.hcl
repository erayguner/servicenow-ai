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

  assert {
    condition     = resource.google_compute_network.vpc.auto_create_subnetworks == false
    error_message = "Auto-create subnetworks should be disabled for custom VPC"
  }

  assert {
    condition     = resource.google_compute_network.vpc.routing_mode == "GLOBAL"
    error_message = "VPC routing mode should be GLOBAL"
  }
}

run "plan_vpc_with_serverless_connector" {
  command = plan
  variables {
    project_id                         = "test-project"
    region                             = "us-central1"
    network_name                       = "test-vpc-serverless"
    enable_serverless_connector        = true
    serverless_connector_name          = "test-connector"
    serverless_connector_cidr          = "10.8.0.0/28"
    serverless_connector_min_instances = 2
    serverless_connector_max_instances = 3
    subnets = [
      {
        name                    = "subnet-usc1"
        ip_cidr_range           = "10.10.0.0/20"
        region                  = "us-central1"
        private_google_access   = true
        secondary_ip_range_pods = "10.20.0.0/16"
        secondary_ip_range_svc  = "10.30.0.0/20"
      }
    ]
  }

  assert {
    condition     = length([for c in resource.google_vpc_access_connector.connector : c]) == 1
    error_message = "Serverless VPC connector should be created when enabled"
  }

  assert {
    condition     = resource.google_vpc_access_connector.connector[0].ip_cidr_range == "10.8.0.0/28"
    error_message = "Connector should use specified CIDR range"
  }

  assert {
    condition     = resource.google_vpc_access_connector.connector[0].min_instances == 2
    error_message = "Connector should have correct min instances"
  }

  assert {
    condition     = resource.google_vpc_access_connector.connector[0].max_instances == 3
    error_message = "Connector should have correct max instances"
  }
}

run "plan_vpc_without_serverless_connector" {
  command = plan
  variables {
    project_id                  = "test-project"
    region                      = "us-central1"
    network_name                = "test-vpc-no-serverless"
    enable_serverless_connector = false
    subnets = [
      {
        name                    = "subnet-usc1"
        ip_cidr_range           = "10.10.0.0/20"
        region                  = "us-central1"
        private_google_access   = true
        secondary_ip_range_pods = "10.20.0.0/16"
        secondary_ip_range_svc  = "10.30.0.0/20"
      }
    ]
  }

  assert {
    condition     = length([for c in resource.google_vpc_access_connector.connector : c]) == 0
    error_message = "Serverless VPC connector should not be created when disabled"
  }
}

run "plan_vpc_with_firewall_rules" {
  command = plan
  variables {
    project_id                  = "test-project"
    region                      = "us-central1"
    network_name                = "test-vpc-fw"
    enable_serverless_connector = true
    serverless_connector_cidr   = "10.8.0.0/28"
    subnets = [
      {
        name                    = "subnet-usc1"
        ip_cidr_range           = "10.10.0.0/20"
        region                  = "us-central1"
        private_google_access   = true
        secondary_ip_range_pods = "10.20.0.0/16"
        secondary_ip_range_svc  = "10.30.0.0/20"
      }
    ]
  }

  assert {
    condition     = length([for fw in resource.google_compute_firewall.serverless_to_vpc : fw]) == 1
    error_message = "Firewall rule for serverless traffic should be created"
  }

  assert {
    condition     = contains(resource.google_compute_firewall.serverless_to_vpc[0].source_ranges, "10.8.0.0/28")
    error_message = "Firewall should allow traffic from serverless connector CIDR"
  }

  assert {
    condition     = length([for fw in resource.google_compute_firewall.serverless_health_checks : fw]) == 1
    error_message = "Firewall rule for health checks should be created"
  }
}
