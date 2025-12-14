variable "model_name" {
  description = "Name of the SageMaker model"
  type        = string
  default     = "ml-model"
}

variable "endpoint_config_name" {
  description = "Name of the SageMaker endpoint configuration"
  type        = string
  default     = "ml-endpoint-config"
}

variable "endpoint_name" {
  description = "Name of the SageMaker endpoint"
  type        = string
  default     = "ml-endpoint"
}

variable "container_image" {
  description = "Docker image for the model container"
  type        = string
  default     = "763104351884.dkr.ecr.us-east-1.amazonaws.com/sklearn-inference:0.23-1-cpu-py3"
}

variable "model_data_url" {
  description = "S3 URL for the model artifacts"
  type        = string
  default     = "s3://your-bucket/model.tar.gz"
}

variable "instance_type" {
  description = "Instance type for the endpoint"
  type        = string
  default     = "ml.t2.medium"
}

variable "initial_instance_count" {
  description = "Initial number of instances for the endpoint"
  type        = number
  default     = 1
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

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "cloud-etl"
}