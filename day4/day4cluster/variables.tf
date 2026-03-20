
variable "server_port" {
    description = "The port the server will use for HTTP requests"
    type = number
    default = 80
}

variable "instance_type" {
    description = "The EC2 instance type to use for the server"
    type = string
    default = "t3.micro"
}

variable "ami" {
    description = "The AMI ID to use for the EC2 instance"
    type = string
    default = "ami-0aaa636894689fa47"
}


variable "region" {
    description = "The AWS region to deploy resources in"
    type = string
    default = "eu-north-1"
}
