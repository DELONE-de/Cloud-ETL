variable "project_prefix" {
  type = string
}

variable "environment" {
  type = string
}

variable "producer_service" {
  type        = string
  description = "Service that assumes producer role (ec2.amazonaws.com, lambda.amazonaws.com)"
  default     = "ec2.amazonaws.com"
}

variable "kinesis_stream_arn" {
  type = string
}

variable "s3_bucket_arn" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "cloudwatch_log_arn" {
  type = string
}