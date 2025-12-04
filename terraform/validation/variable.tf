variable "project_prefix" { type = string }

variable "lambda_package_bucket" { type = string }
variable "validation_lambda_key" { type = string }
variable "transformation_lambda_key" { type = string }

variable "raw_bucket_arn" { type = string }
variable "processed_bucket" { type = string }

variable "secret_arn" { type = string }

variable "lambda_secret_values" {
  type = map(string)
}

variable "alarm_sns_topic_arn" { type = string }

variable "lambda_error_threshold" {
  type    = number
  default = 1
}

variable "lambda_throttle_threshold" {
  type    = number
  default = 1
}