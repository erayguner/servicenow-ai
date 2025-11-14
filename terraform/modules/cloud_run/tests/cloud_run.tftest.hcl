run "test_cloud_run_service_creation" {
  command = plan

  variables {
    project_id            = "test-project"
    region                = "us-central1"
    service_name          = "test-service"
    image                 = "gcr.io/test-project/test-image:latest"
    vpc_connector         = "projects/test-project/locations/us-central1/connectors/test-connector"
    service_account_email = "test-sa@test-project.iam.gserviceaccount.com"
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
}

run "test_iap_enabled" {
  command = plan

  variables {
    project_id            = "test-project"
    region                = "us-central1"
    service_name          = "test-service-iap"
    image                 = "gcr.io/test-project/test-image:latest"
    vpc_connector         = "projects/test-project/locations/us-central1/connectors/test-connector"
    service_account_email = "test-sa@test-project.iam.gserviceaccount.com"
    create_service_account = false
    enable_iap            = true
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
    region                 = "us-central1"
    service_name           = "test-service-sa"
    image                  = "gcr.io/test-project/test-image:latest"
    vpc_connector          = "projects/test-project/locations/us-central1/connectors/test-connector"
    create_service_account = true
  }

  assert {
    condition     = length([for sa in google_service_account.cloud_run_sa : sa]) == 1
    error_message = "Service account should be created when create_service_account is true"
  }
}
