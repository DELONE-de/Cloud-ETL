data "archive_file" "training_code" {
  type        = "zip"
  source_file = "../../sagemaker/train_model.py"
  output_path = "code.tar.gz"
}

resource "aws_s3_object" "training_code" {
  bucket = var.s3_bucket_name
  key    = "code/code.tar.gz"
  source = data.archive_file.training_code.output_path
}


resource "aws_s3_bucket" "model_artifacts_bucket" {
  bucket = var.model_artifacts_bucket
}



resource "aws_s3_object" "etl_script" {
  bucket = var.s3_bucket_name
  key    = "scripts/etl_feature_engineering.py"
  source = "../../glue/etl_feature_engineering.py"
  etag   = filemd5("../../glue/etl_feature_engineering.py")
}


