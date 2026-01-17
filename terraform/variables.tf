variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "cloud-etl-project"

}
variable "project_prefix" {
  description = "Prefix for project resources"
  type        = string
  default     = "cloud-etl"
}


variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}
######### INGESTION VARIABLES #########
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

############## DATA VALIDATION VARIABLES ##############
variable "aws_catalog_description" {
  description = "Description of the AWS Glue Data Catalog"
  type        = string
  default     = "Data Catalog for Cloud ETL Project"
}

variable "lambda_package" {
  description = "Lambda package name"
  type        = string
  default     = "validation-lambda-package.zip"
}

variable "handler" {
  description = "lambda handler"
  type = string
  default = "lambda_function.lambda_handler"
}

variable "runtime" {
  description = "lambda function runtime"
  type = string
  default = "python3.10"
}

variable "timeout" {
  description = "timeout of the lambda function"
  type = string
  default = "30"
}

variable "memory_size" {
  description = "the memory size of the lambda function"
  type = string
  default = "256"
}

variable "glue_job_name" {
  description = "the name of the aws glue jobs"
  type = list(string)
  default = ["etl-job-1", "etl-job-2"]
}

variable "training_image" {
  description = "the ETL machine training image"
  type = string
  default = "382416733822.dkr.ecr.us-east-1.amazonaws.com/sklearn-training:1.2-1-cpu-py3"
}