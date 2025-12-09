variable "step_function_arn" {
  description = "The ARN of the AWS Step Function State Machine to be triggered."
  type        = string
}

variable "schedule_name" {
  description = "The name for the EventBridge Scheduler schedule."
  type        = string
  default     = "weekly-etl-training-pipeline"
}

variable "aws_region" {
  description = "The AWS region where resources are deployed."
  type        = string
  default     = "us-east-1" # <--- UPDATE THIS
}

variable "s3_bucket_name" {
  description = "The S3 bucket for Glue output and SageMaker data."
  type        = string
  default     = "your-etl-data-bucket" # <--- UPDATE THIS
}

variable "sagemaker_exec_role_arn" {
  description = "The ARN of the IAM role dedicated to SageMaker execution."
  type        = string
  default     = "arn:aws:iam::123456789012:role/sagemaker-execution-role" # <--- UPDATE THIS
}