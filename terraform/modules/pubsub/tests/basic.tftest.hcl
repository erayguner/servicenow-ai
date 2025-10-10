mock_provider "google" {}

run "plan_pubsub" {
  command = plan
  variables {
    project_id = "test-project"
    topics = [
      { name = "topic-a" },
      { name = "topic-b" }
    ]
  }

  assert {
    condition     = length(resource.google_pubsub_topic.topics) == 2
    error_message = "Expected 2 topics"
  }
}
