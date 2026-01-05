resource "aws_kinesis_stream" "ingest_stream" {
  name             = "${var.project_prefix}-${var.environment}-stream"
  shard_count      = var.kinesis_shard_count
  retention_period = var.kinesis_retention_hours
  shard_level_metrics = [GetRecords.Success, PutRecord.Success, GetRecords.Records,GetRecords.Latency]

  tags = {
    Project     = var.project_prefix
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}