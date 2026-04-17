# Day 27: 3-Tier Multi-Region High Availability Infrastructure

A production-grade, multi-region Terraform implementation deploying a 3-tier architecture across two AWS regions with automatic failover capabilities.

##  Architecture Overview

This project demonstrates enterprise-level Infrastructure as Code by deploying a complete 3-tier application across two AWS regions:

- **Web Tier**: Application Load Balancers in public subnets
- **Application Tier**: Auto Scaling Groups in private subnets
- **Database Tier**: RDS MySQL Multi-AZ in private subnets

**Regions**: eu-north-1 (primary) and eu-west-1 (secondary)

##  Project Structure

```
day27-multi-region-ha/
├── modules/
│   ├── vpc/          # VPC, subnets, NAT gateways, route tables
│   ├── alb/          # Application Load Balancer, target groups
│   ├── asg/          # Auto Scaling Groups, launch templates, CloudWatch alarms
│   ├── rds/          # RDS MySQL with Multi-AZ support
│   └── route53/      # DNS failover routing (optional)
├── envs/
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── provider.tf
│       └── terraform.tfvars
└── backend.tf
```

## Features

### Multi-Region Deployment
- **Primary Region**: eu-north-1 (Stockholm)
- **Secondary Region**: eu-west-1 (Ireland)
- Independent VPCs in each region with full networking stack

### High Availability
- **Multi-AZ**: Resources distributed across 2 availability zones per region
- **Auto Scaling**: CPU-based scaling (70% scale-out, 30% scale-in)
- **Load Balancing**: ALB with health checks in each region
- **Database**: RDS Multi-AZ in primary region

### Security
- **Network Isolation**: Public/private subnet separation
- **Security Groups**: Least-privilege access (ALB → EC2 → RDS)
- **NAT Gateways**: Outbound internet for private subnets
- **Encrypted State**: S3 backend with encryption enabled

### Monitoring
- **CloudWatch Alarms**: CPU-based auto scaling triggers
- **Health Checks**: ALB health checks on `/health` endpoint
- **ELB Health Integration**: ASG uses ALB health status

##  Module Design

### VPC Module (`modules/vpc/`)

**Purpose**: Creates complete networking infrastructure per region

**Resources**:
- VPC with DNS support
- Internet Gateway
- Public subnets (2 AZs)
- Private subnets (2 AZs)
- NAT Gateways (one per AZ)
- Route tables and associations

**Key Variables**:
- `vpc_cidr` - VPC CIDR block (required)
- `public_subnet_cidrs` - List of public subnet CIDRs (required)
- `private_subnet_cidrs` - List of private subnet CIDRs (required)
- `availability_zones` - List of AZs to use (required)

### ALB Module (`modules/alb/`)

**Purpose**: Creates Application Load Balancer infrastructure

**Resources**:
- Application Load Balancer
- Target Group with health checks
- HTTP Listener
- Security Group

**Key Variables**:
- `name` - Name prefix for resources (required)
- `vpc_id` - VPC ID (required)
- `subnet_ids` - Public subnet IDs for ALB (required)

### ASG Module (`modules/asg/`)

**Purpose**: Creates Auto Scaling Group with monitoring

**Resources**:
- Launch Template with user data
- Auto Scaling Group
- Scaling policies (scale-out/scale-in)
- CloudWatch alarms (CPU high/low)
- Security Group

**Key Variables**:
- `launch_template_ami` - AMI ID for region (required)
- `target_group_arns` - ALB target group ARNs (required)
- `alb_security_group_id` - ALB security group ID (required)
- `cpu_scale_out_threshold` - Scale-out CPU % (default: 70)
- `cpu_scale_in_threshold` - Scale-in CPU % (default: 30)

### RDS Module (`modules/rds/`)

**Purpose**: Creates RDS MySQL instance with Multi-AZ support

**Resources**:
- RDS DB Instance
- DB Subnet Group
- Security Group

**Key Variables**:
- `identifier` - DB instance identifier (required)
- `db_name`, `db_username`, `db_password` - Database credentials (required)
- `multi_az` - Enable Multi-AZ (default: true)
- `is_replica` - Set true for read replica (default: false)

### Route53 Module (`modules/route53/`)

**Purpose**: DNS failover routing between regions

**Resources**:
- Route53 health checks (primary/secondary)
- Route53 A records with failover policy

**Note**: Commented out in this deployment (requires real domain)

##  Data Flow Between Modules

The modules are interconnected through outputs and inputs:

```
VPC → ALB (public_subnet_ids)
VPC → ASG (private_subnet_ids)
VPC → RDS (private_subnet_ids)

ALB → ASG (target_group_arn, alb_security_group_id)
ASG → RDS (instance_security_group_id)

RDS Primary → RDS Replica (db_instance_arn) [Free tier limitation]
```

## 📊 Deployment Results

**Total Resources**: 59 resources across 2 regions

### Primary Region (eu-north-1)
- 1 VPC with 2 public + 2 private subnets
- 2 NAT Gateways
- 1 Application Load Balancer
- 1 Auto Scaling Group (2 instances)
- 1 RDS MySQL Multi-AZ instance

### Secondary Region (eu-west-1)
- 1 VPC with 2 public + 2 private subnets
- 2 NAT Gateways
- 1 Application Load Balancer
- 1 Auto Scaling Group (2 instances)

**Outputs**:
```
primary_alb_dns_name   = "ha-day27-alb-eu-nor-1495729507.eu-north-1.elb.amazonaws.com"
secondary_alb_dns_name = "ha-day27-alb-eu-wes-781363599.eu-west-1.elb.amazonaws.com"
primary_rds_endpoint   = <sensitive>
```

##  Live Application Testing

**Primary Region**:
```bash
curl http://ha-day27-alb-eu-nor-1495729507.eu-north-1.elb.amazonaws.com
# Response: Region: eu-north-1 | AZ: eu-north-1a | Environment: prod
```

**Secondary Region**:
```bash
curl http://ha-day27-alb-eu-wes-781363599.eu-west-1.elb.amazonaws.com
# Response: Region: eu-west-1 | AZ: eu-west-1a | Environment: prod
```

Both regions serving traffic independently with region/AZ identification!

##  Security Architecture

### Network Layers
```
Internet
    ↓
ALB (Public Subnet) - Security Group: 0.0.0.0/0:80,443
    ↓
EC2/ASG (Private Subnet) - Security Group: ALB-SG:80
    ↓
RDS (Private Subnet) - Security Group: EC2-SG:3306
```

### Security Groups
- **ALB**: Allows HTTP/HTTPS from internet
- **EC2**: Only accepts traffic from ALB security group
- **RDS**: Only accepts MySQL traffic from EC2 security group

##  Auto Scaling Behavior

### Scale-Out (CPU ≥ 70%)
1. CloudWatch alarm detects CPU ≥ 70% for 2 periods (4 minutes)
2. Triggers scale-out policy
3. ASG adds 1 instance
4. Instance launches in private subnet
5. Registers with ALB target group
6. Health check grace period (300s)
7. ALB begins routing traffic

### Scale-In (CPU ≤ 30%)
1. CloudWatch alarm detects CPU ≤ 30% for 2 periods (4 minutes)
2. Triggers scale-in policy
3. ASG removes 1 instance (down to min_size)

## Free Tier Limitations Encountered

### RDS Cross-Region Read Replica
**Issue**: AWS free tier restricts `backup_retention_period` to 0, but cross-region read replicas require `backup_retention_period >= 1` on the primary instance.

**Error**:
```
FreeTierRestrictionError: The specified backup retention period exceeds 
the maximum available to free tier customers.
```

**Solution**: RDS replica module is commented out. The code is correct and would work on a paid AWS account.

**Architecture Impact**: Primary RDS is Multi-AZ (protects against AZ failure), but no cross-region replica (no protection against full regional outage).

##  Key Learnings

### Multi-AZ vs Cross-Region

**Multi-AZ (Implemented)**:
- Protects against: Single AZ failure
- Failover time: 1-2 minutes (automatic)
- Use case: High availability within a region
- Cost: ~2x single-AZ

**Cross-Region Read Replica (Documented, not deployed)**:
- Protects against: Full regional outage
- Failover time: Manual promotion required
- Use case: Disaster recovery, read scaling
- Cost: Full instance cost + data transfer

### Module Design Philosophy

**Why 5 Modules?**
1. **Single Responsibility**: Each module has one clear purpose
2. **Reusability**: Same VPC module used in both regions
3. **Testability**: Each module can be validated independently
4. **Maintainability**: Changes isolated to specific components

### Provider Configuration

**Multi-Provider Pattern**:
```hcl
provider "aws" {
  alias  = "primary"
  region = "eu-north-1"
}

provider "aws" {
  alias  = "secondary"
  region = "eu-west-1"
}

module "vpc_primary" {
  providers = { aws = aws.primary }
  # ...
}
```

This pattern allows deploying identical infrastructure to multiple regions with a single `terraform apply`.

##  Cleanup

```bash
terraform destroy
```

**Resources Destroyed**: All 59 resources across both regions removed successfully.

**Cost Savings**: NAT Gateways ($0.045/hour each = $0.18/hour total) and RDS ($0.017/hour) stopped immediately.

##  Additional Resources

- [AWS Multi-Region Architecture](https://aws.amazon.com/solutions/implementations/multi-region-application-architecture/)
- [Terraform Multiple Providers](https://developer.hashicorp.com/terraform/language/providers/configuration#alias-multiple-provider-configurations)
- [AWS RDS Multi-AZ](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZ.html)
- [Route53 Failover Routing](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy-failover.html)

