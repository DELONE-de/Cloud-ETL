



module "deployment" {
  source = "./model_endpoint"
  project_prefix = "cloud-etl"
  sagemaker_endpoint_name = "my endpoint_name_demo"
  lambda_name = "my_lambda_demo"

  # Required attributes
  tags = {
    Environment = "dev"
    Project = "cloud-etl"
  }
  destination_prefix = "models/"
  model_name = "crop-recommendation-model"
  source_prefix = "raw/"
  target_bucket_name = "cloud-etl-model-artifacts"
  model_data_s3_uri = "s3://cloud-etl-model-artifacts/models/model.tar.gz"
  source_dir_s3_uri = "s3://cloud-etl-model-artifacts/code/code.tar.gz"
  s3_key_prefix = "inference/"
  sklearn_image_uri = "683313688378.dkr.ecr.us-east-1.amazonaws.com/sagemaker-scikit-learn:0.23-1-cpu-py3"
  s3_bucket_name = "cloud-etl-model-artifacts"
  sagemaker_execution_role = module.iam.sagemaker_execution_role_arn
  api_gateway_lambda_role = module.iam.api_gateway_lambda_role_arn
}


module "iam" {
  source = "./iam"
  environment = "dev"
  project_prefix = "cloud-etl"

}