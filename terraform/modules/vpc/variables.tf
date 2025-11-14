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

variable "enable_serverless_connector" {
  description = "Enable Serverless VPC Access Connector for Cloud Run"
  type        = bool
  default     = false
}

variable "serverless_connector_name" {
  description = "Name of the Serverless VPC Access Connector"
  type        = string
  default     = "cloud-run-connector"
}

variable "serverless_connector_cidr" {
  description = "CIDR range for Serverless VPC Access Connector (must be /28)"
  type        = string
  default     = "10.8.0.0/28"
}

variable "serverless_connector_min_instances" {
  description = "Minimum number of instances for Serverless VPC Access Connector"
  type        = number
  default     = 2
}

variable "serverless_connector_max_instances" {
  description = "Maximum number of instances for Serverless VPC Access Connector"
  type        = number
  default     = 3
}

variable "serverless_connector_machine_type" {
  description = "Machine type for Serverless VPC Access Connector"
  type        = string
  default     = "e2-micro"
}
