mock_provider "google" {}

run "test_cloud_run_service_creation" {
  command = plan

  variables {
    project_id             = "test-project"
    region                 = "europe-west2"
    service_name           = "test-service"
    image                  = "gcr.io/test-project/test-image:latest"
    vpc_connector          = "projects/test-project/locations/europe-west2/connectors/test-connector"
    service_account_email  = "test-sa@test-project.iam.gserviceaccount.com"
    create_service_account = false
    environment_variables = {
      "NODE_ENV" = "production"
    }
  }

  assert {
    condition     = google_cloud_run_v2_service.service.name == "test-service"
    error_message = "Cloud Run service name should be 'test-service'"
  }

  assert {
    condition     = google_cloud_run_v2_service.service.ingress == "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
    error_message = "Cloud Run service should have internal ingress only"
  }

  assert {
    condition     = google_cloud_run_v2_service.service.template[0].vpc_access[0].egress == "PRIVATE_RANGES_ONLY"
    error_message = "Cloud Run should only egress to private ranges"
  }
}

run "test_iap_enabled" {
  command = plan

  variables {
    project_id             = "test-project"
    region                 = "europe-west2"
    service_name           = "test-service-iap"
    image                  = "gcr.io/test-project/test-image:latest"
    vpc_connector          = "projects/test-project/locations/europe-west2/connectors/test-connector"
    service_account_email  = "test-sa@test-project.iam.gserviceaccount.com"
    create_service_account = false
    enable_iap             = true
  }

  assert {
    condition     = length([for m in google_cloud_run_service_iam_member.iap_invoker : m]) == 1
    error_message = "IAP invoker should be configured when enable_iap is true"
  }
}

run "test_service_account_creation" {
  command = plan

  variables {
    project_id             = "test-project"
    region                 = "europe-west2"
    service_name           = "test-service-sa"
    image                  = "gcr.io/test-project/test-image:latest"
    vpc_connector          = "projects/test-project/locations/europe-west2/connectors/test-connector"
    create_service_account = true
  }

  assert {
    condition     = length([for sa in google_service_account.cloud_run_sa : sa]) == 1
    error_message = "Service account should be created when create_service_account is true"
  }

  assert {
    condition     = google_service_account.cloud_run_sa[0].account_id == "test-service-sa-sa"
    error_message = "Service account ID should follow naming pattern"
  }
}

run "test_secret_environment_variables" {
  command = plan

  variables {
    project_id             = "test-project"
    region                 = "europe-west2"
    service_name           = "test-service-secrets"
    image                  = "gcr.io/test-project/test-image:latest"
    vpc_connector          = "projects/test-project/locations/europe-west2/connectors/test-connector"
    service_account_email  = "test-sa@test-project.iam.gserviceaccount.com"
    create_service_account = false
    secret_environment_variables = {
      "API_KEY" = {
        secret  = "my-api-key"
        version = "latest"
      }
    }
  }

  assert {
    condition     = length([for env in google_cloud_run_v2_service.service.template[0].containers[0].env : env if env.value_source != null]) > 0
    error_message = "Secret environment variables should be configured"
  }
}

run "test_resource_limits" {
  command = plan

  variables {
    project_id             = "test-project"
    region                 = "europe-west2"
    service_name           = "test-service-limits"
    image                  = "gcr.io/test-project/test-image:latest"
    vpc_connector          = "projects/test-project/locations/europe-west2/connectors/test-connector"
    service_account_email  = "test-sa@test-project.iam.gserviceaccount.com"
    create_service_account = false
    cpu_limit              = "2"
    memory_limit           = "1Gi"
  }

  assert {
    condition     = google_cloud_run_v2_service.service.template[0].containers[0].resources[0].limits["cpu"] == "2"
    error_message = "CPU limit should be set correctly"
  }

  assert {
    condition     = google_cloud_run_v2_service.service.template[0].containers[0].resources[0].limits["memory"] == "1Gi"
    error_message = "Memory limit should be set correctly"
  }
}
