variable "environment" {
  description = "Environment name"
  type        = string
}

variable "buckets" {
  description = "List of S3 buckets to create"
  type = list(object({
    name                       = string
    kms_key_arn                = string
    versioning_enabled         = optional(bool, true)
    enable_intelligent_tiering = optional(bool, false)
    enable_eventbridge         = optional(bool, false)
    lifecycle_rules = optional(list(object({
      id              = string
      expiration_days = optional(number)
      transitions = optional(list(object({
        days          = number
        storage_class = string
      })))
    })), [])
  }))
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
