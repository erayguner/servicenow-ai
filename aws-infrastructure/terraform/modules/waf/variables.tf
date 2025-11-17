variable "name" {
  type = string
}

variable "scope" {
  description = "REGIONAL for ALB/API Gateway, CLOUDFRONT for CloudFront"
  type        = string
  default     = "REGIONAL"
}

variable "rate_limit" {
  description = "Rate limit per 5 minutes per IP"
  type        = number
  default     = 2000
}

variable "tags" {
  type    = map(string)
  default = {}
}
