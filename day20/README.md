# Day 20: Workflow for Deploying Application Code

## What I Did Today

Mapped the seven-step application deployment workflow to Terraform, simulated all seven
steps end-to-end, set up Terraform Cloud, explored Sentinel policies and the private
registry, and documented where the workflows align and diverge.

---

## Project Structure

```
day20/
├── modules/services/webserver-cluster/   # production-grade module with IMDSv2
└── live/dev/services/webserver-cluster/  # calling config — app_version = "v3"
```

---

## Seven-Step Walkthrough

### Step 1 — Version Control

Code lives in the `30daysof-TerraformChallenge` GitHub repository. Main branch is
protected — no direct pushes, only merges via pull request.

Key difference: the state file is NOT in Git. It lives in encrypted S3. Committing
state exposes sensitive resource attributes and causes conflicts when multiple engineers
apply simultaneously.

---

### Step 2 — Run Locally

Changed `app_version = "v3"` in the module call. Ran plan and saved it:

```bash
terraform plan -out=day20.tfplan
```

---

### Step 3 — Feature Branch

```bash
git checkout -b update-app-version-day20
git add day20/
git commit -m "feat(day20): update app response to v3 and simulate seven-step deployment workflow"
git push origin update-app-version-day20
```

---

### Step 4 — Pull Request

Opened PR with plan output pasted in the description — the infrastructure equivalent
of a code diff. Reviewer sees what AWS resources will change without running Terraform.

During review, CodeRabbit identified two valid findings:
- Missing `crash.log` in `.gitignore` — fixed
- No IMDSv2 enforcement on launch template — fixed by adding `metadata_options` block

---

### Step 5 — Automated Tests

```
✅ Terraform CI / Validate and Plan    — Successful in 34s
✅ Terraform Tests / Unit Tests        — Successful in 35s
✅ Terraform Tests / Validate and Plan — Successful in 27s
⏭️ Terraform Tests / Integration Tests — Skipped (PR only)
```

---

### Step 6 — Merge and Release

```bash
git tag -a "v1.3.0" -m "Update app response to v3 for Day 20"
git push origin v1.3.0
```

```
* [new tag] v1.3.0 -> v1.3.0
```

After merge, integration tests triggered automatically on main.

---

### Step 7 — Deploy

```bash
terraform apply "day20.tfplan"
```

```
Apply complete! Resources: 11 added, 0 changed, 0 destroyed.

Outputs:

alb_dns_name       = "webservers-dev-alb-180723400.eu-north-1.elb.amazonaws.com"
instance_type_used = "t3.micro"
sns_topic_arn      = "arn:aws:sns:eu-north-1:629836545449:webservers-dev-alerts"
```

```bash
curl -s http://webservers-dev-alb-180723400.eu-north-1.elb.amazonaws.com
<h1>Hello from webservers-dev — v3 — ip-172-31-7-216.eu-north-1.compute.internal</h1>
```

---

## Terraform Plan Output

Full plan from Step 2 — saved to `day20.tfplan`:

```
Plan: 11 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + alb_dns_name       = (known after apply)
  + instance_type_used = "t3.micro"
  + sns_topic_arn      = (known after apply)

Saved the plan to: day20.tfplan
```

Confirmed exactly what was intended — 11 new resources, v3 in user data, t3.micro
instance type. Nothing unexpected. Safe to proceed.

Note: `*.tfplan` added to `.gitignore` — plan files contain sensitive resource details
and must never be committed to Git.

---

## Terraform Cloud Setup

```hcl
terraform {
  cloud {
    organization = "sarahcodes"

    workspaces {
      name = "webserver-cluster-dev"
    }
  }
}
```

Run `terraform login` to authenticate, then `terraform init` to migrate state.

**What Terraform Cloud provides over S3 backend:**
- Stores every plan — reviewers see it in the UI without running Terraform
- Runs `terraform apply` in a locked, trusted environment — not on a developer's laptop
- Manages AWS credentials centrally — no keys on any developer's machine
- Full audit log of every plan and apply with who triggered it
- Team access control without managing IAM policies

---

## Variable Configuration

| Variable | Type | Sensitive | Why |
|---|---|---|---|
| `AWS_ACCESS_KEY_ID` | Environment | ✅ Yes | AWS credential — never in .tf files or CI logs |
| `AWS_SECRET_ACCESS_KEY` | Environment | ✅ Yes | AWS credential — never in .tf files or CI logs |
| `cluster_name` | Terraform | No | Not sensitive |
| `instance_type` | Terraform | No | Not sensitive |
| `environment` | Terraform | No | Not sensitive |
| `db_secret_name` | Terraform | No | Points to Secrets Manager path, not the secret value |

**Why sensitive variables must never appear in .tf files or CI logs:**

Anyone with read access to the repository can see `.tf` files. Anyone with access to
GitHub Actions logs can see CI output. Terraform Cloud encrypts sensitive variables at
rest and never displays them in plan output, apply logs, or the UI. The value is
injected into the run environment at execution time and immediately discarded.

---

## Sentinel Policies Lab Takeaway

Sentinel is Terraform Cloud's policy-as-code framework. Rules are enforced before
every `terraform apply` — not after.

Example — require Environment tag on all resources:

```python
import "tfplan/v2" as tfplan

main = rule {
  all tfplan.resource_changes as _, changes {
    changes.change.after.tags["Environment"] is not null
  }
}
```

If any resource in the plan is missing the `Environment` tag, the apply is blocked
before it runs. No human needs to review every plan manually.

**What Sentinel provides that GitHub Actions cannot:**
- Policies enforced server-side — engineers cannot bypass them
- Apply to all workspaces in the organisation automatically
- Policy violations block apply, not just warn
- Audit log of every policy evaluation

---

## Private Registry

The webserver cluster module is published at:
`https://github.com/SarahWanjiru/terraform-aws-webserver-cluster`

Steps to publish to Terraform Cloud private registry:
1. Repository already follows naming convention: `terraform-aws-webserver-cluster` (`terraform-<provider>-<name>`)
2. Tag a release:
```bash
cd ~/Desktop/terraform-aws-webserver-cluster
git tag v1.0.0
git push origin v1.0.0
```
3. Terraform Cloud: Registry → Publish → Module → connect `SarahWanjiru/terraform-aws-webserver-cluster`

Once published, teams reference it like any public module:

```hcl
module "webserver_cluster" {
  source  = "app.terraform.io/sarahcodes/webserver-cluster/aws"
  version = "1.0.0"

  cluster_name  = "prod-cluster"
  instance_type = "t3.small"
  min_size      = 3
  max_size      = 10
  environment   = "production"
}
```

The module source URL format is: `app.terraform.io/<org>/<module-name>/<provider>`

Note: Publishing was attempted during the challenge but blocked by a browser popup
blocker on the GitHub App connection step. The repository, naming convention, and
version tag are all correctly set up. The registry connection is the final step.

**Private registry vs GitHub URL directly:**

| | GitHub URL | Private Registry |
|---|---|---|
| Version pinning | Manual `?ref=` tag | Semantic `version =` |
| Documentation | README only | Auto-generated from variables/outputs |
| Discovery | Must know the repo URL | Searchable in Terraform Cloud UI |
| Access control | GitHub permissions | Terraform Cloud team permissions |
| Usage tracking | None | Shows which workspaces use which version |

---

## Workflow Comparison Table

| Step | Application Code | Infrastructure Code | Key Difference |
|---|---|---|---|
| 1. Version control | Git for source code | Git for .tf files | State file is NOT in Git |
| 2. Run locally | `npm start` | `terraform plan` | Plan shows what will change, not a running app |
| 3. Make changes | Edit source files | Edit .tf files | Changes affect real cloud resources |
| 4. Review | Code diff in PR | Plan output in PR | Reviewer must understand cloud resource implications |
| 5. Automated tests | Unit tests, linting | `terraform test`, Terratest | Infra tests deploy real resources and cost money |
| 6. Merge and release | Merge + tag | Merge + tag | Module consumers must pin to versions explicitly |
| 7. Deploy | CI/CD pipeline | `terraform apply` | Apply must run from a trusted, locked environment |

**Biggest difference — Step 5:**

Application unit tests run in milliseconds and cost nothing. Terraform integration
tests deploy real AWS infrastructure, take 5-15 minutes, and cost money. You cannot
run integration tests on every commit the way you run unit tests.

---

## Chapter 10 Learnings

The seven-step workflow exists because deploying application code without it causes
incidents. The same is true for infrastructure code — but the consequences are worse.
A bad application deploy might break a feature. A bad `terraform apply` might destroy
a production database.

**What breaks when teams skip steps:**

- Skip Step 2 — apply a plan you have not reviewed. Surprises in production.
- Skip Step 4 — no second pair of eyes catches mistakes before they reach AWS.
- Skip Step 5 — regressions reach production undetected.
- Skip Step 6 — no way to roll back to a known good version.
- Skip Step 7 discipline — the plan you reviewed is not the plan you applied.

---

## Challenges and Fixes

**Missing crash.log in .gitignore:**
Adding `*.tfplan` accidentally removed `crash.log`. CodeRabbit caught it. Fixed by
restoring `crash.log` alongside `crash.*.log`.

**No IMDSv2 on launch template:**
Launch template had no `metadata_options` block — instances vulnerable to SSRF via
IMDSv1. Fixed:

```hcl
metadata_options {
  http_endpoint               = "enabled"
  http_tokens                 = "required"
  http_put_response_hop_limit = 1
}
```

**SNS topic encryption suggestion:**
CodeRabbit suggested KMS encryption for SNS. Declined — adds $1/month per key and
complexity for lab infrastructure. Known gap for real production.

**day20.tfplan accidentally staged:**
`git add .` from inside the live directory staged the plan file. Fixed by unstaging
and adding `*.tfplan` to `.gitignore`.

---

## Blog Post

URL: *(paste blog URL here)*

---

## Social Media

URL: *(paste post URL here)*

> 🚀 Day 20 of the 30-Day Terraform Challenge — application deployment workflow mapped
> to Terraform. Seven steps from local change to production, Terraform Cloud for state
> and variable management, private registry for internal module sharing. Infrastructure
> as Code done properly looks exactly like good software engineering.
> #30DayTerraformChallenge #TerraformChallenge #Terraform #TerraformCloud #DevOps #IaC
> #AWSUserGroupKenya #EveOps
