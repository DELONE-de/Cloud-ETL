resource "aws_kinesis_stream" "ingest_stream" {
  name             = "${var.project_prefix}-${var.environment}-stream"
  shard_count      = var.kinesis_shard_count
  retention_period = var.kinesis_retention_hours
  shard_level_metrics = [] # enable if you want metrics
  encryption_type  = "KMS"
  kms_key_id       = aws_kms_key.ingest.arn

  tags = {
    Project     = var.project_prefix
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}