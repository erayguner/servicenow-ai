variable "project_id" { type = string }
variable "topics" {
  type = list(object({
    name                       = string
    message_retention_duration = optional(string, "604800s")
    kms_key                    = optional(string)
  }))
}
