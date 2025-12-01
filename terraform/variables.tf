variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev/prod)"
  type        = string
  default     = "dev"
}

variable "project_prefix" {
  description = "Project prefix for resource names"
  type        = string
  default     = "etl"
}

variable "kinesis_shard_count" {
  description = "Number of shards for Kinesis data stream"
  type        = number
  default     = 1
}

variable "kinesis_retention_hours" {
  description = "Kinesis data retention in hours (24..168)"
  type        = number
  default     = 24
}

variable "firehose_buffer_size_mb" {
  description = "Firehose buffer size (MB)"
  type        = number
  default     = 5
}

variable "firehose_buffer_interval_seconds" {
  description = "Firehose buffer interval (seconds)"
  type        = number
  default     = 60
}

variable "s3_lifecycle_transition_days" {
  description = "Days before moving raw objects to Glacier/Deep Archive"
  type        = number
  default     = 90
}

variable "s3_bucket_acl" {
  description = "S3 bucket ACL"
  type        = string
  default     = "private"
}