TITLE (paste into Medium title field):
Preparing for the Terraform Associate Exam — Key Resources and Tips

SUBTITLE (paste into Medium subtitle field):
The CLI commands section is harder than most people expect. Day 23 — I audited every exam domain, found my gaps, and built a study plan. Here is everything.

---

BODY (paste everything below into Medium):

---

The book is done. The builds are running.

Now it is time to actually pass the exam.

Day 23 of my 30-Day Terraform Challenge is a full shift into exam prep mode. No new infrastructure today. Just an honest audit of where I am, where my gaps are, and a structured plan for the remaining days.

Here is everything — the domain audit, the CLI commands you need to know cold, the practice questions I wrote, and the one insight that changes how you study for this exam.


Prerequisites

- Basic understanding of Terraform
- Some hands-on experience with terraform plan, apply, and destroy

New to Terraform? Check the earlier posts in this series — links at the bottom.


The Exam Domains — My Honest Audit

The Terraform Associate exam covers nine domains. Here is where I stand after 22 days of hands-on work:

🟢 Green — confident, done hands-on
🟡 Yellow — understand conceptually, need more practice
🔴 Red — not confident

Understand IaC concepts (16%) — 🟢 Green
Built and explained IaC from Day 1. Declarative vs imperative, idempotency, state management — all solid.

Understand Terraform's purpose (20%) — 🟢 Green
Providers, state, plan/apply cycle — all hands-on across 22 days.

Understand Terraform basics (24%) — 🟡 Yellow
Variables, outputs, locals, count, for_each — solid. Workspace isolation vs directory isolation — needs review.

Use the Terraform CLI (26%) — 🟡 Yellow
Core commands solid. terraform state mv, terraform state rm, terraform taint — need hands-on practice.

Interact with Terraform modules (12%) — 🟢 Green
Built, versioned, and published modules. configuration_aliases, providers map — all done.

Navigate the core Terraform workflow (8%) — 🟢 Green
Seven-step workflow executed end-to-end on Days 20-21.

Implement and maintain state (8%) — 🟡 Yellow
S3 backend, DynamoDB locking, terraform import — solid. State commands and workspace state paths — need practice.

Read, generate, and modify configuration (8%) — 🟢 Green
count, for_each, conditionals, locals, dynamic blocks — all hands-on.

Understand Terraform Cloud capabilities (4%) — 🟡 Yellow
Sentinel and cost estimation written. Remote runs vs local runs — needs review.

Summary: 5 Green, 4 Yellow, 0 Red. The CLI commands domain is the highest-weighted yellow — 26% of the exam.


The CLI Commands Section Is Harder Than You Think

Most people study the big commands — plan, apply, destroy. The exam goes deeper.

It asks scenario questions like:

"You run terraform state rm aws_s3_bucket.logs. What happens to the actual S3 bucket in AWS?"

The answer is: nothing. The bucket still exists. terraform state rm only removes the resource from the state file. It makes no API calls to AWS.

That distinction — state is not infrastructure — is the most important concept for the CLI section.

Here are the 15 commands you need to know cold:

terraform init — downloads providers, configures backend. Run when you first clone a repo or change the backend.

terraform validate — checks syntax without AWS calls. Use in CI to catch errors before plan.

terraform fmt — reformats .tf files to canonical style. Use with -check in CI to fail on unformatted files.

terraform plan — generates a diff against state. Always save with -out=plan.tfplan in production.

terraform apply — creates or updates infrastructure. Always apply from a saved plan file.

terraform destroy — removes all managed resources. Always run terraform plan -destroy first.

terraform output — reads output values from state without running a plan.

terraform state list — lists all resources in state. Use before running other state commands.

terraform state show — shows all attributes of a specific resource in state.

terraform state mv — moves a resource within state. Use when refactoring without wanting to destroy and recreate.

terraform state rm — removes a resource from state without destroying it. Use when handing a resource to another team.

terraform import — adds an existing resource to state. Use when bringing manually-created infrastructure under Terraform management.

terraform taint — deprecated. Use terraform apply -replace=resource.name instead.

terraform workspace — creates, selects, lists workspaces. Each workspace has its own state file.

terraform providers — shows all providers required by the configuration.

terraform login — authenticates to Terraform Cloud.

terraform graph — outputs the dependency graph in DOT format.


Non-Cloud Providers

Terraform manages more than just cloud resources. The random and local providers appear frequently in exam questions.

resource "random_id" "suffix" {
  byte_length = 4
}

resource "random_password" "db" {
  length  = 16
  special = true
}

resource "local_file" "config" {
  content  = "cluster_suffix = ${random_id.suffix.hex}"
  filename = "${path.module}/generated-config.txt"
}

random_id — used in Day 12 to generate unique ASG names so old and new ASGs can coexist during create_before_destroy. Without it, two ASGs with the same name would conflict.

random_password — generates secure passwords for database bootstrapping without hardcoding them in .tf files.

local_file — generates configuration files as part of a terraform apply. Useful when downstream tools need a file that references Terraform-managed resources.


Five Practice Questions I Wrote

Writing your own questions is one of the most effective study techniques. It forces you to understand the material well enough to construct a plausible wrong answer.

Question 1

You run terraform state rm aws_s3_bucket.logs. What happens to the actual S3 bucket?

A) The bucket is deleted from AWS
B) The bucket is moved to a different state file
C) Nothing — the bucket still exists but Terraform no longer tracks it
D) The bucket is marked for deletion on the next apply

Answer: C. terraform state rm only removes the resource from state. No API calls. The real bucket continues to exist.

Question 2

A team member manually deleted an EC2 instance that Terraform manages. What does terraform plan show?

A) No changes
B) The instance will be destroyed
C) The instance will be created
D) An error

Answer: C. Terraform detects the drift — state says the instance exists, AWS says it does not. Plan shows it as a resource to create.

Question 3

What is the difference between terraform workspace new staging and creating a live/staging/ directory?

A) Workspaces are faster to create
B) Workspaces share configuration files but maintain separate state; directory isolation uses separate configuration files
C) Directory isolation is deprecated
D) No difference

Answer: B. Workspaces use the same .tf files with separate state. Directory isolation uses completely separate configuration files. The book recommends directory isolation for production because differences between environments are explicit in code.

Question 4

You have count = var.enable_feature ? 1 : 0 and try to output value = aws_resource.example.arn when enable_feature = false. What happens?

A) Output returns null
B) Output returns empty string
C) Terraform errors at plan time
D) Output is skipped automatically

Answer: C. When count = 0, the resource does not exist. Referencing it without index notation causes a plan-time error. Correct pattern: value = var.enable_feature ? aws_resource.example[0].arn : null

Question 5

What does terraform apply -replace=aws_instance.web do?

A) Removes the instance from state without destroying it
B) Forces the instance to be destroyed and recreated even if no configuration changes
C) Imports the instance into state
D) Marks the instance as tainted for the next apply

Answer: B. -replace forces destroy and recreate regardless of configuration changes. This is the modern replacement for the deprecated terraform taint command.


The One Insight That Changes How You Study

State is not infrastructure.

State is Terraform's record of what it thinks exists. Real infrastructure is what actually exists in AWS. These can diverge.

Every state command operates on the record, not on the real infrastructure — except terraform apply and terraform destroy.

Once that distinction is clear, the CLI section becomes much easier. Every scenario question about state commands becomes: "does this command touch real infrastructure or just the record?"

terraform state rm — touches only the record
terraform state mv — touches only the record
terraform import — touches only the record (adds to it)
terraform apply — touches real infrastructure
terraform destroy — touches real infrastructure


Key Lessons Learned

- The CLI commands section is 26% of the exam — the highest-weighted domain
- State is not infrastructure — every state command operates on the record, not AWS
- terraform state rm does not delete real resources — it only removes them from tracking
- Workspace isolation and directory isolation are different patterns with different tradeoffs
- Writing your own practice questions is more effective than reading docs
- The official sample questions are the best proxy for exam difficulty — do them first


One question before you go:

Which CLI command do you find most confusing — terraform state mv, terraform import, or terraform taint? And why?

Drop it in the comments. I am building a list of the most commonly misunderstood commands to cover in the next post.

If this post helped you, clap so more engineers find it before their exam.

Follow me here on Medium — the challenge posts keep coming.

I am currently doing the 30-Day Terraform Challenge while building Cloud and DevOps skills in public. Open to opportunities — using this time to build real-world skills by actually doing and breaking things.

I am Sarah Wanjiru — a frontend developer turned cloud and DevOps engineer, sharing every step of the transition in public. The mistakes. The fixes. The moments things finally click. Follow along if that sounds useful. 🤝💫

#30DayTerraformChallenge #TerraformChallenge #Terraform #TerraformAssociate #CertificationPrep #AWSUserGroupKenya #EveOps #WomenInTech #BuildInPublic #CloudComputing #AWS #Andela
DevOps
Terraform
AWS
Infrastructure As Code
Buildinginpublic
