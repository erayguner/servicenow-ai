variable "project_id" { type = string }
variable "region" { type = string }
variable "instance_name" { type = string }
variable "database_version" {
  type    = string
  default = "POSTGRES_16"
}
variable "tier" {
  type    = string
  default = "db-custom-4-16384"
} # 4 vCPU, 16GB
variable "disk_size" {
  type    = number
  default = 100
}
variable "disk_autoresize" {
  type    = bool
  default = true
}
variable "availability_type" {
  type    = string
  default = "REGIONAL"
}
variable "deletion_protection" {
  type    = bool
  default = false
}
variable "kms_key" { type = string }
variable "databases" {
  type    = list(string)
  default = []
}
variable "users" {
  description = "List of DB users to create (passwords to be rotated via Secret Manager, not TF)."
  type        = list(object({ name = string, password = optional(string) }))
  default     = []
}
variable "private_network" {
  description = "VPC network self-link for private IP connectivity"
  type        = string
  default     = null
}
