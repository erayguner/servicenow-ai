mock_provider "google" {}

run "plan_redis" {
  command = plan
  variables {
    project_id         = "test-project"
    region             = "europe-west2"
    name               = "test-redis"
    authorized_network = "/projects/test-project/global/networks/test"
    memory_size_gb     = 1
  }

  assert {
    condition     = resource.google_redis_instance.cache.name == "test-redis"
    error_message = "Redis instance name mismatch"
  }

  assert {
    condition     = resource.google_redis_instance.cache.transit_encryption_mode == "SERVER_AUTHENTICATION"
    error_message = "Redis must enable transit encryption"
  }
}
