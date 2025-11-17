variable "key_prefix" {
  description = "Prefix for KMS key names"
  type        = string
}

variable "keys" {
  description = "Map of key names to create"
  type        = map(string)
}

variable "deletion_window_in_days" {
  description = "KMS key deletion window"
  type        = number
  default     = 30
}

variable "enable_multi_region" {
  description = "Enable multi-region keys"
  type        = bool
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
