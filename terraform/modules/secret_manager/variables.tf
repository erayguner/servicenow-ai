variable "project_id" { type = string }
variable "secrets" {
  description = "Secrets to create; versions should be added manually or via CI."
  type = list(object({
    name        = string
    labels      = optional(map(string), {})
    replication = optional(object({ automatic = bool, locations = optional(list(string)) }), { automatic = true })
  }))
}
variable "accessors" {
  description = "IAM accessors for secrets (workload identity service accounts)."
  type        = map(list(string))
  default     = {}
}
