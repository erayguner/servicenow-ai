variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-2"
}

variable "eks_public_access_cidrs" {
  description = "CIDR blocks that can access EKS public endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "db_master_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
}

variable "redis_auth_token" {
  description = "Redis authentication token"
  type        = string
  sensitive   = true
}

variable "budget_alert_emails" {
  description = "Email addresses for budget alerts"
  type        = list(string)
}
