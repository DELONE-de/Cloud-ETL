data "archive_file" "training_code" {
  type        = "zip"
  source_file = "${path.module}/../../sagemaker/train_model.py"
  output_path = "${path.root}/sagemaker/train_model.py.code.tar.gz"
}

resource "aws_s3_bucket" "etl-bucket" {
  bucket = var.s3_bucket_name
  
}

resource "aws_s3_object" "training_code" {
  bucket = aws_s3_bucket.etl-bucket.id
  key    = "code/code.tar.gz"
  source = data.archive_file.training_code.output_path
  etag   = data.archive_file.training_code.output_md5

  depends_on = [aws_s3_bucket.etl-bucket]
}



resource "aws_s3_bucket" "model_artifacts_bucket" {
  bucket = "cloud-etl-model-artifacts"
}



resource "aws_s3_object" "etl_script" {
  bucket = aws_s3_bucket.etl-bucket.id
  key    = "scripts/etl_feature_engineering.py"
  source = "${path.module}/../../glue/etl_feature_engineering.py"
  etag   = filemd5("${path.module}/../../glue/etl_feature_engineering.py")
}


