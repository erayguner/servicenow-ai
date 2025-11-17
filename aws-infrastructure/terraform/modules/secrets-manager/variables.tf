variable "kms_key_arn" {
  type = string
}

variable "secrets" {
  description = "List of secrets to create"
  type = list(object({
    name                    = string
    description             = optional(string, "")
    recovery_window_in_days = optional(number, 30)
    enable_rotation         = optional(bool, false)
    rotation_lambda_arn     = optional(string, "")
    rotation_days           = optional(number, 30)
  }))
}

variable "tags" {
  type    = map(string)
  default = {}
}
