# Day 26: Scalable Web Application with Auto Scaling on AWS

A production-grade, modular Terraform implementation that deploys a scalable web application on AWS using EC2 Launch Templates, Application Load Balancer, and Auto Scaling Group with CloudWatch monitoring.

## Architecture Overview

This project demonstrates Infrastructure as Code best practices by splitting functionality into three focused modules:

- **EC2 Module**: Launch Template and instance security group
- **ALB Module**: Application Load Balancer, target group, and HTTP listener  
- **ASG Module**: Auto Scaling Group with CPU-based scaling policies and CloudWatch alarms

## Project Structure

```
day26-scalable-web-app/
├── modules/
│   ├── ec2/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── alb/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── asg/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── envs/
│   └── dev/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars
├── backend.tf
├── provider.tf
└── variables.tf
```

## Features

### Core Infrastructure
- **Multi-AZ Deployment**: Instances distributed across availability zones
- **Auto Scaling**: Scales 1-4 instances based on CPU utilization
- **Load Balancing**: Application Load Balancer with health checks
- **Security**: Proper security groups for ALB and EC2 instances
- **Monitoring**: CloudWatch alarms for scale-out (70% CPU) and scale-in (30% CPU)

### Bonus Features
- **CloudWatch Dashboard**: Real-time monitoring of CPU and instance metrics
- **ALB Request Monitoring**: High request count alarm (1000+ requests/target)
- **Clean Teardown**: Force delete enabled for dev environments

## Module Design

### EC2 Module (`modules/ec2/`)

**Purpose**: Creates Launch Template and instance security group

**Key Resources**:
- `aws_launch_template.web`: Defines instance configuration with user data
- `aws_security_group.instancesg`: Allows HTTP/HTTPS inbound traffic

**Variables**:
- `instance_type`: EC2 instance type (default: "t3.micro")
- `ami_id`: AMI ID for instances (required)
- `key_name`: SSH key pair name (default: null)
- `environment`: Deployment environment with validation
- `tags`: Additional resource tags

### ALB Module (`modules/alb/`)

**Purpose**: Creates Application Load Balancer infrastructure

**Key Resources**:
- `aws_lb.alb`: Application Load Balancer with security hardening
- `aws_lb_target_group.tg`: Target group with health check configuration
- `aws_lb_listener.http`: HTTP listener for traffic routing
- `aws_security_group.albsg`: ALB security group
- `aws_cloudwatch_metric_alarm.high_request_count`: Traffic spike monitoring

**Variables**:
- `name`: Name prefix for ALB resources (required)
- `vpc_id`: VPC ID for ALB placement (required)
- `subnet_ids`: Public subnet IDs for ALB (required)
- `environment`: Deployment environment (required)
- `tags`: Additional resource tags

### ASG Module (`modules/asg/`)

**Purpose**: Creates Auto Scaling Group with monitoring and policies

**Key Resources**:
- `aws_autoscaling_group.web`: Auto Scaling Group with ELB health checks
- `aws_autoscaling_policy.cpu_scale_out/in`: Scaling policies
- `aws_cloudwatch_metric_alarm.cpu_high/low`: CPU-based alarms
- `aws_cloudwatch_dashboard.web`: Monitoring dashboard

**Variables**:
- `launch_template_id`: Launch template ID from EC2 module (required)
- `target_group_arns`: ALB target group ARNs (required)
- `min_size`, `max_size`, `desired_capacity`: Scaling configuration
- `cpu_scale_out_threshold`: Scale-out CPU threshold (default: 70%)
- `cpu_scale_in_threshold`: Scale-in CPU threshold (default: 30%)

## Data Flow Between Modules

The modules are interconnected through outputs and inputs:

1. **EC2 → ASG**: `module.ec2.launch_template_id` flows into ASG's `launch_template_id`
2. **ALB → ASG**: `module.alb.target_group_arn` flows into ASG's `target_group_arns`
3. **ASG → Monitoring**: CloudWatch alarms monitor ASG and trigger scaling policies

This design keeps each module focused on a single responsibility while enabling clean integration.

## Auto Scaling Behavior

### Scale-Out Trigger (CPU ≥ 70%)
1. CloudWatch alarm `cpu_high` detects average CPU ≥ 70% for 2 evaluation periods
2. Alarm triggers `aws_autoscaling_policy.cpu_scale_out`
3. ASG adds 1 instance (up to max_size of 4)
4. New instance registers with ALB target group
5. Health check grace period (300s) allows instance to become healthy

### Scale-In Trigger (CPU ≤ 30%)
1. CloudWatch alarm `cpu_low` detects average CPU ≤ 30% for 2 evaluation periods  
2. Alarm triggers `aws_autoscaling_policy.cpu_scale_in`
3. ASG removes 1 instance (down to min_size of 1)

### Health Check Integration
- `health_check_type = "ELB"` ensures ASG only considers instances healthy when ALB health checks pass
- This prevents traffic routing to unhealthy instances during scaling events

## Security Features

- **ALB Security**: `drop_invalid_header_fields = true` prevents header injection attacks
- **Security Groups**: Least-privilege access with specific port rules
- **IMDSv2**: Launch template enforces metadata service v2
- **Encrypted State**: S3 backend with `encrypt = true`

## Monitoring & Observability

### CloudWatch Dashboard
- **CPU Utilization**: Real-time CPU metrics with scaling thresholds
- **Instance Count**: ASG instance count with desired capacity line
- **Access URL**: Available in terraform outputs as `dashboard_url`

### Alarms
- **CPU High/Low**: Triggers auto scaling based on CPU utilization
- **High Request Count**: Monitors ALB traffic spikes (1000+ requests/target)

## Deployment

### Prerequisites
- AWS CLI configured with appropriate permissions
- Terraform >= 1.0 installed
- Valid VPC and subnet IDs

### Deploy
```bash
cd envs/dev
terraform init
terraform validate
terraform plan
terraform apply
```

### Access Application
After deployment, access your application using the ALB DNS name from outputs:
```bash
terraform output alb_dns_name
```

### Monitor
Access the CloudWatch dashboard:
```bash
terraform output dashboard_url
```

## Cleanup

The ASG module includes `force_delete = true` for non-production environments to ensure clean teardown:

```bash
terraform destroy
```

## Key Learnings

### Why Three Modules?
- **Single Responsibility**: Each module has one clear purpose
- **Reusability**: Modules can be used across environments
- **Maintainability**: Changes are isolated to specific components
- **Testing**: Each module can be tested independently

### Critical Configuration Details
- **ELB Health Checks**: `health_check_type = "ELB"` prevents routing to unhealthy instances
- **Target Group Integration**: `target_group_arns` connects ASG to ALB
- **Lifecycle Management**: `create_before_destroy` ensures zero-downtime updates

## Resource Tags

All resources include consistent tagging:
- `Environment`: Deployment environment (dev/staging/production)
- `ManagedBy`: "Terraform" 
- `Project`: "scalable-web-app"
- Custom tags from variables

## Infrastructure Metrics

**Total Resources Created**: 13
- 1 Launch Template
- 2 Security Groups  
- 1 Application Load Balancer
- 1 Target Group
- 1 ALB Listener
- 1 Auto Scaling Group
- 2 Scaling Policies
- 2 CloudWatch Alarms
- 1 CloudWatch Dashboard
- 1 ALB Request Count Alarm



## Additional Resources

- [AWS EC2 Auto Scaling Documentation](https://docs.aws.amazon.com/autoscaling/ec2/)
- [AWS Application Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

