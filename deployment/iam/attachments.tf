resource "aws_iam_role_policy_attachment" "sagemaker_s3_attach" {
  role       = aws_iam_role.sagemaker_execution_role.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}


# API Gateway Lambda Attachments
resource "aws_iam_role_policy_attachment" "api_gateway_lambda_basic_attach" {
  role       = aws_iam_role.api_gateway_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "api_gateway_lambda_sagemaker_attach" {
  role       = aws_iam_role.api_gateway_lambda_role.name
  policy_arn = aws_iam_policy.sagemaker_invoke_policy.arn
}