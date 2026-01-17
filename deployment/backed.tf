terraform {
  backend "s3" {
    bucket = "my2007-terraform-state-bucket"
    key    = "terraform-deployment/terraform.tfstate"
    region = "us-east-1"
  }
}
