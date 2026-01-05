variable "lambda_name" {
  type        = string
}

variable "sagemaker_endpoint_name" {
    type        = string
}

variable "project_prefix" {
  type = string
}

variable "target_bucket_name" {
  type = string
}

variable "s3_key_prefix" {
  type        = string
}

variable "s3_bucket_name" {
  type = string
}

variable "source_prefix" {
  type = string
}

variable "destination_prefix" {
  type = string
}

variable "model_name" {
  type = string
}

variable "sklearn_image_uri" {
  type = string
}

variable "model_data_s3_uri" {
  type = string
}

variable "source_dir_s3_uri" {
  type = string
}

variable "tags" {
  type = string
}

variable "sagemaker_execution_role" {
  type = string
}


variable "api_gateway_lambda_role" {
  type = string
}