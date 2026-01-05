


# --- SageMaker Model (scikit-learn Script Mode) ---
resource "aws_sagemaker_model" "crop_model" {
  name               = var.model_name
  execution_role_arn = var.sagemaker_execution_role

  primary_container {
    image          = var.sklearn_image_uri
    model_data_url = var.model_data_s3_uri

    environment = {
      # Script Mode entry point
      SAGEMAKER_PROGRAM          = "inference.py"
      SAGEMAKER_SUBMIT_DIRECTORY = var.source_dir_s3_uri

      # Optional quality-of-life settings
      SAGEMAKER_REGION              = data.aws_region.current.name
      SAGEMAKER_CONTAINER_LOG_LEVEL = "20"
    }
  }

  tags = {
    Environment = "dev"
    Project = "cloud-etl"
  }
}

# --- Endpoint Configuration ---
resource "aws_sagemaker_endpoint_configuration" "crop_endpoint_cfg" {
  name = "${var.model_name}-config"

  production_variants {
    variant_name           = "AllTraffic"
    model_name             = aws_sagemaker_model.crop_model.name
    initial_instance_count = 1
    instance_type          = "ml.t2.medium"
    initial_variant_weight = 1
  }

  tags = {
    Environment = "dev"
    Project = "cloud-etl"
  }
}

# --- Real-time Endpoint ---
resource "aws_sagemaker_endpoint" "crop_endpoint" {
  name                 = "${var.model_name}-endpoint"
  endpoint_config_name = aws_sagemaker_endpoint_configuration.crop_endpoint_cfg.name

  tags = {
    Environment = "dev"
    Project = "cloud-etl"
  }
}

