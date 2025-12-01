variable "tf_state_bucket"{
    type = string
    description = "state_bucket"
}    
    
variable "region" {
  type = string
  description = "us-east-1"
}

variable "tf_lock_table" {
  type = string
  description = "terraform_table"
}