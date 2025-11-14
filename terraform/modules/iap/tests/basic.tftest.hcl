mock_provider "google" {}

run "test_iap_with_manual_oauth" {
  command = plan

  variables {
    project_id             = "test-project"
    region                 = "us-central1"
    service_name           = "test-service"
    cloud_run_service_name = "test-cloud-run-service"
    network                = "projects/test-project/global/networks/test-vpc"
    subnetwork             = "projects/test-project/regions/us-central1/subnetworks/test-subnet"
    create_brand           = false
    create_oauth_client    = false
    oauth_client_id        = "test-client-id.apps.googleusercontent.com"
    oauth_client_secret    = "test-client-secret"
    iap_access_members = [
      "user:test@example.com",
      "group:test-group@example.com"
    ]
  }

  assert {
    condition     = google_compute_backend_service.default.name == "test-service-backend"
    error_message = "Backend service name should follow naming pattern"
  }

  assert {
    condition     = google_compute_backend_service.default.load_balancing_scheme == "INTERNAL_MANAGED"
    error_message = "Backend service should use internal load balancing"
  }

  assert {
    condition     = google_compute_backend_service.default.iap[0].enabled == true
    error_message = "IAP should be enabled on backend service"
  }

  assert {
    condition     = google_compute_backend_service.default.iap[0].oauth2_client_id == "test-client-id.apps.googleusercontent.com"
    error_message = "OAuth client ID should be set correctly"
  }

  assert {
    condition     = length([for b in google_iap_brand.project_brand : b]) == 0
    error_message = "IAP brand should not be created when create_brand is false (future-proof)"
  }

  assert {
    condition     = length([for c in google_iap_client.iap_client : c]) == 0
    error_message = "IAP client should not be created when create_oauth_client is false (future-proof)"
  }
}

run "test_network_endpoint_group" {
  command = plan

  variables {
    project_id             = "test-project"
    region                 = "us-central1"
    service_name           = "test-service-neg"
    cloud_run_service_name = "test-cloud-run-service"
    network                = "projects/test-project/global/networks/test-vpc"
    subnetwork             = "projects/test-project/regions/us-central1/subnetworks/test-subnet"
    oauth_client_id        = "test-client-id.apps.googleusercontent.com"
    oauth_client_secret    = "test-client-secret"
    iap_access_members     = []
  }

  assert {
    condition     = google_compute_region_network_endpoint_group.cloud_run_neg.network_endpoint_type == "SERVERLESS"
    error_message = "NEG should be configured for serverless Cloud Run"
  }

  assert {
    condition     = google_compute_region_network_endpoint_group.cloud_run_neg.cloud_run[0].service == "test-cloud-run-service"
    error_message = "NEG should point to correct Cloud Run service"
  }
}

run "test_load_balancer_configuration" {
  command = plan

  variables {
    project_id             = "test-project"
    region                 = "us-central1"
    service_name           = "test-lb"
    cloud_run_service_name = "test-cloud-run-service"
    network                = "projects/test-project/global/networks/test-vpc"
    subnetwork             = "projects/test-project/regions/us-central1/subnetworks/test-subnet"
    oauth_client_id        = "test-client-id.apps.googleusercontent.com"
    oauth_client_secret    = "test-client-secret"
    iap_access_members     = []
  }

  assert {
    condition     = google_compute_forwarding_rule.http.load_balancing_scheme == "INTERNAL_MANAGED"
    error_message = "HTTP forwarding rule should use internal load balancing"
  }

  assert {
    condition     = google_compute_forwarding_rule.http.port_range == "80"
    error_message = "HTTP forwarding rule should listen on port 80"
  }
}

run "test_iap_access_members" {
  command = plan

  variables {
    project_id             = "test-project"
    region                 = "us-central1"
    service_name           = "test-service-access"
    cloud_run_service_name = "test-cloud-run-service"
    network                = "projects/test-project/global/networks/test-vpc"
    subnetwork             = "projects/test-project/regions/us-central1/subnetworks/test-subnet"
    oauth_client_id        = "test-client-id.apps.googleusercontent.com"
    oauth_client_secret    = "test-client-secret"
    iap_access_members = [
      "user:alice@example.com",
      "user:bob@example.com",
      "group:admins@example.com"
    ]
  }

  assert {
    condition     = length(google_iap_web_backend_service_iam_binding.iap_access.members) == 3
    error_message = "IAP access should include all specified members"
  }

  assert {
    condition     = google_iap_web_backend_service_iam_binding.iap_access.role == "roles/iap.httpsResourceAccessor"
    error_message = "IAP access should grant httpsResourceAccessor role"
  }
}

run "test_health_check" {
  command = plan

  variables {
    project_id             = "test-project"
    region                 = "us-central1"
    service_name           = "test-service-health"
    cloud_run_service_name = "test-cloud-run-service"
    network                = "projects/test-project/global/networks/test-vpc"
    subnetwork             = "projects/test-project/regions/us-central1/subnetworks/test-subnet"
    oauth_client_id        = "test-client-id.apps.googleusercontent.com"
    oauth_client_secret    = "test-client-secret"
    iap_access_members     = []
    health_check_path      = "/healthz"
  }

  assert {
    condition     = google_compute_region_health_check.default.http_health_check[0].request_path == "/healthz"
    error_message = "Health check should use custom path"
  }

  assert {
    condition     = google_compute_region_health_check.default.timeout_sec == 5
    error_message = "Health check timeout should be 5 seconds"
  }
}
