 terraform {
 backend "s3" {
    bucket         = "sarahcodes-terraform-state-2026"
    key            = "day27/multi-region-ha/prod/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "sarahcodes-terraform-locks"
    encrypt        = true
  }
}