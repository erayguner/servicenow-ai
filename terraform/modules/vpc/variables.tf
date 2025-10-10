variable "project_id" { type = string }
variable "region" { type = string }
variable "network_name" { type = string }
variable "subnets" {
  description = "List of subnets with names, CIDRs, and secondary ranges for GKE pods/services."
  type = list(object({
    name                    = string
    ip_cidr_range           = string
    region                  = string
    private_google_access   = bool
    flow_logs               = optional(bool, true)
    secondary_ip_range_pods = string
    secondary_ip_range_svc  = string
  }))
}
variable "nat_enabled" {
  type    = bool
  default = true
}
variable "router_name" {
  type    = string
  default = "core-router"
}
variable "nat_name" {
  type    = string
  default = "core-nat"
}
variable "nat_ip_count" {
  type    = number
  default = 0
}
variable "create_fw_default_deny" {
  type    = bool
  default = true
}
