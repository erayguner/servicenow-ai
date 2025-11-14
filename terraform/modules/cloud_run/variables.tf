variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "service_name" {
  description = "Name of the Cloud Run service"
  type        = string
}

variable "image" {
  description = "Container image URL"
  type        = string
}

variable "vpc_connector" {
  description = "VPC Access Connector for Cloud Run"
  type        = string
}

variable "service_account_email" {
  description = "Service account email for Cloud Run service"
  type        = string
  default     = ""
}

variable "create_service_account" {
  description = "Whether to create a service account for Cloud Run"
  type        = bool
  default     = true
}

variable "environment_variables" {
  description = "Environment variables for the container"
  type        = map(string)
  default     = {}
}

variable "secret_environment_variables" {
  description = "Secret environment variables from Secret Manager"
  type = map(object({
    secret  = string
    version = string
  }))
  default = {}
}

variable "min_instances" {
  description = "Minimum number of instances"
  type        = number
  default     = 0
}

variable "max_instances" {
  description = "Maximum number of instances"
  type        = number
  default     = 10
}

variable "cpu_limit" {
  description = "CPU limit"
  type        = string
  default     = "1"
}

variable "memory_limit" {
  description = "Memory limit"
  type        = string
  default     = "512Mi"
}

variable "cpu_always_allocated" {
  description = "Whether CPU is always allocated"
  type        = bool
  default     = false
}

variable "container_port" {
  description = "Container port"
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "Health check path"
  type        = string
  default     = "/health"
}

variable "enable_iap" {
  description = "Enable Identity-Aware Proxy"
  type        = bool
  default     = true
}

variable "authenticated_member" {
  description = "Authenticated member for Cloud Run invoker (if not using IAP)"
  type        = string
  default     = "allUsers"
}

variable "enable_cloud_sql_access" {
  description = "Enable Cloud SQL access for service account"
  type        = bool
  default     = false
}

variable "enable_firestore_access" {
  description = "Enable Firestore access for service account"
  type        = bool
  default     = false
}

variable "storage_buckets" {
  description = "Storage buckets to grant access to"
  type        = set(string)
  default     = []
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}
