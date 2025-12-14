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

variable "api_url" {
  type = string
}

variable "raw_bucket_arn" {
  description = "ARN of the raw S3 bucket"
  type        = string
}

variable "processed_bucket_arn" {
  description = "ARN of the processed S3 bucket"
  type        = string
}

variable "secret_arn" {
  description = "ARN of the secrets manager secret"
  type        = string
}

variable "step_function_arn" {
  description = "ARN of the step function"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "glue_job_names" {
  description = "List of Glue job names"
  type        = list(string)
  default     = []
}

variable "allowed_sagemaker_training_prefixes" {
  description = "Allowed SageMaker training job prefixes"
  type        = list(string)
  default     = []
}

variable "sagemaker_exec_role_arn" {
  description = "ARN of the SageMaker execution role"
  type        = string
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

