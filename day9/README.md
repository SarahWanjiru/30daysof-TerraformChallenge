# Day 9: Advanced Terraform Modules — Versioning, Gotchas, and Multi-Environment Reuse

## What I Did Today

Went deeper into Terraform modules — specifically the rough edges that cause real bugs in production. Learned how to version modules using Git tags, pin different environments to different versions, and write a README good enough that a stranger can use the module without asking questions.

---

## Module Gotchas

### Gotcha 1 — File Paths Inside Modules

Relative paths like `./user-data.sh` resolve from where `terraform apply` is run, not from the module directory. If the caller is in `live/dev/`, the path breaks entirely.

```hcl
# broken — resolves relative to the caller, not the module
user_data = templatefile("./user-data.sh", {
  server_port = var.server_port
})
```

```hcl
# corrected — always resolves relative to the module file itself
user_data = templatefile("${path.module}/user-data.sh", {
  server_port = var.server_port
})
```

### Gotcha 2 — Inline Blocks vs Separate Resources

`aws_security_group` supports both inline `ingress`/`egress` blocks and standalone `aws_security_group_rule` resources. Mixing both causes Terraform to fight itself — rules get removed and re-added on every plan.

```hcl
# broken — mixing inline block with a separate rule resource
resource "aws_security_group" "alb_sg" {
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "extra" {   # conflicts with inline block above
  type              = "ingress"
  security_group_id = aws_security_group.alb_sg.id
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}
```

```hcl
# corrected — use only inline blocks OR only separate resources, never both
resource "aws_security_group" "alb_sg" {
  name   = "${var.cluster_name}-alb-sg"
  vpc_id = data.aws_vpc.default.id
  # no inline ingress/egress blocks — all rules managed via aws_security_group_rule
}

resource "aws_security_group_rule" "http" {
  type              = "ingress"
  security_group_id = aws_security_group.alb_sg.id
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}
```

Separate resources are the better choice for modules — callers can add rules without touching the module.

### Gotcha 3 — Module Output Dependencies

When a root config uses `depends_on` pointing at a module output, Terraform treats the **entire module** as the dependency — not just the specific resource. This causes Terraform to destroy and recreate resources that didn't need to change.

```hcl
# broken — depends_on a module output forces full module re-evaluation
resource "aws_route53_record" "app" {
  depends_on = [module.webserver_cluster]   # recreates everything if any module resource changes
  name       = "app.example.com"
}
```

```hcl
# corrected — reference the specific output directly, no depends_on needed
resource "aws_route53_record" "app" {
  name    = "app.example.com"
  records = [module.webserver_cluster.alb_dns_name]   # Terraform infers the dependency automatically
}
```

Expose granular outputs from your module so callers can reference exactly what they need.

---

## Versioned Module Repository

**GitHub:** https://github.com/SarahWanjiru/terraform-aws-webserver-cluster

```bash
$ git tag -l
v0.0.1
v0.0.2
```

**What changed between versions:**

- `v0.0.1` — initial module: ASG + ALB + security groups, outputs `alb_dns_name`, `asg_name`, `alb_arn`
- `v0.0.2` — added `alb_security_group_id` output so callers can attach custom security group rules without modifying the module

---

## Multi-Environment Calling Configurations

### Dev — uses v0.0.2 (latest, for testing)

```hcl
# live/dev/services/webserver-cluster/main.tf
provider "aws" {
  region = "eu-north-1"
}

terraform {
  backend "s3" {
    bucket         = "sarahcodes-terraform-state-2026"
    key            = "day8/dev/services/webserver-cluster/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "sarahcodes-terraform-locks"
    encrypt        = true
  }
}

module "webserver_cluster" {
  source = "github.com/SarahWanjiru/terraform-aws-webserver-cluster?ref=v0.0.2"

  cluster_name  = "webservers-dev"
  instance_type = "t3.micro"
  min_size      = 2
  max_size      = 4
}

output "alb_dns_name" {
  value       = module.webserver_cluster.alb_dns_name
  description = "The DNS name of the dev load balancer"
}
```

### Production — pinned to v0.0.1 (validated stable)

```hcl
# live/production/services/webserver-cluster/main.tf
provider "aws" {
  region = "eu-north-1"
}

terraform {
  backend "s3" {
    bucket         = "sarahcodes-terraform-state-2026"
    key            = "day8/production/services/webserver-cluster/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "sarahcodes-terraform-locks"
    encrypt        = true
  }
}

module "webserver_cluster" {
  source = "github.com/SarahWanjiru/terraform-aws-webserver-cluster?ref=v0.0.1"

  cluster_name  = "webservers-production"
  instance_type = "t3.micro"
  min_size      = 2
  max_size      = 4
}

output "alb_dns_name" {
  value       = module.webserver_cluster.alb_dns_name
  description = "The DNS name of the production load balancer"
}
```

**Why pin production to an older version?** Production only moves to a new module version after it has been validated in dev. If something breaks in v0.0.2, production is unaffected. This is the standard promotion pattern: dev tests → staging validates → production promotes.

---

## terraform init Output

```
Initializing modules...
Downloading git::https://github.com/SarahWanjiru/terraform-aws-webserver-cluster?ref=v0.0.2 for webserver_cluster...
- webserver_cluster in .terraform/modules/webserver_cluster

Initializing the backend...
Successfully configured the backend "s3"!

Initializing provider plugins...
- Finding latest version of hashicorp/aws...
- Installing hashicorp/aws v5.x.x...

Terraform has been successfully initialized!
```

---

## Module README

See the full module README at: [`terraform-aws-webserver-cluster/README.md`](../../terraform-aws-webserver-cluster/README.md)

Reproduced here for submission completeness:

```markdown
# Webserver Cluster Module

Deploys a highly available web server cluster on AWS using an Auto Scaling Group behind
an Application Load Balancer. Instances run Apache httpd and serve a simple HTML page.
All resources are created in the default VPC. Security groups use inline blocks only —
do not mix with aws_security_group_rule resources when calling this module.

## Usage

module "webserver_cluster" {
  source = "github.com/SarahWanjiru/terraform-aws-webserver-cluster?ref=v0.0.2"

  cluster_name  = "webservers-dev"
  instance_type = "t3.micro"
  min_size      = 2
  max_size      = 4
}

## Inputs

| Variable      | Type   | Default                   | Required | Description                        |
|---------------|--------|---------------------------|----------|------------------------------------|
| cluster_name  | string | —                         | yes      | Name prefix for all resources      |
| instance_type | string | t3.micro                  | no       | EC2 instance type                  |
| min_size      | number | —                         | yes      | Minimum ASG instances              |
| max_size      | number | —                         | yes      | Maximum ASG instances              |
| server_port   | number | 80                        | no       | HTTP port for instances and ALB    |
| ami           | string | ami-0aaa636894689fa47     | no       | AMI ID (Amazon Linux 2023, eu-north-1) |
| region        | string | eu-north-1                | no       | AWS region                         |

## Outputs

| Output                | Description                                          |
|-----------------------|------------------------------------------------------|
| alb_dns_name          | DNS name of the load balancer                        |
| asg_name              | Name of the Auto Scaling Group                       |
| alb_arn               | ARN of the load balancer                             |
| alb_security_group_id | Security group ID of the ALB (added in v0.0.2)       |

## Known Limitations

- Deploys into the default VPC only — no custom VPC support yet
- AMI default is region-specific (eu-north-1); override `ami` when deploying elsewhere
- Do not mix inline security group blocks with aws_security_group_rule when calling this module
```

---

## Version Pinning Strategy

Referencing a module without a version pin — like `source = "github.com/org/module"` — always pulls the latest commit on the default branch. In a team environment this is dangerous:

- Engineer A runs `terraform plan` on Monday — module is at commit X
- Someone merges a breaking change to the module on Tuesday
- Engineer B runs `terraform apply` on Wednesday — pulls commit Y, applies different infrastructure

The two applies are now inconsistent. Resources get recreated or destroyed that weren't supposed to change. In production this means downtime.

Version pinning with `?ref=v0.0.1` locks every engineer and every CI run to the exact same code. The only way production changes is a deliberate decision to bump the pin.

---

## Most Dangerous Gotcha

**Gotcha 1 (file paths)** is the most dangerous in production. It fails silently in the worst way — `templatefile()` with a wrong path either errors at plan time (if you're lucky) or renders an empty user-data script (if you're not). Instances launch with no web server running, health checks fail, the ASG keeps replacing instances, and the ALB returns 502s. The root cause is non-obvious because the Terraform code looks correct — the path string is valid, it just resolves to the wrong place.

I didn't hit this specific one this week, but Gotcha 2 (inline vs separate rules) bit me on Day 8 when I tried adding a rule to the security group from the root module — Terraform kept showing a diff on every plan even though nothing had changed.

---

## Challenges and Fixes

- **terraform init caching**: After changing the `?ref=` tag, `terraform init` sometimes used the cached module. Fix: delete `.terraform/modules/` and re-run `terraform init`.
- **Git tag not pushed**: Tagged locally but forgot `--tags` on push. The `?ref=v0.0.1` source returned a 404 until I ran `git push origin main --tags`.
- **ALB name length limit**: AWS enforces a 32-character limit on ALB names. Long `cluster_name` values cause a cryptic API error. Kept names short as a workaround — a `substr` guard would be the proper fix.

---

## Blog Post

URL: *(paste blog URL here)*

Covered the three module gotchas with broken/fixed code examples, walked through the full versioning workflow from `git tag` to `?ref=` pinning, and explained the dev→production promotion pattern. Also compared local path, Git, and Terraform Registry source formats side by side.

---

## Social Media

URL: *(paste post URL here)*

> 🔄 Day 9 of the 30-Day Terraform Challenge — went deep on advanced Terraform modules today. Module versioning, file path gotchas, and deploying different module versions across dev and production. This is the pattern that keeps large infrastructure codebases manageable. #30DayTerraformChallenge #TerraformChallenge #Terraform #IaC #DevOps #AWSUserGroupKenya #EveOps
