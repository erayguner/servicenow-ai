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

# Path to kubeconfig used by kubernetes and helm providers
variable "kubeconfig_path" {
  description = "Absolute path to the kubeconfig file for Kubernetes/Helm providers"
  type        = string
  default     = ""

  validation {
    condition     = var.kubeconfig_path == "" || can(regex("^/", var.kubeconfig_path))
    error_message = "kubeconfig_path must be an absolute path (starts with /) or empty to use in-cluster/default config."
  }
}
