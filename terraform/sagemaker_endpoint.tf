resource "aws_sagemaker_model" "model" {
  name               = "ml-model"
  execution_role_arn = aws_iam_role.sagemaker_role.arn

  primary_container {
    image          = "763104351884.dkr.ecr.us-east-1.amazonaws.com/sklearn-inference:0.23-1-cpu-py3"
    model_data_url = "s3://your-bucket/model.tar.gz"
  }
}

resource "aws_sagemaker_endpoint_configuration" "config" {
  name = "ml-endpoint-config"

  production_variants {
    model_name             = aws_sagemaker_model.model.name
    initial_instance_count = 1
    instance_type          = "ml.t2.medium"
  }
}

resource "aws_sagemaker_endpoint" "endpoint" {
  name                 = "ml-endpoint"
  endpoint_config_name = aws_sagemaker_endpoint_configuration.config.name
}