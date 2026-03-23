variable "region" {
    description = "The region to deploy resources in"
    type = string
    default = "eu-north-1"
}

variable "day6-s3-bucket" {
    description = "The S3 bucket name for the day6 resource"
    type = string
    default = "sarahcodes-terraform-state-2026"
}

