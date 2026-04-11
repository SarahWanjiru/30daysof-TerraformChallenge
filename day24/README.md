# Day 24: Final Exam Review and Certification Focus

## What I Did Today

No new deployments. Pure focused exam preparation. Ran a full 60-minute simulation,
drilled the four high-weight domains, answered all ten flash card questions, and built
a specific exam-day strategy.

---

## Exam Simulation Score

**Score: 121/200 — Established range, better than 66% of assessed learners**

This was a real knowledge assessment covering all Terraform Associate exam domains
after 23 days of hands-on work.

Score breakdown by level:
- Beginning: 0-49
- Developing: 50-99
- **Established: 100-149 ← my score (121)**
- Advanced: 150-200

Domains where I was weakest based on the assessment:
- Terraform CLI — state commands, workspace state paths, flag behaviour
- Terraform basics — terraform refresh vs terraform apply -refresh-only
- Terraform Cloud — remote vs local execution modes, Sentinel timing

Topics to drill before the real exam:
1. What does `terraform plan -target=module.vpc` do to resources outside the target?
2. Where does Terraform store workspace state in S3 when using the S3 backend?
3. What is the difference between `terraform refresh` and `terraform apply -refresh-only`?
4. What happens to a resource when you run `terraform state mv` to a new address?
5. When does Sentinel run in the Terraform Cloud workflow?
6. What does `terraform output -json` return when there are no outputs defined?

---

## Flash Card Answers

**1. What file does terraform init create to record provider versions?**

`.terraform.lock.hcl` — records the exact provider version selected and its
cryptographic hashes. Committed to Git so every team member and CI system uses the
same provider version.

**2. What is the difference between terraform.workspace and a Terraform Cloud workspace?**

`terraform.workspace` is a built-in string variable that returns the name of the
currently selected workspace (e.g. "default", "dev", "production"). A Terraform Cloud
workspace is a named environment in Terraform Cloud that has its own state, variables,
and run history. They are related concepts but not the same thing.

**3. If you run terraform state rm aws_instance.web, what happens to the EC2 instance in AWS?**

Nothing. The EC2 instance continues to exist in AWS. `terraform state rm` only removes
the resource from the state file — it makes no API calls. Terraform simply stops
tracking that resource.

**4. What does the depends_on meta-argument do and when should you use it?**

`depends_on` creates an explicit dependency between resources, forcing Terraform to
create or destroy them in a specific order. Use it when Terraform cannot automatically
detect the dependency — for example when a resource depends on the side effects of
another resource rather than its output values.

**5. What is the purpose of the .terraform.lock.hcl file?**

Records the exact provider version selected during `terraform init` and its
cryptographic hashes. Ensures every engineer and CI run uses the same provider version.
Should always be committed to Git. Update it with `terraform init -upgrade`.

**6. How does for_each differ from count when items are removed from the middle of a collection?**

`count` addresses resources by index — removing an item from the middle renumbers all
subsequent resources, causing Terraform to destroy and recreate them. `for_each`
addresses resources by key — removing one item only affects that specific resource,
leaving all others untouched.

**7. What does terraform apply -refresh-only do?**

Updates the state file to match the real infrastructure without making any changes to
the real infrastructure. It is the modern replacement for the deprecated
`terraform refresh` command. Use it to detect and record drift without applying changes.

**8. What is the maximum number of items you can specify in a single terraform import command?**

One. Each `terraform import` command imports exactly one resource. To import multiple
resources you must run the command multiple times, once per resource.

**9. What happens when you run terraform plan against a workspace that has never been applied?**

Terraform treats it as a fresh environment with no existing state. The plan shows all
resources as new — everything will be created. There is no state file yet for that
workspace.

**10. What does the prevent_destroy lifecycle argument do and what does it NOT prevent?**

`prevent_destroy = true` causes Terraform to error if a plan would destroy the
resource — it blocks `terraform destroy` and any configuration change that would
require recreation. It does NOT prevent manual deletion of the resource in the AWS
console. It does NOT prevent `terraform state rm` (which removes from state without
destroying). It only blocks Terraform-initiated destruction.

---

## High-Weight Domain Drill

### Terraform Basics (24%)

Three things I now know precisely:

1. `terraform refresh` is deprecated. The replacement is `terraform apply -refresh-only`.
   `refresh` updates state to match real infrastructure. `-refresh-only` does the same
   but shows you what changed before committing — safer because you can review the diff.

2. `terraform.tfstate.backup` is created automatically before every apply. It contains
   the previous state. If an apply corrupts the current state file, you can restore from
   the backup. It is always one apply behind.

3. Data sources read existing infrastructure — they do not create anything. A
   `data "aws_vpc" "default"` block reads the VPC that already exists. A
   `resource "aws_vpc" "new"` block creates a new VPC. The key difference: data sources
   are read-only, resources are read-write.

**Built-in functions to know cold:**

```hcl
locals {
  merged      = merge(var.common_tags, { Name = "example" })
  upper_names = [for name in var.names : upper(name)]
  name_map    = { for name in var.names : name => length(name) }
}
```

- `file(path)` — reads a file and returns its contents as a string
- `templatefile(path, vars)` — reads a file and renders it as a template with variables
- `lookup(map, key, default)` — looks up a key in a map, returns default if not found
- `merge(map1, map2)` — combines maps, later values override earlier ones
- `length(collection)` — returns the number of elements in a list, map, or string
- `toset(list)` — converts a list to a set, removing duplicates and losing order
- `tolist(set)` — converts a set to a list
- `tomap(object)` — converts an object to a map

---

### Terraform CLI (26%)

Three things I now know precisely:

1. `terraform workspace new staging` creates the workspace AND switches to it in one
   command. You do not need to run `terraform workspace select staging` afterward.

2. `terraform state rm` removes from state only — the real resource is untouched.
   `terraform destroy` removes the real resource AND removes it from state. These are
   completely different operations with completely different consequences.

3. `terraform import` brings an existing resource into state but does NOT generate the
   `.tf` configuration. You must write the resource block yourself to match the existing
   resource. If your block does not match, `terraform plan` will show changes that could
   modify or destroy the resource.

---

### IaC Concepts (16%)

Three things I now know precisely:

1. Idempotency means applying the same configuration multiple times produces the same
   result. Running `terraform apply` twice in a row should show "No changes" on the
   second run. If it does not, the configuration is not idempotent.

2. Configuration drift is the gap between declared state and actual state. It happens
   when someone makes a manual change in the AWS console. `terraform plan` detects drift
   and shows what it will do to bring reality back in line with the configuration.

3. Immutable infrastructure means replacing resources rather than modifying them in
   place. `create_before_destroy = true` is the Terraform implementation of this
   pattern — new resource is created before old is destroyed, ensuring no downtime.

---

### Terraform's Purpose (20%)

Three things I now know precisely:

1. Terraform Cloud is SaaS — HashiCorp hosts and manages it. Terraform Enterprise is
   self-hosted — you run it on your own infrastructure. Both provide remote state,
   team access control, Sentinel policies, and audit logs. Enterprise adds SSO, audit
   logging to external systems, and clustering for high availability.

2. The state file is Terraform's source of truth for mapping configuration to real
   resources. Without state, Terraform cannot know which real resource corresponds to
   which resource block in your configuration. This is why state must be stored remotely
   and protected.

3. Terraform is provider-agnostic — it works with any platform that has a provider.
   AWS, Azure, GCP, Kubernetes, GitHub, Datadog, PagerDuty — all managed with the same
   HCL syntax and the same workflow.

---

## Common Exam Traps

**Trap 1 — `terraform destroy` vs `terraform state rm`**

The trap: both "remove" a resource. The difference: `terraform destroy` removes the
real resource from AWS AND removes it from state. `terraform state rm` removes it from
state only — the real resource continues to exist. Exam questions often describe a
scenario and ask which command was used based on the outcome.

**Trap 2 — `sensitive = true` does not encrypt state**

The trap: marking a variable or output as `sensitive = true` looks like a security
measure. It is not. It only hides the value from terminal output and logs. The value
is still stored in plaintext in `terraform.tfstate`. The state file must be encrypted
separately via the S3 backend with `encrypt = true`.

**Trap 3 — Module source pinning: branch vs tag**

The trap: `source = "github.com/org/module?ref=main"` looks pinned. It is not. `main`
is a branch — it changes every time someone pushes. `?ref=v1.0.0` is a tag — it is
immutable. Exam questions test whether you know the difference between mutable and
immutable references.

**Trap 4 — `terraform workspace new` switches automatically**

The trap: you might think you need to run `terraform workspace new staging` then
`terraform workspace select staging`. You do not. `new` creates AND switches in one
command.

**Trap 5 — `terraform import` does not generate configuration**

The trap: `terraform import` sounds like it does everything — imports the resource and
writes the config. It only adds the resource to state. You still have to write the
resource block yourself. If you run `terraform plan` after import without writing the
block, Terraform will plan to destroy the resource.

---

## Exam-Day Strategy

- Spend maximum 90 seconds on any single question before flagging and moving on
- Answer every question — there is no penalty for wrong answers, so never leave one blank
- On multi-select questions, read "select TWO" carefully — selecting one or three marks the whole question wrong
- Eliminate clearly wrong answers first — most questions have at least one obviously wrong choice
- Watch for "NOT" and "EXCEPT" in question stems — easy to miss under time pressure
- For state questions, always ask: "does this command touch real infrastructure or just the state file?"
- For `sensitive = true` questions, always ask: "does this encrypt state or just hide terminal output?"
- Flag and return — complete all questions first, then revisit flagged ones with remaining time

---

## Remaining Red Topics

No red topics remaining from yesterday's audit. The four yellow topics have been
addressed through today's drill:

- ✅ `terraform state` commands — drilled with flash cards and practice questions
- ✅ Workspace isolation vs directory isolation — clarified in domain drill
- ✅ Terraform Cloud remote runs — covered in Terraform's purpose domain
- ✅ CLI flags — covered in CLI domain drill

---

## Blog Post

URL: *(paste blog URL here)*

Title: **My Final Preparation for the Terraform Associate Exam**

---

## Social Media

URL: *(paste post URL here)*

> 🎓 Day 24 of the 30-Day Terraform Challenge — final exam prep. Full simulation under
> timed conditions, drilled the high-weight domains, built my exam-day strategy.
> Whatever the score is, I know this material better than I did 24 days ago. Let's go.
> #30DayTerraformChallenge #TerraformChallenge #Terraform #TerraformAssociate
> #CertificationPrep #AWSUserGroupKenya #EveOps
