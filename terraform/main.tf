

module "networking" {
    source = "./networking" 
}

module "ingestion" {
    source = "./ingestion"  
}

module "Validation" {
  
}

module "enrichment" {
    source = "./enrichment"
  
}
module "processing" {
    source = "./processing"
}

module "ci_cd" {
    source = "./ci_cd"
  
}

module "deployment" {
    source = "./deployment"
  
}

module "iam" {
    source = "./iam"
    project_prefix      = var.project_prefix
    environment         = var.environment
    producer_service    = "ec2.amazonaws.com"
    kinesis_stream_arn  = aws_kinesis_stream.ingest_stream.arn
    s3_bucket_arn       = aws_s3_bucket.raw.arn
    kms_key_arn         = aws_kms_key.ingest.arn
    cloudwatch_log_arn  = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
}
  

module "observability" {
    source = "./observability"
  
}

module "orchestration" {
    source = "./orchestration"
  
}

module "security" {
    source = "./security"
    project_prefix = var.project_prefix
    environment = var.environment

}