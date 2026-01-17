


output "sagemaker_execution_role_arn" {
  value = aws_iam_role.sagemaker_execution_role.arn
}

output "api_gateway_lambda_role_arn" {
  value = aws_iam_role.api_gateway_lambda_role.arn
}

output "sagemaker_invoke_policy_arn" {
  value = aws_iam_policy.sagemaker_invoke_policy.arn
}