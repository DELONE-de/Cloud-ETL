variable "project_prefix" {
  description = "Prefix for project resources"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "lambda_package" {
  type = string
}

variable "processed_bucket" {
  type = string
}

variable "raw_bucket" {
  type = string
}

variable "raw_bucket_arn" {
  type = string
}

variable "catalog_db_name" {
  type = string
}

variable "Environment" {
  type = string
}

variable "project" {
  type = string
}

variable "catalog_table_name" {
  type = string
}

variable "glue_crawler_name" {
  type = string
}

variable "aws_catalog_description" {
  type = string
}

variable "glue_crawler_role_arn" {
  type = string
}

variable "lambda_role_arn" {
  type = string
}

variable "handler" {
  type = string
}

variable "runtime" {
  type = string
}

variable "timeout" {
  type = string
}

variable "memory_size" {
  type = string
}

