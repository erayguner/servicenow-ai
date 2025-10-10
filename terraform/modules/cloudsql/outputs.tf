output "instance_connection_name" {
  description = "The connection name for Cloud SQL Proxy"
  value       = google_sql_database_instance.pg.connection_name
}

output "instance_id" {
  description = "The server-assigned unique identifier for the database instance"
  value       = google_sql_database_instance.pg.id
}

output "instance_name" {
  description = "The name of the Cloud SQL instance"
  value       = google_sql_database_instance.pg.name
}

output "database_version" {
  description = "The database version running on the instance"
  value       = google_sql_database_instance.pg.database_version
}

output "private_ip_address" {
  description = "The private IP address assigned to the instance"
  value       = try(google_sql_database_instance.pg.private_ip_address, null)
}
