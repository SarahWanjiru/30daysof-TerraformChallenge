provider "aws" {
  region = "eu-north-1"
}

resource "aws_security_group" "Web_SG" {
  name        = "day4-sg-v3"
  description = "Allow HTTP and SSH traffic"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "sarahday4instance" {
  ami                    = var.ami
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.Web_SG.id]

  user_data = <<-EOF
#!/bin/bash
dnf update -y
dnf install -y httpd
systemctl start httpd
systemctl enable httpd
echo "<h1>Hello from SarahCanCode!</h1>" > /var/www/html/index.html
EOF

  tags = {
    Name = "SarahDay4Instance"
  }
}

output "instance_public_ip" {
  value = aws_instance.sarahday4instance.public_ip
}
