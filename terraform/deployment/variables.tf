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

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "sagemaker"
}

variable "sagemaker_role_arn" {
  description = "ARN of the SageMaker execution role"
  type        = string
}

variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
  default     = ""
}

variable "vpc_config" {
  description = "VPC configuration for SageMaker"
  type = object({
    security_group_ids = list(string)
    subnet_ids         = list(string)
  })
  default = null
}

variable "enable_network_isolation" {
  description = "Enable network isolation for the model"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "instance_count" {
  description = "Number of instances for the endpoint"
  type        = number
  default     = 1
}

variable "serverless_config" {
  description = "Serverless configuration"
  type = object({
    max_concurrency = number
    memory_size_mb  = number
  })
  default = null
}

variable "enable_data_capture" {
  description = "Enable data capture for the endpoint"
  type        = bool
  default     = false
}

variable "data_capture_s3_uri" {
  description = "S3 URI for data capture"
  type        = string
  default     = ""
}

variable "target_bucket_name" {
  type    = string
  default = "your-sagemaker-model-bucket" # <--- UPDATE THIS
}

variable "s3_key_prefix" {
  type    = string
  default = "sagemaker/my-app"
}


variable "region" {
  default = "us-east-1" # <--- Update to your preferred AWS region
}

variable "s3_bucket_name" {
  default = "your-sagemaker-model-bucket" # <--- Must match the bucket name in your Python script
}

variable "source_prefix" {
  default = "sagemaker/source_files"
}

variable "destination_prefix" {
  default = "sagemaker/model_artifacts"
}

variable "model_version" {
  description = "Version of the model"
  type        = string
  default     = "1.0"
}

variable "api_url" {
  description = "API URL for the model"
  type        = string
  default     = "https://api.example.com"
}