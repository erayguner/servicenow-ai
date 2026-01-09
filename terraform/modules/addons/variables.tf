variable "security_policy_name" {
  type = string
}
variable "create_example_ingress" {
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
