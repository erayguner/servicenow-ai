variable "name" {
  description = "Name of the ElastiCache cluster"
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "eks_node_security_group_id" {
  type = string
}

variable "engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.1"
}

variable "node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.r7g.large"
}

variable "num_cache_nodes" {
  description = "Number of cache nodes in the cluster"
  type        = number
  default     = 2
}

variable "auth_token" {
  type      = string
  sensitive = true
}

variable "kms_key_arn" {
  type = string
}

variable "snapshot_retention_limit" {
  description = "Number of days to retain snapshots"
  type        = number
  default     = 5
}

variable "snapshot_window" {
  description = "Daily time range for snapshots"
  type        = string
  default     = "03:00-05:00"
}

variable "maintenance_window" {
  description = "Weekly maintenance window"
  type        = string
  default     = "sun:05:00-sun:07:00"
}

variable "tags" {
  type    = map(string)
  default = {}
}
