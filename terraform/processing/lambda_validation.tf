###############################
#  LAMBDA FUNCTION
###############################
resource "aws_lambda_function" "data_processing" {
  function_name = "${var.project_prefix}-validation-transformation"

  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.10"
  timeout       = 30
  memory_size   = 256

  filename         = var.lambda_package
  source_code_hash = filebase64sha256(var.lambda_package)

  environment {
    variables = {
      PROCESSED_S3_BUCKET = var.processed_bucket
      SECRET_ARN          = var.secret_arn
    }
  }
}

###############################
#  S3 TRIGGER FOR RAW ZONE
###############################
resource "aws_s3_bucket_notification" "raw_trigger" {
  bucket = var.raw_bucket

  lambda_function {
    lambda_function_arn = aws_lambda_function.data_processing.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "raw/"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

