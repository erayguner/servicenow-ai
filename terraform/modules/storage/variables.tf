variable "project_id" { type = string }
variable "location" { type = string }
variable "buckets" {
  description = "List of bucket definitions. Note: uniform_bucket_level_access is always enforced for security."
  type = list(object({
    name          = string
    force_destroy = optional(bool, false)
    versioning    = optional(bool, true) # Versioning enabled by default for data protection
    kms_key       = string
    log_bucket    = optional(string)
    lifecycle_rules = optional(list(object({
      action = object({ type = string, storage_class = optional(string) })
      condition = object({
        age                   = optional(number)
        matches_storage_class = optional(list(string))
        num_newer_versions    = optional(number)
        with_state            = optional(string)
      })
    })), [])
  }))
}
