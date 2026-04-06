# Day 17: Manual Testing of Terraform Code

## What I Did Today

Built a structured manual test checklist and ran it against both dev and production
environments using the day16 production-grade webserver cluster. Documented every test
result, hit one real failure (prevent_destroy blocking cleanup), and verified clean
destruction using AWS CLI.



## Project Structure

```
day17/
├── modules/services/webserver-cluster/   # copied from day16 — production-grade module
├── live/
│   ├── dev/services/webserver-cluster/   # dev test environment
│   └── production/services/webserver-cluster/  # production test environment
└── test/
    └── webserver_cluster_test.go         # Terratest reference
```



## Manual Test Checklist

### Provisioning Verification
- [ ] `terraform init` completes without errors
- [ ] `terraform validate` passes cleanly
- [ ] `terraform plan` shows expected number and type of resources
- [ ] `terraform apply` completes without errors

### Resource Correctness
- [ ] All expected resources visible in AWS Console
- [ ] Resource names, tags, and regions match variables
- [ ] Security group rules match configuration exactly

### Functional Verification
- [ ] ALB DNS name resolves
- [ ] `curl http://<alb-dns>` returns expected HTML response
- [ ] All instances in ASG pass health checks

### State Consistency
- [ ] `terraform plan` returns "No changes" immediately after fresh apply
- [ ] State file accurately reflects what exists in AWS

### Regression Check
- [ ] Small change shows only that change in plan — nothing unexpected
- [ ] `terraform plan` returns clean after applying the change

### Cleanup
- [ ] `terraform plan -destroy` shows expected resources to destroy
- [ ] `terraform destroy` completes without errors
- [ ] AWS CLI confirms no orphaned resources remain



## Test Execution Results — Dev Environment

**Test 1 — terraform validate**
```
Command:  terraform validate
Expected: Success! The configuration is valid.
Actual:   Success! The configuration is valid.
Result:   PASS
```

**Test 2 — terraform plan**
```
Command:  terraform plan
Expected: 11 resources to add, correct tags on all resources
Actual:   Plan: 11 to add, 0 to change, 0 to destroy.
          instance_type_used = "t3.micro"
Result:   PASS
```

**Test 3 — terraform apply**
```
Command:  terraform apply -auto-approve
Expected: Apply complete, 11 resources created
Actual:   Apply complete! Resources: 11 added, 0 changed, 0 destroyed.
          alb_dns_name = "webservers-dev-alb-163403368.eu-north-1.elb.amazonaws.com"
          instance_type_used = "t3.micro"
          sns_topic_arn = "arn:aws:sns:eu-north-1:629836545449:webservers-dev-alerts"
Result:   PASS
```

**Test 4 — State consistency**
```
Command:  terraform plan (immediately after apply)
Expected: No changes. Your infrastructure matches the configuration.
Actual:   No changes. Your infrastructure matches the configuration.
Result:   PASS
```

**Test 5 — Functional verification**
```
Command:  curl -s http://webservers-dev-alb-163403368.eu-north-1.elb.amazonaws.com
Expected: HTML response containing "Hello from webservers-dev"
Actual:   <h1>Hello from webservers-dev — v1 — ip-172-31-6-29.eu-north-1.compute.internal</h1>
Result:   PASS
```

**Test 6 — Regression check (plan)**
```
Command:  terraform plan (after changing app_version from "v1" to "v2")
Expected: Exactly 2 changes — Launch Template user_data and ASG tag
Actual:   Plan: 0 to add, 2 to change, 0 to destroy.
Result:   PASS
```

**Test 7 — Regression check (apply)**
```
Command:  terraform apply -auto-approve
Expected: 0 added, 2 changed, 0 destroyed
Actual:   Apply complete! Resources: 0 added, 2 changed, 0 destroyed.
Result:   PASS
```

**Test 8 — Clean state after regression**
```
Command:  terraform plan
Expected: No changes.
Actual:   No changes. Your infrastructure matches the configuration.
Result:   PASS
```

**Test 9 — Cleanup (FAIL → FIXED)**
```
Command:  terraform plan -destroy
Expected: Plan to destroy 11 resources cleanly
Actual:   Error: Instance cannot be destroyed
          Resource module.webserver_cluster.aws_lb.web has lifecycle.prevent_destroy set

Result:   FAIL
Fix:      prevent_destroy = true on the ALB is working exactly as designed — it blocks
          accidental destruction in production. For testing environments, the lifecycle
          block must be temporarily removed before destroy.
          Removed prevent_destroy from the module, re-ran apply (0 changes to infra),
          then destroy succeeded cleanly.
```

**Test 10 — Cleanup verification**
```
Command:  aws ec2 describe-instances --filters "Name=tag:ManagedBy,Values=terraform" \
            --query "Reservations[*].Instances[*].[InstanceId,State.Name]" \
            --region eu-north-1 --output table
Actual:
---------------------------------------
|          DescribeInstances          |
+----------------------+--------------+
|  i-0300d1ae86a7a5903 |  terminated  |
+----------------------+--------------+

Command:  aws elbv2 describe-load-balancers \
            --query "LoadBalancers[*].LoadBalancerArn" --region eu-north-1
Actual:   []

Result:   PASS — instance is terminated (not running), ALB is gone. AWS keeps terminated
          instances visible in the API for a few hours before purging them.
```



## Test Execution Results — Production Environment

**Test 1 — terraform validate**
```
Result: PASS — Success! The configuration is valid.
```

**Test 2 — terraform plan**
```
Command:  terraform plan
Expected: 14 resources (3 more than dev — autoscaling policies + CloudWatch alarm)
Actual:   Plan: 14 to add, 0 to change, 0 to destroy.
          instance_type_used = "t3.small"
          min_size_used      = 3
          max_size_used      = 10
Result:   PASS
```

**Test 3 — terraform apply**
```
Command:  terraform apply -auto-approve
Actual:   Apply complete! Resources: 14 added, 0 changed, 0 destroyed.
          alb_dns_name       = "webservers-production-alb-1315022415.eu-north-1.elb.amazonaws.com"
          instance_type_used = "t3.small"
          min_size_used      = 3
          max_size_used      = 10
Result:   PASS
```

**Test 4 — Functional verification**
```
Command:  curl -s http://webservers-production-alb-1315022415.eu-north-1.elb.amazonaws.com
Actual:   <h1>Hello from webservers-production — v1 — ip-172-31-6-73.eu-north-1.compute.internal</h1>
Result:   PASS
```

**Test 5 — State consistency**
```
Command:  terraform plan
Actual:   No changes. Your infrastructure matches the configuration.
Result:   PASS
```



## Multi-Environment Comparison

| Test | Dev | Production | Difference |
|---|---|---|---|
| Resources created | 11 | 14 | Production has autoscaling policies + CloudWatch alarm |
| instance_type | t3.micro | t3.small | Driven by `is_production` local |
| min_size | 1 | 3 | Driven by `is_production` local |
| max_size | 3 | 10 | Driven by `is_production` local |
| ALB response | webservers-dev | webservers-production | cluster_name variable |
| Tags | Environment = "dev" | Environment = "production" | common_tags local |

No unexpected differences. Every difference was intentional and driven by the `is_production`
conditional logic built in Day 11. This confirms the module behaves correctly across environments.

---

## Cleanup Verification

```bash
# EC2 instances
aws ec2 describe-instances \
  --filters "Name=tag:ManagedBy,Values=terraform" \
  --query "Reservations[*].Instances[*].[InstanceId,State.Name]" \
  --region eu-north-1 --output table

# Output:
# +----------------------+--------------+
# |  i-0300d1ae86a7a5903 |  terminated  |
# +----------------------+--------------+
# Instance is terminated — not running, just pending API purge

# Load balancers
aws elbv2 describe-load-balancers \
  --query "LoadBalancers[*].LoadBalancerArn" \
  --region eu-north-1

# Output: []  — clean
```

---

## Chapter 9 Learnings

**What the author means by "cleaning up after tests":**

Cleaning up means destroying every resource created during a test run immediately after
the test completes. The author says this is harder than it sounds for three reasons:

1. `terraform destroy` sometimes fails partway through — leaving orphaned resources that
   are not tracked in state and continue to cost money
2. Engineers forget — a test cluster left running overnight costs real money
3. Leftover resources pollute future test runs — name conflicts, stale state, unexpected
   plan output

**The risk of not cleaning up between test runs:**

If you run a test, forget to destroy, then run the test again — Terraform might try to
create resources that already exist and fail with name conflicts. Or it might succeed and
you now have two copies of the same infrastructure, both in state, both costing money.
The state file becomes unreliable and you lose confidence in what is actually running.

---

## Lab Takeaways — terraform import

`terraform import` solves the problem of infrastructure that exists in AWS but was not
created by Terraform. Someone created a security group manually in the console. A legacy
system created an S3 bucket. `terraform import` adds that resource to the state file so
Terraform can manage it going forward.

**What it does:**
- Adds the existing resource to `terraform.tfstate`
- Terraform now tracks it and can plan changes against it

**What it does NOT do:**
- It does not write the `.tf` configuration for you
- You must write the resource block manually to match the existing resource
- If your configuration does not match the actual resource, `terraform plan` will show
  changes to bring it in line

The limitation: import is a one-way operation. You get the resource into state but you
still have to reverse-engineer the configuration. `terraform show` after import helps —
it displays all the resource attributes so you can write the matching config.



## Challenges and Fixes

**Challenge 1 — prevent_destroy blocking cleanup**

`terraform plan -destroy` failed with:

```
Error: Instance cannot be destroyed
Resource module.webserver_cluster.aws_lb.web has lifecycle.prevent_destroy set
```

Root cause: `prevent_destroy = true` was added to the ALB in the day16 production-grade
refactor. It is working exactly as designed — protecting the ALB from accidental deletion.

Fix: For test environments, `prevent_destroy` must be temporarily removed before destroy.
Removed the lifecycle block, ran `terraform apply` (0 infrastructure changes), then
`terraform destroy` succeeded.

Lesson: `prevent_destroy` is a production safety feature, not a testing feature. Consider
using it only in production calling configs, not in the module itself.

**Challenge 2 — Terminated instance appearing in cleanup verification**

After destroy, the EC2 cleanup check showed one instance still present. Looked like an
orphaned resource. Turned out the instance was in `terminated` state — AWS keeps terminated
instances visible in the API for a few hours before purging them from the response.

Fix: Added `State.Name` to the query to confirm the state. `terminated` = clean.

