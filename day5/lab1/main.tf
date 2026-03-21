provider "aws" {
    region = var.region
}

data "aws_availability_zones" "available" {
    state = "available"
}

data "aws_ami" "amazon_linux" {
    most_recent = true

    filter {
        name = "name"
        values = ["al2023-ami-*-x86_64"]
    }

    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }

    owners = ["amazon"]
}

resource "aws_vpc" "day5vpc" {
    cidr_block = var.vpc_cidr
    tags = {
        Name = "day5VPC"
    }
}


resource "aws_subnet" "day5publicsubnet" {
    vpc_id = aws_vpc.day5vpc.id
    cidr_block = var.public_subnet_cidr
    availability_zone = data.aws_availability_zones.available.names[0]
    map_public_ip_on_launch = true
    tags = {
        Name = "day5PublicSubnet"
    }
}

resource "aws_internet_gateway" "day5igw" {
    vpc_id = aws_vpc.day5vpc.id
    tags = {
        Name = "day5IGW"
    }
}


resource "aws_instance" "day5instance" {
    ami = data.aws_ami.amazon_linux.id
    instance_type = var.instance_type
    subnet_id = aws_subnet.day5publicsubnet.id
    tags = {
        Name = "day5Instance"
    }
}


output "instance_public_ip" {
    value = aws_instance.day5instance.public_ip
}

output "instance_id" {
    value = aws_instance.day5instance.id
}

output "ami_used" {
    value = data.aws_ami.amazon_linux.id
}
