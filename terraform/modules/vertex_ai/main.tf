resource "google_vertex_ai_index" "kb_index" {
  provider     = google-beta
  project      = var.project_id
  region       = var.region
  display_name = var.display_name
  description  = "Knowledge Base Vector Index"
  metadata {
    contents_delta_uri = "gs://${var.project_id}-vertex-ai/initial"
    config {
      dimensions                  = var.dimensions
      approximate_neighbors_count = 10
      distance_measure_type       = var.distance_measure_type
      algorithm_config {
        tree_ah_config {
          leaf_node_embedding_count = 1000
        }
      }
    }
  }
}

resource "google_vertex_ai_index_endpoint" "kb_endpoint" {
  provider     = google-beta
  project      = var.project_id
  region       = var.region
  display_name = "${var.display_name}-endpoint"
}

output "index_id" { value = google_vertex_ai_index.kb_index.id }
output "endpoint_id" { value = google_vertex_ai_index_endpoint.kb_endpoint.id }
