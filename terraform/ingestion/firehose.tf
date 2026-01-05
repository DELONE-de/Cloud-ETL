resource "aws_kinesis_firehose_delivery_stream" "kinesis_to_s3" {
  name        = "${var.project_prefix}-${var.environment}-firehose"
  destination = "s3"

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.ingest_stream.arn
    role_arn           = var.firehose_role_arn
  }

  extended_s3_configuration {
    role_arn           = var.firehose_role_arn
    bucket_arn         = aws_s3_bucket.raw.arn
    prefix             = "raw/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
    buffering_size     = var.firehose_buffer_size_mb
    buffering_interval = var.firehose_buffer_interval_seconds

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = var.log_group_name
      log_stream_name = var.log_stream_name
    }
  }

  tags = {
    Project     = var.project_prefix
    Environment = var.environment
  }

  depends_on = [
    var.firehose_attach,
    var.firehose_s3_attach,
    var.firehose_kinesis_attach,
    var.firehose_logs_attach
  ]
}