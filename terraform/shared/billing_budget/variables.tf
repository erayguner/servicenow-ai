variable "billing_account" {
  type = string
}

variable "project_id" {
  type = string
}

variable "amount_monthly" {
  type = number
}

variable "thresholds" {
  type    = list(number)
  default = [0.5, 0.8, 1.0]
}
