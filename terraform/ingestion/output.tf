output "kinesis_stream_name" {
  description = "Kinesis stream name"
  value       = aws_kinesis_stream.ingest_stream.name
}

output "kinesis_stream_arn" {
  description = "Kinesis stream arn"
  value       = aws_kinesis_stream.ingest_stream.arn
}

output "firehose_name" {
  description = "Firehose delivery stream name"
  value       = aws_kinesis_firehose_delivery_stream.kinesis_to_s3.name
}

output "s3_raw_bucket" {
  description = "S3 raw bucket name"
  value       = aws_s3_bucket.raw.bucket
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.raw.arn
}