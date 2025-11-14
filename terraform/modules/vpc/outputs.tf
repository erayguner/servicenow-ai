output "network_self_link" {
  value = google_compute_network.vpc.self_link
}

output "subnet_self_links" {
  value = { for k, v in google_compute_subnetwork.subnets : k => v.self_link }
}

output "serverless_connector_id" {
  description = "ID of the Serverless VPC Access Connector"
  value       = var.enable_serverless_connector ? google_vpc_access_connector.connector[0].id : null
}

output "serverless_connector_name" {
  description = "Name of the Serverless VPC Access Connector"
  value       = var.enable_serverless_connector ? google_vpc_access_connector.connector[0].name : null
}
