# modules/sagemaker/main.tf

locals {
  timestamp = formatdate("YYYYMMDD-hhmm", timestamp())
}

# SageMaker model
resource "aws_sagemaker_model" "main" {
  name               = "${var.name_prefix}-model-${local.timestamp}"
  execution_role_arn = var.sagemaker_role_arn

  primary_container {
    image          = var.container_image
    model_data_url = var.model_data_url
    environment = {
      SAGEMAKER_PROGRAM           = "inference_handler.py"
      SAGEMAKER_SUBMIT_DIRECTORY  = "/opt/ml/model"
      SAGEMAKER_CONTAINER_LOG_LEVEL = "20"
      MODEL_SERVER_WORKERS        = "1"
      MAX_REQUEST_SIZE            = "100000000"
      MAX_RESPONSE_SIZE           = "100000000"
    }

    dynamic "image_config" {
      for_each = var.kms_key_id != "" ? [1] : []
      content {
        repository_access_mode = "Platform"
      }
    }
  }

  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [1] : []
    content {
      security_group_ids = var.vpc_config.security_group_ids
      subnets            = var.vpc_config.subnet_ids
    }
  }

  enable_network_isolation = var.enable_network_isolation

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-model"
  })
}

# SageMaker endpoint configuration
resource "aws_sagemaker_endpoint_configuration" "main" {
  name = "${var.name_prefix}-endpoint-config-${local.timestamp}"

  production_variants {
    variant_name           = "AllTraffic"
    model_name             = aws_sagemaker_model.main.name
    initial_instance_count = var.instance_count
    instance_type          = var.instance_type
    initial_variant_weight = 1.0

    dynamic "serverless_config" {
      for_each = var.serverless_config != null ? [1] : []
      content {
        max_concurrency = var.serverless_config.max_concurrency
        memory_size_in_mb = var.serverless_config.memory_size_mb
      }
    }
  }

  dynamic "data_capture_config" {
    for_each = var.enable_data_capture ? [1] : []
    content {
      enable_capture              = true
      initial_sampling_percentage = 100
      destination_s3_uri          = var.data_capture_s3_uri
      capture_options {
        capture_mode = "Input"
      }
      capture_options {
        capture_mode = "Output"
      }
      capture_content_type_header {
        json_content_types = ["application/json", "application/x-www-form-urlencoded"]
        csv_content_types  = ["text/csv"]
      }
    }
  }


  tags = merge(var.tags, {
    Name = "${var.name_prefix}-endpoint-config"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# SageMaker endpoint
resource "aws_sagemaker_endpoint" "main" {
  name                 = "${var.name_prefix}-endpoint"
  endpoint_config_name = aws_sagemaker_endpoint_configuration.main.name

  deployment_config {
    blue_green_update_policy {
      traffic_routing_configuration {
        type = "ALL_AT_ONCE"

        wait_interval_in_seconds = 0
      }

      termination_wait_in_seconds = 0
    }

    auto_rollback_configuration {
      alarms {
        alarm_name = aws_cloudwatch_metric_alarm.endpoint_errors[0].alarm_name
      }
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-endpoint"
  })

  lifecycle {
    ignore_changes = [
      endpoint_config_name
    ]
  }
}

# CloudWatch alarm for endpoint errors


