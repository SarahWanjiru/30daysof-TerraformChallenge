# Day 5 — Terraform State and Scaled Infrastructure

## Overview
Day 5 has two parts. The first is a hands-on lab exploring how Terraform state works. The second is the main task deploying a fully scaled, load-balanced web application on a custom VPC.

## Structure

| Folder | Description |
|---|---|
| `lab1/` | Benefits of State lab — VPC, subnet, IGW, EC2 instance, state experiments |
| `taskday5/` | Full ALB + ASG deployment on a custom VPC with two public subnets |

## Key Concepts Covered
- What terraform.tfstate stores and why it is the source of truth
- How Terraform detects drift between state and real infrastructure
- Why state must never be committed to Git
- How an Application Load Balancer connects to an Auto Scaling Group
- Using data sources to dynamically fetch AMIs and availability zones
