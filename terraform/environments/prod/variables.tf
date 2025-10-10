variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "europe-west2"
}

variable "gke_master_cidr" {
  type    = string
  default = "172.16.0.0/28"
}

variable "billing_account" {
  type = string
}

variable "enable_example_ingress" {
  type    = bool
  default = false
}

variable "ingress_host" {
  type    = string
  default = ""
}

variable "cluster_issuer" {
  type    = string
  default = "letsencrypt"
}
