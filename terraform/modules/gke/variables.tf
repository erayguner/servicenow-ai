variable "project_id" { type = string }
variable "region" { type = string }
variable "network" { type = string }
variable "subnetwork" { type = string }
variable "cluster_name" { type = string }
variable "release_channel" {
  type    = string
  default = "REGULAR"
}
variable "master_ipv4_cidr_block" {
  type    = string
  default = "172.16.0.0/28"
}
variable "authorized_master_cidrs" {
  description = "List of CIDRs permitted to access the GKE control plane"
  type        = list(object({ cidr_block = string, display_name = string }))
  default     = []
}
variable "general_pool_size" {
  type = object({ min = number, max = number })
}
variable "ai_pool_size" {
  type = object({ min = number, max = number })
}
variable "vector_pool_size" {
  type = object({ min = number, max = number })
}
variable "labels" {
  type    = map(string)
  default = {}
}
variable "tags" {
  type    = list(string)
  default = []
}
variable "subnetwork_name" {
  description = "Subnetwork name (used to reference secondary IP ranges)"
  type        = string
}
variable "google_domain" {
  description = "Google Workspace domain for GKE RBAC groups"
  type        = string
  default     = "example.com"
}
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "enable_spot_instances" {
  description = "Enable spot (preemptible) instances for cost optimization (dev/staging only)"
  type        = bool
  default     = false
}

variable "spot_instance_pools" {
  description = "List of node pool names to use spot instances (e.g., ['general', 'ai-inference'])"
  type        = list(string)
  default     = []
}
