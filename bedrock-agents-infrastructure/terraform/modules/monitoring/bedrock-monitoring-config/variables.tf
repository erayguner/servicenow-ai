variable "project_name" {
  description = "Name of the project for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "enable_config" {
  description = "Enable AWS Config"
  type        = bool
  default     = true
}

variable "enable_recorder" {
  description = "Enable Config recorder"
  type        = bool
  default     = true
}

variable "recording_frequency" {
  description = "Recording frequency (CONTINUOUS or DAILY)"
  type        = string
  default     = "CONTINUOUS"

  validation {
    condition     = contains(["CONTINUOUS", "DAILY"], var.recording_frequency)
    error_message = "Recording frequency must be CONTINUOUS or DAILY"
  }
}

variable "include_global_resource_types" {
  description = "Include global resources (IAM, etc.)"
  type        = bool
  default     = true
}

variable "s3_bucket_name" {
  description = "S3 bucket name for Config snapshots and history"
  type        = string
  default     = null
}

variable "create_s3_bucket" {
  description = "Create S3 bucket for Config"
  type        = bool
  default     = true
}

variable "s3_key_prefix" {
  description = "S3 key prefix for Config files"
  type        = string
  default     = "config"
}

variable "delivery_frequency" {
  description = "Delivery frequency for config snapshots"
  type        = string
  default     = "TwentyFour_Hours"

  validation {
    condition = contains([
      "One_Hour",
      "Three_Hours",
      "Six_Hours",
      "Twelve_Hours",
      "TwentyFour_Hours"
    ], var.delivery_frequency)
    error_message = "Invalid delivery frequency"
  }
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for Config notifications"
  type        = string
  default     = null
}

variable "enable_compliance_rules" {
  description = "Enable compliance rules"
  type        = bool
  default     = true
}

variable "enable_remediation" {
  description = "Enable automatic remediation"
  type        = bool
  default     = false
}

variable "resource_types" {
  description = "List of AWS resource types to record"
  type        = list(string)
  default = [
    "AWS::Bedrock::Agent",
    "AWS::Bedrock::KnowledgeBase",
    "AWS::Lambda::Function",
    "AWS::StepFunctions::StateMachine",
    "AWS::ApiGateway::RestApi",
    "AWS::ApiGatewayV2::Api",
    "AWS::S3::Bucket",
    "AWS::KMS::Key",
    "AWS::IAM::Role",
    "AWS::IAM::Policy",
    "AWS::EC2::SecurityGroup",
    "AWS::Logs::LogGroup"
  ]
}

variable "kms_key_id" {
  description = "KMS key ID for encrypting Config data"
  type        = string
  default     = null
}

variable "enable_aggregator" {
  description = "Enable Config aggregator for multi-region/account"
  type        = bool
  default     = false
}

variable "aggregator_account_ids" {
  description = "List of account IDs to aggregate"
  type        = list(string)
  default     = []
}

variable "aggregator_regions" {
  description = "List of regions to aggregate"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
