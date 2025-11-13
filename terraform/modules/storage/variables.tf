variable "project_id" { type = string }
variable "location" { type = string }
variable "buckets" {
  description = "List of bucket definitions."
  type = list(object({
    name           = string
    uniform_access = optional(bool, true)
    force_destroy  = optional(bool, false)
    kms_key        = string
    log_bucket     = optional(string)
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
