variable "environment" {
  description = "Environment name"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption"
  type        = string
}

variable "tables" {
  description = "List of DynamoDB tables to create"
  type = list(object({
    name                          = string
    billing_mode                  = optional(string, "PAY_PER_REQUEST")
    hash_key                      = string
    range_key                     = optional(string)
    read_capacity                 = optional(number, 5)
    write_capacity                = optional(number, 5)
    enable_autoscaling            = optional(bool, false)
    autoscaling_read_max          = optional(number, 100)
    autoscaling_write_max         = optional(number, 100)
    enable_point_in_time_recovery = optional(bool, true)
    enable_streams                = optional(bool, false)
    stream_view_type              = optional(string, "NEW_AND_OLD_IMAGES")
    ttl_attribute                 = optional(string)
    attributes = list(object({
      name = string
      type = string
    }))
    global_secondary_indexes = optional(list(object({
      name            = string
      hash_key        = string
      range_key       = optional(string)
      projection_type = string
      read_capacity   = optional(number, 5)
      write_capacity  = optional(number, 5)
    })))
  }))
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
