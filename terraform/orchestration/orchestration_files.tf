resource "aws_s3_object" "training_script" {
  bucket = var.s3_bucket_name
  key    = "scripts/train.py"
  source = "path/to/your/train.py"
  etag   = filemd5("path/to/your/train.py")
}
