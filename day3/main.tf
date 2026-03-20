provider "aws" {
    region = "eu-north-1"
}


resource "aws_intance" "sarahinstance" {
    ami = "ami-0aaa636894689fa47"
    intsnace_type = "t3.micro"
}


