variable "topics" {
  description = "List of SNS topics and SQS queues"
  type = list(object({
    name                      = string
    message_retention_seconds = optional(number, 604800)
    fifo                      = optional(bool, false)
  }))
}

variable "kms_key_arn" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
