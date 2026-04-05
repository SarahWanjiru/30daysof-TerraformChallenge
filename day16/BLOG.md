TITLE (paste into Medium title field):
Creating Production-Grade Infrastructure with Terraform

SUBTITLE (paste into Medium subtitle field):
There is a big difference between Terraform code that works and Terraform code that is production-ready. Day 16 of my challenge was about closing that gap.

---

BODY (paste everything below into Medium):

---

Introduction

On Day 16 of my 30-Day Terraform Challenge, I did something uncomfortable.

I audited my own code.

I went through every module I had built over the past two weeks and scored it against a production-grade checklist from Chapter 8 of Terraform: Up & Running.

The result was humbling. Some things I had done right. A lot of things I had missed.

This post walks through what the checklist covers, the three most impactful changes I made, and what I learned about the gap between "it works" and "it's production-ready."


What Does Production-Grade Actually Mean?

The checklist breaks down into five categories:

Code structure — are modules small, focused, and well-documented?
Reliability — will the infrastructure survive updates without downtime?
Security — are secrets protected? Is access restricted?
Observability — can you tell when something is wrong?
Maintainability — can someone else understand and change this code under pressure?

I had been focused almost entirely on the first two. The last three had gaps.


1. The Tagging Problem

Before today, my resources looked like this:

resource "aws_security_group" "instance_sg" {
  name = "${var.cluster_name}-instance-sg"
  # no tags at all
}

resource "aws_lb" "web" {
  name = "${var.cluster_name}-alb"
  tags = { Name = "${var.cluster_name}-alb" }
  # missing Environment, ManagedBy, Project, Owner
}

In a real AWS account with hundreds of resources, untagged resources are impossible to attribute to a team, a project, or a cost centre. You cannot answer "who owns this?" or "what does this cost?" without tags.

The fix — a common_tags local applied to every resource:

locals {
  common_tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = var.project_name
    Owner       = var.team_name
  }
}

resource "aws_security_group" "instance_sg" {
  name = "${var.cluster_name}-instance-sg"
  tags = merge(local.common_tags, { Name = "${var.cluster_name}-instance-sg" })
}

resource "aws_lb" "web" {
  name = "${var.cluster_name}-alb"
  tags = merge(local.common_tags, { Name = "${var.cluster_name}-alb" })
}

merge() combines the common tags with the resource-specific Name tag. Change project_name once in the calling config — every resource updates automatically.

📸 Screenshot here — your module code showing merge(local.common_tags, {...}) on a resource
Caption: common_tags applied via merge() — one change updates every resource in the module


2. prevent_destroy on Critical Resources

Before today, the ALB had no lifecycle protection:

resource "aws_lb" "web" {
  name = "${var.cluster_name}-alb"
}

A misconfigured terraform destroy or a variable change that forces ALB recreation would take down the load balancer — and all traffic with it.

After:

resource "aws_lb" "web" {
  name = "${var.cluster_name}-alb"

  lifecycle {
    prevent_destroy = true
  }
}

With prevent_destroy, Terraform errors before touching the ALB:

Error: Instance cannot be destroyed
Resource aws_lb.web has lifecycle.prevent_destroy set to true.

You must explicitly remove the lifecycle block to destroy it. In production this is a feature, not a bug.

I immediately discovered the downside — I could not run terraform destroy to clean up after testing. Had to temporarily remove the lifecycle block. This is the intended behaviour.


3. CloudWatch Alarms That Actually Notify Someone

Before today, the CloudWatch alarm existed but fired silently:

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  threshold = 80
  # no alarm_actions — alarm fires but nobody is notified
}

After — SNS topic wired to the alarm:

resource "aws_sns_topic" "alerts" {
  name = "${var.cluster_name}-alerts"
  tags = merge(local.common_tags, { Name = "${var.cluster_name}-alerts" })
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.cluster_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "CPU utilization exceeded 80% for 4 minutes on ${var.cluster_name}"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

When CPU exceeds 80% for 4 consecutive minutes, the alarm fires and publishes to the SNS topic. Subscribe an email address or a PagerDuty endpoint to the topic to receive the notification.

80% threshold — chosen because sustained CPU above 80% indicates real load, not a brief spike. evaluation_periods = 2 with period = 120 means 4 minutes of sustained high CPU before the alarm fires.


4. Input Validation on Every Constrained Variable

I already had validation on environment and active_environment from Day 11. Today I added it to instance_type:

variable "instance_type" {
  description = "EC2 instance type — must be t2 or t3 family"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = can(regex("^t[23]\\.", var.instance_type))
    error_message = "Instance type must be a t2 or t3 family type."
  }
}

can(regex(...)) — can() returns true if the expression does not error. regex() errors when there is no match. So this returns true only when the instance type starts with t2. or t3.

Passing instance_type = "m5.large" returns:

Error: Invalid value for variable
Instance type must be a t2 or t3 family type.

At plan time. Before any API calls.


5. GitHub Actions CI Pipeline

Instead of running Terratest locally (which requires Go), I set up a GitHub Actions workflow
that runs automated checks on every push to main and every pull request.

name: Terraform CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  terraform:
    runs-on: ubuntu-latest
    env:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      AWS_DEFAULT_REGION: eu-north-1
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.11.0"
      - name: Terraform Format Check
        run: terraform fmt -check -recursive
      - name: Validate day16 module
        working-directory: day16/modules/services/webserver-cluster
        run: |
          terraform init -backend=false
          terraform validate
      - name: Plan day16 dev
        id: plan
        working-directory: day16/live/dev/services/webserver-cluster
        run: |
          terraform init
          terraform plan -no-color
        continue-on-error: true

What each step does:

- terraform fmt -check -recursive — fails if any file is not formatted correctly
- terraform init -backend=false — initialises the module without connecting to S3
- terraform validate — checks syntax without calling AWS
- terraform plan — runs a real plan using credentials from GitHub secrets

The error I hit:

The original plan step had no id field. The post-plan step referenced steps.plan.outputs.stdout
but GitHub Actions could not find the step because it had no id to reference. Fixed by adding
id: plan to the plan step.

This is the practical alternative to Terratest for teams that do not use Go. Every push to
main now runs format checks, validation, and a plan automatically.


6. Automated Testing with Terratest

The last item on the checklist — automated tests.

Manual testing means: deploy, check it works, destroy. You do this once. Then someone changes the module three months later and nobody tests it again.

Automated testing means: every change to the module runs the test. If the change breaks something, the test catches it before it reaches production.

package test

import (
    "fmt"
    "testing"
    "time"

    http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
    "github.com/gruntwork-io/terratest/modules/terraform"
)

func TestWebserverCluster(t *testing.T) {
    t.Parallel()

    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir: "../modules/services/webserver-cluster",
        Vars: map[string]interface{}{
            "cluster_name":  "test-cluster",
            "instance_type": "t3.micro",
            "min_size":      1,
            "max_size":      2,
            "environment":   "dev",
        },
    })

    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndApply(t, terraformOptions)

    albDnsName := terraform.Output(t, terraformOptions, "alb_dns_name")
    url := fmt.Sprintf("http://%s", albDnsName)

    http_helper.HttpGetWithRetry(t, url, nil, 200, "Hello", 30, 10*time.Second)
}

What it does:

1. Runs terraform init and terraform apply with test variables
2. Gets the ALB DNS name from outputs
3. Hits the URL and retries for up to 5 minutes until it gets a 200 response
4. defer terraform.Destroy runs destroy after the test — even if the test fails

defer is the most important line. Without it, a failed assertion would leave real AWS resources running and incurring cost. defer guarantees cleanup regardless of test outcome.

I did not run this test today — it requires Go and Terratest installed, and would deploy real AWS resources. But writing it and understanding what it tests is the learning objective.


The Checklist Results

Code structure — ✅ all passing
Reliability — ✅ all passing (create_before_destroy, name_prefix, prevent_destroy added today)
Security — ✅ mostly passing (Secrets Manager, sensitive = true, encrypted state)
Observability — ⚠️ tagging and SNS added today, log groups still missing
Maintainability — ✅ all passing

The gap was smaller than I expected. The patterns from Days 11-15 — create_before_destroy, validation blocks, sensitive = true, encrypted state — were already on the checklist. The checklist is not a new set of things to learn. It is a way of verifying that the things you have been learning are actually applied consistently.


7. The CI Pipeline Errors

Setting up the GitHub Actions pipeline hit three errors worth documenting.

Error 1 — terraform fmt failing on old files

The fmt check ran against the entire repo and failed on unformatted files from days 3-12.
Fixed by scoping it to day16/ only.

Error 2 — missing id on the plan step

The post-plan comment step referenced steps.plan.outputs.stdout but the plan step had no
id field. GitHub Actions could not find the step. Fixed by adding id: plan.

Error 3 — Secrets Manager secret deleted

The day13/db/credentials secret had been deleted after the password was accidentally
published in the blog. The pipeline failed with:

couldn't find resource
  with module.webserver_cluster.data.aws_secretsmanager_secret.db_credentials

AWS puts deleted secrets into a scheduled deletion window — you cannot create a new secret
with the same name until the window expires. Fixed by restoring the secret first:

aws secretsmanager restore-secret --secret-id "day13/db/credentials" --region eu-north-1
aws secretsmanager put-secret-value --secret-id "day13/db/credentials" \
  --secret-string '{"username":"dbadmin","password":"<new-password>"}'

This is also why you never publish real passwords in blog posts — even as examples.


Key Lessons Learned

- Consistent tagging with merge(local.common_tags, {...}) costs almost nothing to implement and makes the entire infrastructure auditable
- prevent_destroy protects critical resources from accidental deletion — but blocks terraform destroy during testing
- CloudWatch alarms that fire silently are useless — always wire alarm_actions to an SNS topic
- can(regex(...)) is the correct pattern for validating string format in Terraform
- defer terraform.Destroy in Terratest is not optional — it is what prevents test failures from leaving orphaned AWS resources
- The production checklist is not a new set of things — it is a verification that the things you have been learning are applied consistently


Final Thoughts

The most valuable part of today was not the code changes. It was the audit.

Going through the checklist and honestly marking what was missing forced me to see my own infrastructure the way a senior engineer would see it. Not "does it work?" but "would I trust this in production?"

The answer was mostly yes — with a few gaps to close.

I am currently doing the 30-Day Terraform Challenge while building Cloud and DevOps skills in public. Open to opportunities — using this time to build real-world skills by actually doing and breaking things.

If you are also learning Terraform or DevOps, let's connect and grow together.

#30DayTerraformChallenge #TerraformChallenge #Terraform #DevOps #IaC #AWSUserGroupKenya #EveOps #WomenInTech #BuildInPublic #CloudComputing #AWS #Kubernetes #Andela
