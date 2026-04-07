# Day 19: Adopting Infrastructure as Code in Your Team

## What I Did Today

Shifted from technical implementation to strategy. Read Chapter 10 on IaC adoption,
reflected honestly on a real client project I am working on, and built a concrete
four-phase adoption plan. Also practised terraform import by bringing the existing
S3 state bucket and DynamoDB lock table under Terraform management — and hit the
exact drift problem the book warns about.

---

## Project Structure

```
day19/
├── import-practice/
│   └── main.tf    # terraform import practice — existing state bucket + DynamoDB table
└── README.md
```

---

## Current State Assessment

This assessment is based on a real client project — a SaaS platform I am currently
migrating from Render to AWS.

### How is infrastructure currently provisioned?

Entirely manual. The application and AI engine both run on Render, configured through
the Render web console. There is no infrastructure code. No version control for
infrastructure. No audit trail of what changed and when.

External services (database, auth, payments, monitoring) are configured through their
respective dashboards. API keys live in a `.env.local` file on the developer's machine.

**IaC Maturity Level: 0** — everything manual, no infrastructure code exists.

### How many people are involved in infrastructure changes?

Currently one person — the lead developer. There is no approval process. Changes happen
directly in the Render console or by updating the `.env.local` file.

### How often do infrastructure changes cause incidents?

The most significant known issue is architectural: the application uses JavaScript `Map`
objects to store job state in server memory. This works on Render's single-instance
setup but will break completely on AWS where multiple instances run simultaneously.
Job results will randomly disappear for users unless this is fixed before migration.

### Is there drift between documented and actual infrastructure?

Yes. The architecture documentation describes the intended design but the actual
configuration has never been codified. There is no way to recreate the exact current
setup from documentation alone.

### Are secrets managed properly?

No. All credentials live in a `.env.local` file on the developer's machine. This file
is not committed to Git (correctly) but it exists only on one machine. There is no
rotation policy, no audit log of access, and no way to give the production server its
credentials without manually copying the file.

### Team readiness

- Strong version control discipline for application code — Git, PRs, code review
- Zero experience with infrastructure as code
- No existing Terraform knowledge
- Client is open to migration — they understand the current setup has limitations
- They need to see results quickly to maintain confidence

---

## Four-Phase IaC Adoption Plan

### Phase 1 — Start with something new (Weeks 1–2)

**What gets done:**
Provision the Terraform state infrastructure itself — the S3 bucket and DynamoDB table
that all future Terraform state will live in. Create the `client-infra` repository with
the initial module structure, remote backend configuration, and CI pipeline.

**Why start here:**
Zero migration risk. We are not touching any existing infrastructure. If anything goes
wrong, nothing breaks for users. This creates the first success story.

**Who does it:**
Infrastructure engineer. Client reviews and approves the PR.

**Success criteria:**
- `terraform apply` creates the S3 bucket and DynamoDB table
- `terraform plan` returns "No changes" on second run
- Client can read the Terraform code and understand what it creates
- PR merged via GitHub with code review
- Team members can run `terraform plan` and understand the output

**Approximate time:** 3–5 days

---

### Phase 2 — Import existing infrastructure (Weeks 3–4)

**What gets done:**
Use `terraform import` to bring existing resources under Terraform management without
recreating them. Write Terraform configurations for Secrets Manager secrets, Route 53
hosted zone, ECR repositories, and IAM roles — then import the ones that already exist.

Also complete critical code fixes required before deployment:
- Replace in-memory `Map` objects with Redis calls
- Add `output: "standalone"` to Next.js config
- Create `Dockerfile` for the application
- Create GitHub Actions deployment workflow

**Who does it:**
Infrastructure engineer writes the Terraform. Application developer makes the code fixes.

**Success criteria:**
- `terraform plan` shows no changes for all imported resources
- Code fixes reviewed and merged
- Docker build succeeds locally

**Approximate time:** 1–2 weeks

---

### Phase 3 — Establish team practices (Weeks 5–6)

**What gets done:**
Deploy the full dev environment on AWS. This is the first real deployment.

Establish the practices that prevent chaos as more people get involved:
- All infrastructure changes via PR — no direct console changes ever
- `terraform plan` output required in every PR description
- `terraform fmt` and `terraform validate` run automatically in CI
- State locking enforced via DynamoDB
- Module versioning for reusable components
- No manual console changes to Terraform-managed resources — ever

**Who does it:**
Infrastructure engineer deploys. Client and developer review the plan output before
every apply.

**Success criteria:**
- `dev.<client-domain>.com` serves the application from AWS
- Core features work end-to-end
- Client can see the infrastructure in the AWS console and understand what they are looking at

**Approximate time:** 1–2 weeks

---

### Phase 4 — Automate deployments and go live (Weeks 7–8)

**What gets done:**
Deploy production environment. Connect GitHub Actions so merges to `main` automatically
build, push to ECR, and deploy to App Runner. Infrastructure changes go through PR
review and `terraform apply` runs automatically on merge.

Set up CloudWatch alerts for error rate spikes and cost budget alerts.

**Who does it:**
Infrastructure engineer. Client approves the production deployment.

**Success criteria:**
- `<client-domain>.com` serves the live application from AWS
- A code push to `main` deploys automatically within 5 minutes
- CloudWatch shows logs from all services
- Budget alert is configured
- Render services are decommissioned

**Approximate time:** 1–2 weeks

---

## The Business Case Table

| Business Problem | IaC Solution | Measurable Outcome |
|---|---|---|
| Job results randomly disappear because state is lost between server instances | Redis replaces in-memory Maps — all instances share one store | Feature reliability goes from ~60% to 100% |
| API keys live on one developer's machine — if lost, production breaks | AWS Secrets Manager stores all credentials centrally | Zero single point of failure for credentials |
| No audit trail of infrastructure changes | Every change is a Git commit with author, timestamp, and PR review | Full audit trail for compliance and debugging |
| Dev environment does not exist — testing happens on production | Separate dev and production environments with identical Terraform configs | Zero risk of test data touching real users |
| Current host goes to sleep after inactivity — users experience slow cold starts | App Runner keeps minimum 1 instance always running | Cold start eliminated, consistent response times |
| No way to roll back a bad deployment | ECR stores last 10 container versions — rollback is one command | Mean time to recovery drops from hours to minutes |
| Infrastructure cannot be recreated if something goes wrong | Entire infrastructure defined in Terraform — recreate with one apply | Disaster recovery time from days to under 1 hour |
| Hours spent on repetitive environment setup | Reusable modules provision environments in minutes | Engineering time freed for product work |

**Estimated numbers:**
- Time to provision a new environment manually: 2–3 hours → with Terraform: under 10 minutes
- Time to onboard a new developer to infrastructure: 1 day → with documented Terraform code: under 2 hours
- Monthly infrastructure cost: $0 (current free tier) → $XXX/month on AWS (confirmed from AWS Pricing Calculator)

---

## terraform import Practice

The S3 state bucket and DynamoDB lock table were created manually on Day 6.
Today they are brought under Terraform management without recreating them.

### Step 1 — Write the resource blocks

```hcl
resource "aws_s3_bucket" "state_bucket" {
  bucket = "<your-state-bucket-name>"

  tags = {
    Name        = "<your-state-bucket-name>"
    ManagedBy   = "terraform"
    Environment = "production"
    Project     = "30day-terraform-challenge"
    Owner       = "<your-name>"
  }
}

resource "aws_dynamodb_table" "state_locks" {
  name         = "<your-lock-table-name>"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "<your-lock-table-name>"
    ManagedBy   = "terraform"
    Environment = "production"
    Project     = "30day-terraform-challenge"
    Owner       = "<your-name>"
  }
}
```

### Step 2 — Run the import commands

```bash
terraform import aws_s3_bucket.state_bucket <your-state-bucket-name>
terraform import aws_dynamodb_table.state_locks <your-lock-table-name>
```

**Import output:**

```
aws_s3_bucket.state_bucket: Importing from ID "<your-state-bucket-name>"...
aws_s3_bucket.state_bucket: Import prepared!
  Prepared aws_s3_bucket for import
aws_s3_bucket.state_bucket: Refreshing state...

Import successful!

aws_dynamodb_table.state_locks: Importing from ID "<your-lock-table-name>"...
aws_dynamodb_table.state_locks: Import prepared!
  Prepared aws_dynamodb_table for import
aws_dynamodb_table.state_locks: Refreshing state...

Import successful!
```

### Step 3 — terraform plan revealed drift

This is the exact problem the book warns about. The plan showed `0 to add, 2 to change,
0 to destroy` — not "No changes" as expected.

```
~ tags = {
    + "Environment" = "production"
    + "ManagedBy"   = "terraform"
    ~ "Name"        = "Sarahcodes-Terraform-State" -> "<your-state-bucket-name>"
    + "Owner"       = "<your-name>"
    + "Project"     = "30day-terraform-challenge"
  }
```

The existing resources had different tag values — the Name tag used title case
(`"Sarahcodes-Terraform-State"`) instead of the lowercase value in the configuration.
The `Environment`, `Owner`, and `Project` tags were missing entirely.

This is drift — the actual resource does not match the configuration. `terraform import`
revealed it. Running `terraform apply` fixed it by updating the tags to match.

### Step 4 — After apply, plan shows No changes

```
No changes. Your infrastructure matches the configuration.

Terraform has compared your real infrastructure against your configuration
and found no differences, so no changes are needed.
```

**What terraform import does:**
Adds the existing resource to `terraform.tfstate` so Terraform can track it going
forward. It does NOT write the `.tf` configuration — you must write that yourself.

**What terraform import does NOT do:**
It does not modify the actual resource. It does not generate the configuration file.
If your resource block does not match the actual resource, `terraform plan` will show
changes — which could modify or destroy the resource on the next apply. Always verify
with `terraform plan` after import before running `terraform apply`.

---

## Terraform Cloud Lab Takeaways

**What Terraform Cloud provides that a plain S3 backend does not:**

| Feature | S3 Backend | Terraform Cloud |
|---|---|---|
| State storage | S3 bucket | Terraform Cloud managed |
| State locking | DynamoDB table (separate resource) | Built in, no extra setup |
| Plan/apply UI | Terminal only | Web UI with full history |
| Team access control | IAM policies | Role-based access in the UI |
| Sentinel policies | Not available | Policy as code — enforce rules before apply |
| Remote execution | Local machine or CI | Runs in Terraform Cloud's infrastructure |
| Cost estimation | Not available | Built in for supported providers |
| VCS integration | Manual CI setup | Native GitHub/GitLab integration |

For the client project, the S3 backend is the right choice at this stage — simpler,
cheaper, and gives full control. Terraform Cloud becomes worth considering when the
team grows beyond 3-4 engineers and managing IAM policies for state access becomes
significant overhead.

---

## Chapter 10 Learnings

**The most common reason IaC adoption fails:**

The author identifies trying to migrate everything at once as the primary failure mode.
Teams see the value of IaC, get excited, and immediately try to import their entire
existing infrastructure into Terraform in one sprint. This creates a massive amount of
work, breaks things that were working, and demoralises the team before they have had
a chance to build confidence with the tool.

The second failure mode is underestimating the cultural change. IaC is not just a
technical tool — it changes how infrastructure decisions are made, reviewed, and
deployed. Engineers who are used to making quick console changes resist the slower
PR-based workflow. Getting buy-in before starting is as important as the technical work.

**Do I agree?**

Yes — and the terraform import exercise today proved it. Even importing two simple
resources revealed drift that required investigation and a fix. Imagine trying to import
hundreds of resources at once. The cognitive load would be overwhelming.

**What I would add:**

The author does not emphasise enough the importance of making the first success visible
early. The moment the client sees their application deployed automatically from a Git
push is the moment they trust the process. That visible win needs to happen as early
as possible — it is more valuable than a perfect plan.

---

## Challenges

**Hardest part of IaC adoption for this client:**

The hardest part is not technical — it is explaining why code that works perfectly on
the current host will silently break on AWS. The in-memory state problem requires the
developer to understand multi-instance deployments — a concept they have never needed
to think about before. This is a code change that must happen before the migration can
succeed, and it requires buy-in from the developer, not just the client.

The second hardest part is secrets management. Moving from a local config file to a
managed secrets service means changing how the application reads its configuration at
startup. This touches both infrastructure and application code.

The third hardest part is patience. The incremental approach feels slow. The temptation
to migrate everything at once is real. Resisting that temptation is what makes the
migration succeed.

**The terraform import drift finding:**

The plan showed tag differences after import — the existing resources had different
tag casing and missing tags. This is a real-world example of infrastructure drift.
The resources existed and worked, but they were not configured consistently. Import
revealed the drift. Terraform fixed it.

---

## Blog Post

URL: *(paste blog URL here)*

Title: **How to Convince Your Team to Adopt Infrastructure as Code**

---

## Social Media

URL: *(paste post URL here)*

> 🚀 Day 19 of the 30-Day Terraform Challenge — IaC adoption strategy. The technical
> part of Terraform is the easy part. Convincing a team to change how they work, building
> trust in automated deployments, migrating existing infrastructure incrementally — that
> is where the real challenge is. #30DayTerraformChallenge #TerraformChallenge #Terraform
> #IaC #DevOps #PlatformEngineering #AWSUserGroupKenya #EveOps
