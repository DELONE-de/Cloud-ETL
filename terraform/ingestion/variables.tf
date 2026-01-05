variable "project_prefix" {
  type = string
}

variable "account_id" {
  type = string
}
variable "project_name" {
  type = string

}
variable "environment" {
  type = string
}

variable "kinesis_shard_count" {
  type = number
}
variable "kinesis_retention_hours" {
  type = number
}
variable "firehose_buffer_interval_seconds" {
  type = number
}
variable "firehose_buffer_size_mb" {
  type = number
}
variable "s3_bucket_acl" {
  type = string
}
variable "s3_lifecycle_transition_days" {
  type = number
}

variable "log_group_name" {
  type = string
}

variable "log_stream_name" {
  type = string
}

variable "firehose_role_arn" {
  type = string
}

variable "firehose_attach" {

}

variable "firehose_s3_attach" {

}

variable "firehose_kinesis_attach" {

}

variable "firehose_logs_attach" {

}