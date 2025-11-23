variable "knowledge_base_name" {
  description = "Name of the knowledge base"
  type        = string
}

variable "description" {
  description = "Description of the knowledge base"
  type        = string
  default     = ""
}

variable "embedding_model_arn" {
  description = "ARN of the embedding model (Titan Embeddings V2)"
  type        = string
  default     = null
}

variable "embedding_model_id" {
  description = "ID of the embedding model"
  type        = string
  default     = "amazon.titan-embed-text-v2:0"
}

variable "vector_dimension" {
  description = "Dimension of the embedding vectors"
  type        = number
  default     = 1024

  validation {
    condition     = contains([256, 512, 1024], var.vector_dimension)
    error_message = "Vector dimension must be 256, 512, or 1024 for Titan Embeddings V2."
  }
}

variable "opensearch_collection_name" {
  description = "Name of the OpenSearch Serverless collection"
  type        = string
  default     = null
}

variable "opensearch_index_name" {
  description = "Name of the vector index in OpenSearch"
  type        = string
  default     = "bedrock-knowledge-base-index"
}

variable "vector_field_name" {
  description = "Name of the vector field in OpenSearch"
  type        = string
  default     = "bedrock-knowledge-base-default-vector"
}

variable "text_field_name" {
  description = "Name of the text field in OpenSearch"
  type        = string
  default     = "AMAZON_BEDROCK_TEXT_CHUNK"
}

variable "metadata_field_name" {
  description = "Name of the metadata field in OpenSearch"
  type        = string
  default     = "AMAZON_BEDROCK_METADATA"
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket for documents (will be created if not exists)"
  type        = string
  default     = null
}

variable "s3_bucket_prefix" {
  description = "Prefix for documents in S3 bucket"
  type        = string
  default     = "documents/"
}

variable "create_s3_bucket" {
  description = "Whether to create a new S3 bucket"
  type        = bool
  default     = true
}

variable "existing_s3_bucket_arn" {
  description = "ARN of existing S3 bucket (if create_s3_bucket is false)"
  type        = string
  default     = null
}

variable "enable_versioning" {
  description = "Enable versioning for S3 bucket"
  type        = bool
  default     = true
}

variable "enable_server_side_encryption" {
  description = "Enable server-side encryption for S3 bucket"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for S3 bucket encryption"
  type        = string
  default     = null
}

variable "chunking_strategy" {
  description = "Chunking strategy for documents (FIXED_SIZE, NONE, HIERARCHICAL, SEMANTIC)"
  type        = string
  default     = "FIXED_SIZE"

  validation {
    condition     = contains(["FIXED_SIZE", "NONE", "HIERARCHICAL", "SEMANTIC"], var.chunking_strategy)
    error_message = "Chunking strategy must be one of: FIXED_SIZE, NONE, HIERARCHICAL, SEMANTIC."
  }
}

variable "max_tokens" {
  description = "Maximum tokens per chunk (for FIXED_SIZE chunking)"
  type        = number
  default     = 300
}

variable "overlap_percentage" {
  description = "Overlap percentage between chunks (for FIXED_SIZE chunking)"
  type        = number
  default     = 20

  validation {
    condition     = var.overlap_percentage >= 0 && var.overlap_percentage <= 99
    error_message = "Overlap percentage must be between 0 and 99."
  }
}

variable "data_deletion_policy" {
  description = "Data deletion policy (RETAIN, DELETE)"
  type        = string
  default     = "RETAIN"

  validation {
    condition     = contains(["RETAIN", "DELETE"], var.data_deletion_policy)
    error_message = "Data deletion policy must be either RETAIN or DELETE."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "enable_vpc_configuration" {
  description = "Whether to enable VPC configuration for OpenSearch Serverless"
  type        = bool
  default     = false
}

variable "vpc_subnet_ids" {
  description = "List of VPC subnet IDs for OpenSearch Serverless"
  type        = list(string)
  default     = []
}

variable "standby_replicas" {
  description = "Standby replicas for OpenSearch Serverless collection"
  type        = string
  default     = "ENABLED"

  validation {
    condition     = contains(["ENABLED", "DISABLED"], var.standby_replicas)
    error_message = "Standby replicas must be either ENABLED or DISABLED."
  }
}
