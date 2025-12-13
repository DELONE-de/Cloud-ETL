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

variable "region" {
  description = "The AWS region for the SageMaker training job."
  type        = string
  default     = "us-east-1" # <--- UPDATE THIS
  
}

variable "project" {
  description = "name of the project"
  type        = string
  default     = "mlops-project"
}

variable "enviroment" {
  description = "Deployment enviroment(dev,staging,production)"
  type = string
  default = "dev"
}

variable "s3_bucket_name" {
  description = "The s3 bucket for glue ouput and sagemaker data"
  type = string
  default = "etl_bucket"
}

variable "sagemaker_exec_role_arn" {
  description = "the ARN of the IAM role dedicated to sagemaker execution"
  type = string
  default = "arn:aws:"
}

variable "glue_job_name" {
  description = "The name of the AWS Glue ETL job to be triggered."
  type        = list(string)
  default     = ["etl-glue-job","data quality check"] # <--- UPDATE THIS
  
}

variable "allow_sagemaker_traning_prefix" {
  description = "Prefix for allowing sagemaker training"
  type        = list(string)
  default     = ["sfn-","etl-","training-","batch-"]
}

variable "glue_job_names" {
  
}

variable "project_name" {
  
}

variable "environment" {
  
}