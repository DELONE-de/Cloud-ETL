output "sagemaker_endpoint_name" {
  value = aws_sagemaker_endpoint.crop_endpoint.name
}

output "sagemaker_model_name" {
  value = aws_sagemaker_model.crop_model.name
}