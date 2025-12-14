variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "step_function_arn" {
  description = "ARN of the Step Function"
  type        = string
}

variable "secret_arn" {
  description = "ARN of the secret"
  type        = string
}

variable "api_url" {
  description = "API URL"
  type        = string
}