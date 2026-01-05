locals {
  raw_prefix = "raw/"
  bucket_name = "${var.project_prefix}-${var.environment}-raw-bucket-${replace(var.account_id, "/","")}"
}
resource "aws_s3_bucket" "raw" {
  bucket = local.bucket_name
  force_destroy = false

  tags = {
    Project     = var.project_prefix
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_s3_bucket_versioning" "raw" {
  bucket = aws_s3_bucket.raw.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_acl" "raw" {
  bucket = aws_s3_bucket.raw.id
  acl    = var.s3_bucket_acl
}

# Block public access
resource "aws_s3_bucket_public_access_block" "raw" {
  bucket                  = aws_s3_bucket.raw.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
