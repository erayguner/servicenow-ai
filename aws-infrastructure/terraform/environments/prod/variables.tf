variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "eks_public_access_cidrs" {
  description = "CIDR blocks that can access EKS public endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "db_master_password" {
  description = "RDS master password (use AWS Secrets Manager in production)"
  type        = string
  sensitive   = true
}

variable "redis_auth_token" {
  description = "Redis authentication token"
  type        = string
  sensitive   = true
}

variable "create_rds_read_replica" {
  description = "Create RDS read replica"
  type        = bool
  default     = false
}

variable "rds_rotation_lambda_arn" {
  description = "Lambda ARN for RDS password rotation"
  type        = string
  default     = ""
}

variable "budget_alert_emails" {
  description = "Email addresses for budget alerts"
  type        = list(string)
}
