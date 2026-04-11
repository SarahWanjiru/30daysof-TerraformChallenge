# Day 23: Exam Preparation — Brushing Up on Key Terraform Concepts

## What I Did Today

Audited every exam domain honestly against the official study guide, built a structured
study plan for the remaining days, reviewed CLI commands, non-cloud providers, and
Terraform Cloud capabilities, and wrote five original practice questions.



## Domain Audit

| Domain | Weight | Rating | Notes |
|---|---|---|---|
| Understand IaC concepts | 16% |  Green | Built and explained IaC from Day 1 |
| Understand Terraform's purpose | 20% |  Green | Providers, state, plan/apply cycle all hands-on |
| Understand Terraform basics | 24% |  Yellow | Variables, outputs, locals solid — workspace isolation needs review |
| Use the Terraform CLI | 26% |  Yellow | Core commands solid — state mv, state rm, taint need practice |
| Interact with Terraform modules | 12% |  Green | Built, versioned, and published modules across 22 days |
| Navigate the core Terraform workflow | 8% |  Green | Seven-step workflow executed end-to-end on Days 20-21 |
| Implement and maintain state | 8% |  Yellow | S3 backend solid — state commands and workspace isolation need practice |
| Read, generate, and modify configuration | 8% |  Green | count, for_each, conditionals, locals all hands-on |
| Understand Terraform Cloud capabilities | 4% |  Yellow | Sentinel and cost estimation written — remote runs vs local runs needs review |

**Summary:** 5 Green, 4 Yellow, 0 Red. Biggest gaps: CLI state commands and Terraform
Cloud remote execution model.



## Study Plan — Days 24 to Exam

| Topic | Confidence | Study Method | Time |
|---|---|---|---|
| `terraform state` commands | Yellow | Run `state mv`, `state rm`, `state show` against test resource, write 3 practice questions | 45 min |
| Workspace isolation vs file layout | Yellow | Read docs, write one practice question comparing workspace vs directory isolation | 30 min |
| Terraform Cloud remote runs | Yellow | Read remote execution docs, compare to local runs, write 2 practice questions | 30 min |
| CLI flags — `terraform plan` | Yellow | Review all flags: `-out`, `-target`, `-refresh-only`, `-destroy`, `-var`, `-var-file` | 30 min |
| Non-cloud providers | Yellow | Write working examples for `random`, `local`, `tls` providers | 20 min |
| Official sample questions | Yellow | Work through all official questions, add every miss to this table | 60 min |
| Full mock exam | Yellow | Time-boxed 60-minute mock, review every wrong answer | 60 min |



## CLI Commands Self-Test

**terraform init**
Downloads provider plugins and configures the backend. Use it when you first clone a
repo, when you add a new provider, or when you change the backend configuration.

**terraform validate**
Checks syntax and internal consistency without making any AWS calls. Use it in CI to
catch type errors and missing required arguments before running plan.

**terraform fmt**
Reformats `.tf` files to the canonical style — consistent indentation and spacing.
Use it before committing code or in CI with `-check` to fail if files are not formatted.

**terraform plan**
Generates a diff between the current state and the desired configuration. Use it before
every apply to review exactly what will change. Save with `-out=plan.tfplan` to pin the
reviewed plan.

**terraform apply**
Creates, updates, or replaces resources to match the configuration. Use it to deploy
infrastructure — always from a saved plan file in production.

**terraform destroy**
Removes all resources managed by the current configuration. Use it to clean up test
environments. Always run `terraform plan -destroy` first to review what will be deleted.

**terraform output**
Reads output values from the state file without running a plan. Use it to retrieve
values like ALB DNS names or ASG names after an apply.

**terraform state list**
Lists all resources currently tracked in the state file. Use it to see what Terraform
is managing or to find the exact resource address before running other state commands.

**terraform state show**
Shows all attributes of a specific resource in state. Use it to inspect the current
state of a resource — for example to see the exact ARN of an ALB.

**terraform state mv**
Moves a resource within state — either renaming it or moving it to a different state
file. Use it when you refactor code and rename a resource without wanting to destroy
and recreate it.

**terraform state rm**
Removes a resource from state without destroying the real infrastructure. Use it when
you want Terraform to stop managing a resource — for example when handing a resource
off to another team's configuration.

**terraform import**
Adds an existing real-world resource to the state file so Terraform can manage it.
Use it when you have infrastructure that was created manually and you want to bring it
under Terraform management.

**terraform taint** *(deprecated — use `-replace` flag on plan/apply)*
Marks a resource for forced recreation on the next apply. Use `terraform apply -replace=resource.name` instead. Useful when a resource is in a broken state but Terraform does not detect it as changed.

**terraform workspace**
Creates, selects, lists, and deletes workspaces. Use it to maintain separate state
files for different environments within the same configuration directory.

**terraform providers**
Shows all providers required by the current configuration and their version constraints.
Use it to debug provider version conflicts or to see which modules require which providers.

**terraform login**
Authenticates to Terraform Cloud by storing a token locally. Use it before running
`terraform init` against a Terraform Cloud backend.

**terraform graph**
Outputs the dependency graph of resources in DOT format. Use it to visualise resource
dependencies and debug unexpected ordering issues.



## Non-Cloud Provider Code

```hcl
terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

# generates a random suffix for resource names — prevents naming conflicts
resource "random_id" "suffix" {
  byte_length = 4
}

# generates a random password — useful for bootstrapping database credentials
resource "random_password" "db" {
  length  = 16
  special = true
}

# writes a local file — useful for generating kubeconfig or inventory files
resource "local_file" "config" {
  content  = "cluster_suffix = ${random_id.suffix.hex}"
  filename = "${path.module}/generated-config.txt"
}

output "resource_suffix" {
  value = random_id.suffix.hex
}

output "db_password" {
  value     = random_password.db.result
  sensitive = true
}
```

**Where these providers are useful:**

`random_id` — used in Day 12 to generate unique ASG names so old and new ASGs can
coexist during `create_before_destroy`. Without it, two ASGs with the same name would
conflict during a zero-downtime update.

`random_password` — generates secure passwords for database bootstrapping without
hardcoding them in `.tf` files. The password is stored in state (encrypted) and can
be passed to Secrets Manager.

`local_file` — generates configuration files (kubeconfig, inventory files, `.env`
files) as part of a Terraform apply. Useful when downstream tools need a file that
references Terraform-managed resources.



## Five Original Practice Questions

**Question 1**

You run `terraform state rm aws_s3_bucket.logs`. What happens to the actual S3 bucket
in AWS?

A) The bucket is deleted from AWS
B) The bucket is moved to a different state file
C) Nothing — the bucket still exists in AWS but Terraform no longer tracks it
D) The bucket is marked for deletion on the next terraform apply

**Answer: C**

`terraform state rm` only removes the resource from the state file. It does not make
any API calls to AWS. The real bucket continues to exist. On the next `terraform plan`,
Terraform will not show the bucket because it is no longer in state — but the bucket
is still there.



**Question 2**

A team member manually deleted an EC2 instance that Terraform manages. What does
`terraform plan` show?

A) No changes — Terraform does not detect manual deletions
B) The instance will be destroyed
C) The instance will be created
D) An error — Terraform cannot plan when resources are missing

**Answer: C**

Terraform compares the state file (which still shows the instance) against the real
infrastructure (where the instance no longer exists). It detects the drift and plans
to create the instance to match the desired configuration.



**Question 3**

What is the difference between `terraform workspace new staging` and creating a
`live/staging/` directory?

A) Workspaces are faster to create
B) Workspaces share the same configuration files but maintain separate state files;
   directory isolation uses completely separate configuration files
C) Directory isolation is deprecated in favour of workspaces
D) There is no difference — both approaches produce identical results

**Answer: B**

Workspaces use the same `.tf` files but store state in separate paths in the backend.
Directory isolation uses completely separate configuration files per environment. The
book recommends directory isolation for production environments because it makes
differences between environments explicit in code rather than hidden in workspace
selection.



**Question 4**

You have a `count = var.enable_feature ? 1 : 0` resource. You try to output its ARN
directly: `value = aws_resource.example.arn`. What happens when `enable_feature = false`?

A) The output returns null
B) The output returns an empty string
C) Terraform errors at plan time — the resource does not exist
D) The output is skipped automatically

**Answer: C**

When `count = 0`, the resource does not exist. Referencing it directly without index
notation causes a plan-time error. The correct pattern is:
`value = var.enable_feature ? aws_resource.example[0].arn : null`



**Question 5**

Which of the following correctly describes what `terraform apply -replace=aws_instance.web`
does?

A) Removes the instance from state without destroying it
B) Forces the instance to be destroyed and recreated even if no configuration changes
C) Imports the instance into state
D) Marks the instance as tainted for the next apply

**Answer: B**

`-replace` forces Terraform to destroy and recreate the specified resource regardless
of whether the configuration has changed. This is the modern replacement for the
deprecated `terraform taint` command. Use it when a resource is in a broken state
that Terraform does not detect as a configuration drift.



## Official Practice Question Results

Worked through the official HashiCorp sample questions.

Topics I needed to review after the sample questions:
- Workspace state isolation — the exact path format in S3 for workspace state files
- `terraform refresh` behaviour — it updates state to match real infrastructure but
  does not modify real infrastructure
- The difference between `sensitive = true` on a variable vs on an output — both
  hide the value from terminal output but neither encrypts the state file



## Chapter Learnings

The CLI commands section is more detailed than most people expect. The exam does not
just ask "what does terraform plan do" — it asks scenario questions like "what happens
to real infrastructure when you run terraform state rm?" The answer requires
understanding the separation between state and real infrastructure.

The most important distinction to internalise: **state is not infrastructure**. State
is Terraform's record of what it thinks exists. Real infrastructure is what actually
exists in AWS. These can diverge. Every state command operates on the record, not on
the real infrastructure — except `terraform apply` and `terraform destroy`.


