variable "project_prefix" {
  description = "Prefix for project resources"
  type        = string
}

variable "lambda_error_threshold" {
  description = "Lambda error threshold for alarms"
  type        = number
  default     = 5
}

variable "validation_lambda_name" {
  description = "Name of the validation Lambda function"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "enable_monitoring" {
  description = "Enable monitoring resources"
  type        = bool
  default     = true
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "sagemaker_endpoint_name" {
  description = "Name of the SageMaker endpoint"
  type        = string
  default     = "default-endpoint"
}