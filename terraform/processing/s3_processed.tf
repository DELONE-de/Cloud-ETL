resource "aws_s3_bucket" "processed" {
  bucket = "${var.project_prefix}-processed-zone"
  force_destroy = true
}