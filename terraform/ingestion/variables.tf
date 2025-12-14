variable "project_prefix" {
  description = "Prefix for project resources"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "firehose_buffer_size_mb" {
  description = "Firehose buffer size in MB"
  type        = number
  default     = 5
}

variable "firehose_buffer_interval_seconds" {
  description = "Firehose buffer interval in seconds"
  type        = number
  default     = 300
}

variable "kinesis_shard_count" {
  description = "Number of shards for Kinesis stream"
  type        = number
  default     = 1
}

variable "kinesis_retention_hours" {
  description = "Kinesis stream retention period in hours"
  type        = number
  default     = 24
}

variable "s3_bucket_acl" {
  description = "S3 bucket ACL"
  type        = string
  default     = "private"
}

variable "s3_lifecycle_transition_days" {
  description = "Days after which objects transition to IA storage"
  type        = number
  default     = 30
}

