output "backend_service_id" {
  description = "ID of the backend service"
  value       = google_compute_backend_service.default.id
}

output "backend_service_name" {
  description = "Name of the backend service"
  value       = google_compute_backend_service.default.name
}

output "load_balancer_ip" {
  description = "IP address of the load balancer"
  value       = google_compute_forwarding_rule.http.ip_address
}

output "oauth_client_id" {
  description = "OAuth client ID for IAP"
  value       = var.create_oauth_client ? google_iap_client.iap_client[0].client_id : var.oauth_client_id
  sensitive   = true
}

output "oauth_client_secret" {
  description = "OAuth client secret for IAP"
  value       = var.create_oauth_client ? google_iap_client.iap_client[0].secret : var.oauth_client_secret
  sensitive   = true
}

output "brand_name" {
  description = "IAP brand name"
  value       = var.create_brand ? google_iap_brand.project_brand[0].name : var.brand_name
}
