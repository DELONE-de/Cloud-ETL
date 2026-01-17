data "archive_file" "validation_zip" {
  type        = "zip"
  source_file = "${path.module}/../../scripts/data_validator.py"
  output_path = "${path.module}/../../scripts/data_validator.py.zip"
}


###############################
#  LAMBDA FUNCTION
###############################
resource "aws_lambda_function" "data_processing" {
  function_name = "${var.project_prefix}-validation-transformation"

  role          = var.lambda_role_arn
  handler       = var.handler#"lambda_function.lambda_handler"
  runtime       = var.runtime#"python3.10"
  timeout       = var.timeout#"30"
  memory_size   = var.memory_size#"256"

  filename         = data.archive_file.validation_zip.output_path
  source_code_hash = filebase64sha256(data.archive_file.validation_zip.output_path)
}

resource "aws_lambda_permission" "allow_s3" {
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.data_processing.function_name
  principal = "s3.amazonaws.com"
  source_arn = var.raw_bucket_arn
}


###############################
#  S3 TRIGGER FOR RAW ZONE
###############################
resource "aws_s3_bucket_notification" "raw_trigger" {
  bucket = var.raw_bucket

  lambda_function {
    lambda_function_arn = aws_lambda_function.data_processing.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

