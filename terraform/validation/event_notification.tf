resource "aws_s3_bucket_notification" "raw_to_validation" {
  bucket = aws_s3_bucket.raw.id

  lambda_function {
    lambda_function_arn = var.validation_lambda_arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [
    var.validation_lambda_permission
  ]
}