provider "google-beta" {}

resource "google_beta_vertex_ai_index" "kb_index" {
  project      = var.project_id
  region       = var.region
  display_name = var.display_name
  description  = "Knowledge Base Vector Index"
  metadata = jsonencode({
    contentsDeltaUri = null
    config = {
      dimensions          = var.dimensions
      algorithmConfig     = { treeAhConfig = {} }
      distanceMeasureType = var.distance_measure_type
    }
  })
}

resource "google_beta_vertex_ai_index_endpoint" "kb_endpoint" {
  project      = var.project_id
  region       = var.region
  display_name = "${var.display_name}-endpoint"
}

output "index_id" { value = google_beta_vertex_ai_index.kb_index.id }
output "endpoint_id" { value = google_beta_vertex_ai_index_endpoint.kb_endpoint.id }

