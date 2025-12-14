resource "aws_kinesis_stream" "ingest_stream" {
  name        = "${var.project_prefix}-ingest-stream"
  shard_count = 1
}

resource "aws_s3_bucket" "raw" {
  bucket = "${var.project_prefix}-raw-data-${random_id.bucket_suffix.hex}"
}

resource "aws_kms_key" "ingest" {
  description = "KMS key for data ingestion"
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "processed" {
  bucket = "${var.project_prefix}-processed-data-${random_id.bucket_suffix.hex}"
}

module "networking" {
    source = "./networking"
    aws_region = var.aws_region
    project_prefix = var.project_prefix
    environment = var.environment
}

module "ingestion" {
    source = "./ingestion"
    project_prefix = var.project_prefix
    environment = var.environment
}

module "validation" {
    source = "./validation"
    project_prefix = var.project_prefix
    environment = var.environment
}


module "processing" {
    source = "./processing"
}

module "ci_cd" {
    source = "./ci_cd"

}

module "deployment" {
    source = "./deployment"
    model_version = "1.0"
    api_url = "https://api.example.com"
    sagemaker_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/SageMakerExecutionRole"
}

module "iam" {
    source = "./iam"
    project_name = var.project_name
    environment = var.environment
    aws_region = var.aws_region
    secret_arn = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_prefix}-secret"
    kinesis_stream_arn = aws_kinesis_stream.ingest_stream.arn
    cloudwatch_log_arn = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
    s3_bucket_arn = aws_s3_bucket.raw.arn
    step_function_arn = "arn:aws:states:${var.aws_region}:${data.aws_caller_identity.current.account_id}:stateMachine:${var.project_prefix}-pipeline"
    s3_bucket_name = aws_s3_bucket.raw.bucket
    processed_bucket_arn = aws_s3_bucket.processed.arn
    name_prefix = var.project_prefix
    api_url = "https://api.example.com"
    kms_key_arn = aws_kms_key.ingest.arn
    project_prefix = var.project_prefix
    sagemaker_exec_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/SageMakerExecutionRole"
    raw_bucket_arn = aws_s3_bucket.raw.arn
}

module "observability" {
    source = "./observability"
    validation_lambda_name = "${var.project_prefix}-validation-lambda"
    alarm_sns_topic_arn = "arn:aws:sns:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.project_prefix}-alarms"
    project_prefix = var.project_prefix
    project_name = var.project_name
    environment = var.environment
    name_prefix = var.project_prefix
}

module "orchestration" {
    source = "./orchestration"
    environment = var.environment
    glue_job_names = ["etl-job-1", "etl-job-2"]
    step_function_arn = "arn:aws:states:${var.aws_region}:${data.aws_caller_identity.current.account_id}:stateMachine:${var.project_prefix}-pipeline"
    project_name = var.project_name
    s3_bucket_name = "${var.project_prefix}-etl-bucket"
}

module "security" {
    source = "./security"
    project_prefix = var.project_prefix
    environment = var.environment
}