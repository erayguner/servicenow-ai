variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "europe-west2"
}

variable "gke_master_cidr" {
  type    = string
  default = "172.18.0.0/28"
}

variable "billing_account" {
  type = string
}
