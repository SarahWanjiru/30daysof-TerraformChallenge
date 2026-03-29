# Webserver Cluster Module

A reusable Terraform module that deploys a highly available web server cluster on AWS using an Auto Scaling Group and Application Load Balancer.

## Usage
```hcl
module "webserver_cluster" {
  source = "../../modules/services/webserver-cluster"

  cluster_name  = "webservers-dev"
  instance_type = "t3.micro"
  min_size      = 2
  max_size      = 4
}
```

## Inputs

| Variable | Description | Type | Default | Required |
|---|---|---|---|---|
| cluster_name | Name prefix for all resources | string | none | yes |
| instance_type | EC2 instance type | string | t3.micro | no |
| min_size | Minimum ASG instances | number | none | yes |
| max_size | Maximum ASG instances | number | none | yes |
| server_port | HTTP port | number | 80 | no |
| ami | AMI ID | string | ami-0aaa636894689fa47 | no |
| region | AWS region | string | eu-north-1 | no |

## Outputs

| Output | Description |
|---|---|
| alb_dns_name | DNS name of the load balancer |
| asg_name | Name of the Auto Scaling Group |
| alb_arn | ARN of the load balancer |
