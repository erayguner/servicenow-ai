variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "service_name" {
  description = "Name of the service (used for resource naming)"
  type        = string
}

variable "cloud_run_service_name" {
  description = "Name of the Cloud Run service to protect with IAP"
  type        = string
}

variable "network" {
  description = "VPC network self-link"
  type        = string
}

variable "subnetwork" {
  description = "VPC subnetwork self-link"
  type        = string
}

variable "create_brand" {
  description = "Whether to create a new IAP brand (OAuth consent screen)"
  type        = bool
  default     = false
}

variable "support_email" {
  description = "Support email for IAP brand"
  type        = string
  default     = ""
}

variable "application_title" {
  description = "Application title for IAP brand"
  type        = string
  default     = "AI Research Assistant"
}

variable "create_oauth_client" {
  description = "Whether to create a new OAuth client"
  type        = bool
  default     = false
}

variable "oauth_client_display_name" {
  description = "Display name for OAuth client"
  type        = string
  default     = "AI Research Assistant Client"
}

variable "brand_name" {
  description = "Existing IAP brand name (if not creating new)"
  type        = string
  default     = ""
}

variable "oauth_client_id" {
  description = "Existing OAuth client ID (if not creating new)"
  type        = string
  default     = ""
}

variable "oauth_client_secret" {
  description = "Existing OAuth client secret (if not creating new)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "iap_access_members" {
  description = "List of members who can access the service through IAP (e.g., 'user:email@example.com', 'group:group@example.com')"
  type        = list(string)
  default     = []
}

variable "ssl_certificate" {
  description = "SSL certificate for HTTPS (optional)"
  type        = string
  default     = null
}

variable "health_check_path" {
  description = "Health check path"
  type        = string
  default     = "/health"
}
