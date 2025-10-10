mock_provider "google-beta" {}

run "plan_vertex" {
  command = plan
  variables {
    project_id   = "test-project"
    region       = "europe-west4"
    display_name = "test-kb-index"
    dimensions   = 768
  }

  assert {
    condition     = resource.google_beta_vertex_ai_index.kb_index.display_name == "test-kb-index"
    error_message = "Vertex AI Index display name mismatch"
  }
}
