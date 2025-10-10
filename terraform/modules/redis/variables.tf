variable "project_id" { type = string }
variable "region" { type = string }
variable "name" { type = string }
variable "tier" {
  type    = string
  default = "STANDARD_HA"
}
variable "memory_size_gb" {
  type    = number
  default = 5
}
variable "redis_version" {
  type    = string
  default = "REDIS_6_X"
}
variable "authorized_network" { type = string }
