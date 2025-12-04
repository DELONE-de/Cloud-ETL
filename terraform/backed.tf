terraform {
  backend "s3" {
    bucket = "s3-state-bucket"
    key = "ml-data-platform/terraform.tfstate"
    region = "us-east-1"
  }
}