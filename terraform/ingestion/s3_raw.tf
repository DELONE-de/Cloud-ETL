locals {
  raw_prefix = "raw/"
  bucket_name = "${var.project_prefix}-${var.environment}-raw-bucket-${replace(data.aws_caller_identity.current.account_id, "/","")}"
}

resource "aws_s3_bucket" "raw" {
  bucket = local.bucket_name
  acl    = var.s3_bucket_acl

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.ingest.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }

  lifecycle_rule {
    id      = "move-to-ia"
    enabled = true

    transition {
      days          = var.s3_lifecycle_transition_days
      storage_class = "GLACIER"
    }
  }

  force_destroy = false

  tags = {
    Project     = var.project_prefix
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "raw" {
  bucket                  = aws_s3_bucket.raw.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket policy: allow only Firehose PutObject (policy will be limited to Firehose role once we have the role)
# We'll assemble the policy using a template after Firehose IAM role exists (use data source interpolation below)