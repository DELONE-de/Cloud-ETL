terraform {
  backend "s3" {
    bucket = "s3-state-bucket"
    key = "ml-data-platform/terraform.tfstate"
    region = "us-east-1"
    dynamodb_table = "terraform_table"
    encrypt = true
  }
}

resource "aws_dynamodb_table" "tf_lock" {
  name         = var.tf_lock_table
  billing_mode = "PAY_PER_REQUEST"
  
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

module "networking" {
    source = "./networking" 
}

module "ingestion" {
    source = "./ingestion"  
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
  
}

module "observability" {
    source = "./observability"
  
}

module "orchestration" {
    source = "./orchestration"
  
}