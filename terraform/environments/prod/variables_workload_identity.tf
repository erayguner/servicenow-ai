# Variables for Workload Identity Federation

variable "github_org" {
  type        = string
  description = "GitHub organization name (e.g., 'mycompany')"
  default     = ""
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name (e.g., 'servicenow-ai')"
  default     = ""
}
