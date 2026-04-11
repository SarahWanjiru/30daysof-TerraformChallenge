TITLE (paste into Medium title field):
My Final Preparation for the Terraform Associate Exam

SUBTITLE (paste into Medium subtitle field):
I scored 121/200 on a real knowledge assessment — Established range, better than 66% of learners. Here is exactly what my gaps are, how I am closing them, and the five traps that catch most people.

---

BODY (paste everything below into Medium):

---

No new infrastructure today.

Day 24 of my 30-Day Terraform Challenge is pure exam prep. A 60-minute simulation under real conditions. Drilling the four highest-weight domains. Building the strategy I will use on exam day.

I scored 121 out of 200 on a real knowledge assessment.

That puts me in the Established range — better than 66% of assessed learners.

Not Advanced yet. But Established after 23 days of hands-on work, starting from zero.

Here is exactly what I got wrong, what I learned from it, and the specific traps that catch most people.


Prerequisites

- Days 1–23 of this series
- The official Terraform Associate Study Guide open in another tab

New to Terraform? Check the earlier posts in this series — links at the bottom.


The Assessment — 121/200, Established Range

This was a real knowledge assessment covering all Terraform Associate exam domains.

Score: 121/200 — Established range, better than 66% of assessed learners.

Not Advanced. But Established after 23 days of hands-on work starting from zero.

The domains where I was weakest:

1. What does terraform plan -target=module.vpc do to resources outside the target?
2. Where does Terraform store workspace state in S3 when using the S3 backend?
3. What is the difference between terraform refresh and terraform apply -refresh-only?
4. What happens to a resource when you run terraform state mv to a new address?
5. When does Sentinel run in the Terraform Cloud workflow?
6. What does terraform output -json return when there are no outputs defined?

All six are CLI or Terraform Cloud questions — the two domains I rated yellow in yesterday's audit. The audit was accurate.


The Most Important Insight for the Exam

State is not infrastructure.

Every CLI question becomes easier once this is clear.

terraform state rm — removes from state only. Real resource untouched.
terraform import — adds to state only. Does not generate .tf configuration.
terraform state mv — moves within state only. Real resource untouched.
terraform apply — touches real infrastructure AND updates state.
terraform destroy — touches real infrastructure AND removes from state.

On any CLI question, ask: "does this command touch real infrastructure or just the state file?" That question eliminates wrong answers fast.


The Five Exam Traps That Catch Most People

Trap 1 — terraform destroy vs terraform state rm

Both "remove" a resource. The difference: terraform destroy removes the real resource from AWS AND removes it from state. terraform state rm removes it from state only — the real resource continues to exist.

Trap 2 — sensitive = true does not encrypt state

Marking a variable as sensitive = true hides the value from terminal output. It does NOT encrypt the state file. The value is still stored in plaintext in terraform.tfstate. The state file must be encrypted separately via the S3 backend with encrypt = true.

Trap 3 — Module source pinning: branch vs tag

source = "github.com/org/module?ref=main" looks pinned. It is not. main is a branch — it changes every time someone pushes. ?ref=v1.0.0 is a tag — it is immutable. The exam tests whether you know the difference.

Trap 4 — terraform workspace new switches automatically

You might think you need terraform workspace new staging then terraform workspace select staging. You do not. new creates AND switches in one command.

Trap 5 — terraform import does not generate configuration

terraform import adds the resource to state. It does NOT write the .tf resource block. You must write it yourself. If you run terraform plan after import without writing the block, Terraform will plan to destroy the resource.


The Flash Card Questions — Test Yourself

Before reading the answers, try each one:

What file does terraform init create to record provider versions?
.terraform.lock.hcl — records exact provider version and cryptographic hashes. Commit it to Git.

What is the difference between terraform.workspace and a Terraform Cloud workspace?
terraform.workspace is a built-in variable returning the current workspace name. A Terraform Cloud workspace is a named environment with its own state, variables, and run history.

If you run terraform state rm aws_instance.web, what happens to the EC2 instance?
Nothing. It continues to exist in AWS. Terraform stops tracking it.

What does depends_on do and when should you use it?
Creates an explicit dependency. Use it when Terraform cannot automatically detect the dependency — when a resource depends on side effects rather than output values.

How does for_each differ from count when items are removed from the middle of a collection?
count addresses by index — removing from the middle renumbers everything and causes unexpected recreations. for_each addresses by key — removing one item only affects that item.

What does terraform apply -refresh-only do?
Updates state to match real infrastructure without making any changes. Modern replacement for the deprecated terraform refresh.

What does prevent_destroy do and what does it NOT prevent?
Blocks Terraform-initiated destruction. Does NOT prevent manual deletion in the AWS console. Does NOT prevent terraform state rm.


The Four High-Weight Domains — What I Drilled

Terraform Basics (24%)

terraform.tfstate.backup is created automatically before every apply. It contains the previous state. If an apply corrupts the current state file, restore from the backup.

Data sources read existing infrastructure — they do not create anything. data "aws_vpc" "default" reads an existing VPC. resource "aws_vpc" "new" creates a new one.

terraform refresh is deprecated. Use terraform apply -refresh-only instead. The difference: -refresh-only shows you what changed before committing — safer because you can review the diff.

Terraform CLI (26%)

terraform workspace new staging creates AND switches in one command.

terraform state rm removes from state only. terraform destroy removes from state AND from AWS.

terraform import adds to state but does NOT generate .tf configuration. You write the resource block yourself.

IaC Concepts (16%)

Idempotency: applying the same configuration twice produces the same result. Second apply should show "No changes."

Configuration drift: the gap between declared state and actual state. Happens when someone makes a manual change in the console.

Immutable infrastructure: replace rather than modify. create_before_destroy is the Terraform implementation.

Terraform's Purpose (20%)

Terraform Cloud is SaaS. Terraform Enterprise is self-hosted. Both provide remote state, Sentinel, and team access control. Enterprise adds SSO and clustering.

The state file maps configuration to real resources. Without state, Terraform cannot know which real resource corresponds to which resource block.

Terraform is provider-agnostic — AWS, Azure, GCP, Kubernetes, GitHub, Datadog — all managed with the same HCL syntax.


My Exam-Day Strategy

- Maximum 90 seconds on any single question before flagging and moving on
- Answer every question — no penalty for wrong answers, never leave one blank
- On multi-select questions, read "select TWO" carefully — selecting one or three marks the whole question wrong
- Eliminate clearly wrong answers first — most questions have at least one obviously wrong choice
- Watch for "NOT" and "EXCEPT" in question stems — easy to miss under time pressure
- For state questions: "does this command touch real infrastructure or just the state file?"
- For sensitive = true questions: "does this encrypt state or just hide terminal output?"
- Flag and return — complete all questions first, then revisit flagged ones


The Resources That Actually Helped

Official Terraform Associate Study Guide — the authoritative source. Every topic listed there is fair game.

Official Sample Questions — the best proxy for exam difficulty. Do these before anything else.

The hands-on work from Days 1–22 — 22 days of building real infrastructure is worth more than any study guide. When the exam asks "what happens when you run terraform state rm?", I know the answer because I ran it on Day 19 and watched what happened.

That last point is the most important one. The exam rewards people who have actually done the work, not just read about it.


Key Lessons Learned

- State is not infrastructure — every CLI question becomes easier with this distinction
- The CLI domain is 26% of the exam — the highest-weighted domain, do not underestimate it
- sensitive = true hides terminal output, it does not encrypt state
- terraform import adds to state but does not generate configuration
- for_each is safer than count for collections that might change
- The official sample questions are the best proxy for exam difficulty
- 22 days of hands-on work is the best exam preparation


One question before you go:

Which of the five traps above did you already know — and which one surprised you?

Drop it in the comments. I am curious which ones catch people most often.

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
