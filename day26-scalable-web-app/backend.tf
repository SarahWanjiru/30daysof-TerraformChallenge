 terraform {
 backend "s3" {
    bucket         = "sarahcodes-terraform-state-2026"
    key            = "day26/scalable-web-app/dev/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "sarahcodes-terraform-locks"
    encrypt        = true
  }
}
