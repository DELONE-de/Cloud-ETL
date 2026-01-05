resource "aws_iam_role" "sagemaker_execution_role" {
  name = "${var.project_prefix}-${var.environment}-sagemaker-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "sagemaker.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role" "api_gateway_lambda_role" {
  name = "${var.project_prefix}-${var.environment}-api-gateway-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# SageMaker Access Policy
resource "aws_iam_policy" "sagemaker_invoke_policy" {
  name = "${var.project_prefix}-${var.environment}-sagemaker-invoke"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sagemaker:InvokeEndpoint"
      ]
      Resource = "arn:aws:sagemaker:*:*:endpoint/*"
    }]
  })
}