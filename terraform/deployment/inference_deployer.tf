

data "aws_s3_bucket" "target" {
  bucket = var.target_bucket_name
}


locals {
  # This map defines the local file path and the desired S3 file name (key suffix)
  files_to_upload = {
    # Key is the unique identifier for the Terraform resource instance
    "inference_script" = {
      local_path   = "../sagemaker/inference_handler.py"
      key_suffix   = "inference.py"
      content_type = "text/x-python"
    }
    "python_deps" = {
      local_path   = "requirements.txt"
      key_suffix   = "requirements.txt"
      content_type = "text/plain"
    }
  }
}

# --- Resource: Upload Both Files using for_each ---

resource "aws_s3_object" "artifact_files" {
  # Iterate over the files_to_upload map
  for_each = local.files_to_upload

  bucket = data.aws_s3_bucket.target.id

  # The final S3 Key: prefix + filename (e.g., sagemaker/my-app/inference.py)
  key = "${var.s3_key_prefix}/${each.value.key_suffix}"

  # The local source file path
  source = each.value.local_path

  # Set the content type based on the map definition
  content_type = each.value.content_type

  # Triggers an update only if the content of the local file changes
  etag = filemd5(each.value.local_path)
}






# --- 1. Package Lambda Function Code into a ZIP File ---
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "../scripts/inference_deployer.py"
  output_path = "../scripts/my_archive.zip"
}





# --- 3. The AWS Lambda Function Resource ---

resource "aws_lambda_function" "sagemaker_packager" {
  function_name = "SageMakerArtifactPackager"

  # References the ZIP file created by the data source
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  role    = aws_iam_role.sagemaker_packager_role.arn
  handler = "inference_deployer.handler" # entrypoint: inference_deployer.handler
  runtime = "python3.11"

  # Critical settings for file processing:
  timeout     = 60  # Give it plenty of time for S3 transfers (default is 3s)
  memory_size = 512 # Increase memory for file operations (default is 128MB)

  # Pass S3 configuration to the Python script via environment variables
  environment {
    variables = {
      SOURCE_BUCKET_NAME = var.s3_bucket_name
      SOURCE_PREFIX      = var.source_prefix
      DESTINATION_PREFIX = var.destination_prefix
    }
  }
}

# --- Output ---
output "lambda_function_arn1" {
  description = "The ARN of the created Lambda function."
  value       = aws_lambda_function.sagemaker_packager.arn
}

output "sagemaker_output_uri" {
  description = "Example S3 URI where the final SageMaker artifact will be uploaded."
  value       = "s3://${var.s3_bucket_name}/${var.destination_prefix}/<timestamp>-sagemaker_model_artifact.tar.gz"
}

