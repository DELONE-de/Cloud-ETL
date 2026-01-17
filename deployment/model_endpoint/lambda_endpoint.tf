data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../../scripts/lambda_endpoint.py"
  output_path = "${path.module}/lambda_endpoint.zip"
}

resource "aws_lambda_function" "sagemaker_lambda" {
  function_name = var.lambda_name
  role          = var.api_gateway_lambda_role
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.10"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  timeout = 30
  memory_size = 256

  environment {
    variables = {
      SAGEMAKER_ENDPOINT_NAME = var.sagemaker_endpoint_name
    }
  }
}
