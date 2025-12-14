output "uploaded_files_s3_uris" {
  description = "The S3 URIs of the two uploaded artifact files."
  value = [for obj in aws_s3_object.artifact_files : "s3://${obj.bucket}/${obj.key}"]
}

output "lambda_function_arn" {
  description = "The ARN of the created Lambda function."
  value       = aws_lambda_function.sagemaker_packager.arn
}

output "sagemaker_output_uri_example" {
  description = "Example S3 URI where the final SageMaker artifact will be uploaded."
  value       = "s3://${var.s3_bucket_name}/${var.destination_prefix}/<timestamp>-sagemaker_model_artifact.tar.gz"
}

output "api_id" {
  description = "API Gateway REST API ID"
  value       = aws_api_gateway_rest_api.insurance_api.id
}

output "api_url" {
  description = "API Gateway invoke URL"
  value       = "https://${aws_api_gateway_rest_api.insurance_api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${aws_api_gateway_stage.prod.stage_name}"
}

output "health_check_url" {
  description = "Health check endpoint URL"
  value       = "https://${aws_api_gateway_rest_api.insurance_api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${aws_api_gateway_stage.prod.stage_name}/api/health"
}

output "predict_url" {
  description = "Prediction endpoint URL"
  value       = "https://${aws_api_gateway_rest_api.insurance_api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${aws_api_gateway_stage.prod.stage_name}/api/predict"
}

output "form_url" {
  description = "HTML form interface URL"
  value       = "https://${aws_api_gateway_rest_api.insurance_api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${aws_api_gateway_stage.prod.stage_name}/api/predict-form"
}

output "api_key" {
  description = "API key for accessing the API (if created)"
  value       = aws_api_gateway_api_key.main.value
  sensitive   = true
}

