resource "aws_kinesis_firehose_delivery_stream" "kinesis_to_s3" {
  name        = "${var.project_prefix}-${var.environment}-firehose"
  destination = "s3"

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.ingest_stream.arn
    role_arn           = aws_iam_role.firehose_role.arn
  }

  s3_configuration {
    role_arn           = aws_iam_role.firehose_role.arn
    bucket_arn         = aws_s3_bucket.raw.arn
    prefix             = "raw/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
    compression_format = "GZIP"

    buffering_size     = var.firehose_buffer_size_mb
    buffering_interval = var.firehose_buffer_interval_seconds

    encryption_configuration {
      kms_key_arn = aws_kms_key.ingest.arn
    }

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = "/aws/kinesisfirehose/${var.project_prefix}-${var.environment}"
      log_stream_name = "S3Delivery"
    }
  }

  tags = {
    Project     = var.project_prefix
    Environment = var.environment
  }

  depends_on = [
    aws_iam_role_policy_attachment.firehose_attach
  ]
}