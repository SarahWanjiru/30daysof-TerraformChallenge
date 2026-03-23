# Configure the backend block 
terraform {
  backend "s3" {
    bucket = "sarahcodes-terraform-state-2026"
    key = "global/s3/terraform.tfstate"
    region = "eu-north-1"
    dynamodb_table = "sarahcodes-terraform-locks"
    encrypt = true
  }
}