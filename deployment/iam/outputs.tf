


output "sagemaker_invoke_policy_arn" {
  value = aws_iam_policy.sagemaker_invoke_policy.arn

}

output "api_gateway_lambda_role" {
  value = aws_iam_role.api_gateway_lambda_role

}