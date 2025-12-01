resource "aws_kms_key" "ingest" {
  description             = "${var.project_prefix}-${var.environment} ingestion key"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Project     = var.project_prefix
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_kms_alias" "ingest_alias" {
  name          = "alias/${var.project_prefix}-${var.environment}-ingest"
  target_key_id = aws_kms_key.ingest.key_id
}