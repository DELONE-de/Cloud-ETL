locals {
  bucket_name = "${var.project_prefix}-${var.environment}-processed-bucket-${var.account_id}"
}

resource "aws_s3_bucket" "processed" {
  bucket = local.bucket_name
  force_destroy = false

   tags = {
    Name        = var.project_prefix
    Environment = var.environment
  }
}