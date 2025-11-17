variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where EKS cluster will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for EKS nodes"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for EKS load balancers"
  type        = list(string)
  default     = []
}

variable "kubernetes_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.29"
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "endpoint_private_access" {
  description = "Enable private API server endpoint"
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Enable public API server endpoint"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "List of CIDR blocks that can access the public API server endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enabled_cluster_log_types" {
  description = "List of control plane logging types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period for EKS control plane logs"
  type        = number
  default     = 30
}

variable "kms_deletion_window" {
  description = "KMS key deletion window in days"
  type        = number
  default     = 30
}

variable "general_node_group" {
  description = "Configuration for general purpose node group"
  type = object({
    instance_types = list(string)
    capacity_type  = string
    min_size       = number
    max_size       = number
    desired_size   = number
    labels         = map(string)
  })
  default = {
    instance_types = ["t3.large", "t3a.large"]
    capacity_type  = "ON_DEMAND"
    min_size       = 3
    max_size       = 20
    desired_size   = 3
    labels         = {}
  }
}

variable "enable_ai_node_group" {
  description = "Enable AI workload node group"
  type        = bool
  default     = true
}

variable "ai_node_group" {
  description = "Configuration for AI workload node group"
  type = object({
    instance_types = list(string)
    capacity_type  = string
    min_size       = number
    max_size       = number
    desired_size   = number
    labels         = map(string)
  })
  default = {
    instance_types = ["r6i.2xlarge", "r6a.2xlarge"]
    capacity_type  = "ON_DEMAND"
    min_size       = 2
    max_size       = 10
    desired_size   = 2
    labels         = {}
  }
}

variable "vpc_cni_version" {
  description = "VPC CNI add-on version"
  type        = string
  default     = null
}

variable "coredns_version" {
  description = "CoreDNS add-on version"
  type        = string
  default     = null
}

variable "kube_proxy_version" {
  description = "kube-proxy add-on version"
  type        = string
  default     = null
}

variable "pod_identity_version" {
  description = "EKS Pod Identity add-on version"
  type        = string
  default     = null
}

variable "ebs_csi_driver_version" {
  description = "EBS CSI driver add-on version"
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
