# Day 18: Automated Testing of Terraform Code

## What I Did Today

Implemented all three layers of Terraform automated testing: unit tests using the native
`terraform test` framework, integration tests using Terratest in Go, and a CI/CD pipeline
using GitHub Actions that runs unit tests on every PR and integration tests on every merge
to main. Set up a `develop` branch workflow so the pipeline runs correctly at each stage.



## Project Structure

```
day18/
├── modules/services/webserver-cluster/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── webserver_cluster_test.tftest.hcl   # unit tests
├── live/dev/services/webserver-cluster/
│   └── main.tf
└── test/
    ├── go.mod
    └── webserver_cluster_test.go            # integration tests
```



## Unit Test File

```hcl
# webserver_cluster_test.tftest.hcl

variables {
  cluster_name   = "test-cluster"
  instance_type  = "t3.micro"
  min_size       = 1
  max_size       = 2
  environment    = "dev"
  project_name   = "terratest"
  team_name      = "sarahcodes"
  db_secret_name = "day13/db/credentials"
}

run "validate_asg_name_prefix" {
  command = plan

  assert {
    condition     = startswith(aws_autoscaling_group.web.name_prefix, "test-cluster-")
    error_message = "ASG name_prefix must start with the cluster_name variable"
  }
}

run "validate_instance_type" {
  command = plan

  assert {
    condition     = aws_launch_template.web.instance_type == "t3.micro"
    error_message = "Launch template instance type must match the instance_type variable"
  }
}

run "validate_environment_tag" {
  command = plan

  assert {
    condition     = aws_security_group.instance_sg.tags["Environment"] == "dev"
    error_message = "Environment tag must match the environment variable"
  }
}

run "validate_managed_by_tag" {
  command = plan

  assert {
    condition     = aws_security_group.instance_sg.tags["ManagedBy"] == "terraform"
    error_message = "ManagedBy tag must always be set to terraform"
  }
}

run "validate_production_instance_type" {
  command = plan

  variables {
    environment = "production"
  }

  assert {
    condition     = aws_launch_template.web.instance_type == "t3.small"
    error_message = "Production environment must use t3.small instance type"
  }
}
```

**What each run block tests:**

- `validate_asg_name_prefix` — proves `cluster_name` variable flows through to the ASG `name_prefix`
- `validate_instance_type` — proves the `instance_type` variable is passed to the launch template
- `validate_environment_tag` — proves `common_tags` locals block applies the environment tag correctly
- `validate_managed_by_tag` — proves `ManagedBy = "terraform"` is always set regardless of inputs
- `validate_production_instance_type` — proves the `is_production` conditional overrides instance type to `t3.small`

`command = plan` means no real AWS resources are created. Tests run in seconds for free.



## Integration Test

```go
package test

import (
    "fmt"
    "testing"
    "time"

    http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
    "github.com/gruntwork-io/terratest/modules/random"
    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestWebserverClusterIntegration(t *testing.T) {
    t.Parallel()

    uniqueID    := random.UniqueId()
    clusterName := fmt.Sprintf("test-cluster-%s", uniqueID)

    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir: "../modules/services/webserver-cluster",
        Vars: map[string]interface{}{
            "cluster_name":   clusterName,
            "instance_type":  "t3.micro",
            "min_size":       1,
            "max_size":       2,
            "environment":    "dev",
            "project_name":   "terratest",
            "team_name":      "sarahcodes",
            "db_secret_name": "day13/db/credentials",
        },
    })

    defer terraform.Destroy(t, terraformOptions)

    terraform.InitAndApply(t, terraformOptions)

    albDnsName := terraform.Output(t, terraformOptions, "alb_dns_name")
    url        := fmt.Sprintf("http://%s", albDnsName)

    http_helper.HttpGetWithRetryWithCustomValidation(
        t, url, nil, 30, 10*time.Second,
        func(status int, body string) bool {
            return status == 200 && len(body) > 0
        },
    )

    assert.NotEmpty(t, albDnsName, "ALB DNS name should not be empty")
}
```

**What `defer terraform.Destroy` guarantees:**

`defer` in Go runs at the end of the function regardless of what happens — even if an
assertion fails, even if the test panics. Without it, a failed assertion would exit
immediately and leave real AWS resources running and incurring cost. `defer` is not
optional in Terratest.



## Test Execution Results

### Unit Tests — PR on develop → main

```
Terraform Tests / Unit Tests — Successful in 32s
```

Unit tests ran on the PR before merge. All 5 assertions passed. No real infrastructure
was created.

📸 Screenshot — PR page showing unit tests passing

### Integration Tests — Push to main (after merge)

```
Error: webserver_cluster_test.go:8:2: missing go.sum entry for module providing
package github.com/gruntwork-io/terratest/modules/http-helper
```

**Root cause:** `go.sum` file was not committed. Go requires a `go.sum` file that records
the cryptographic hashes of all dependencies. It is generated by running `go mod tidy`
locally. Without it, `go get` cannot verify the packages.

**Fix:** Run `go mod tidy` in the `test/` directory to generate `go.sum`, then commit it.

```bash
cd day18/test
go mod tidy
git add go.sum
git commit -m "fix: add go.sum for Terratest dependencies"
git push origin develop
```


## CI/CD Pipeline

```yaml
name: Terraform Tests

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  unit-tests:
    name: Unit Tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.11.0"
      - name: Terraform Init
        run: terraform init -backend=false
        working-directory: day18/modules/services/webserver-cluster
      - name: Run Unit Tests
        run: terraform test
        working-directory: day18/modules/services/webserver-cluster

  integration-tests:
    name: Integration Tests
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    needs: unit-tests
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v4
        with:
          go-version: "1.21"
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.11.0"
      - name: Run Integration Tests
        run: go test -v -timeout 30m ./...
        working-directory: day18/test
```

**Job dependency explanation:**

- `unit-tests` runs on both PRs and pushes to main — fast, free, catches logic errors
- `integration-tests` only runs on push to main — the `if` condition checks both the
  event type and the branch. This means it only runs when a PR is merged, not on every PR
- `needs: unit-tests` means integration tests only start if unit tests pass first

**Why integration tests don't run on every PR:**

If 5 engineers each open a PR at the same time, running integration tests on all 5 would
deploy 5 sets of real AWS infrastructure simultaneously. That is expensive and slow.
Unit tests on PRs give fast feedback. Integration tests on main give confidence after merge.



## Test Layer Comparison

| Test Type | Tool | Deploys Real Infra | Time | Cost | What It Catches |
|---|---|---|---|---|---|
| Unit | `terraform test` | No | Seconds | Free | Logic errors, wrong variable values, bad conditionals, tag mistakes |
| Integration | Terratest | Yes | 5-15 min | Low (~$0.50) | Real networking, health checks, HTTP responses, IAM issues |
| End-to-End | Terratest | Yes | 15-30 min | Medium (~$2-5) | Cross-module communication, full user path, database connectivity |



## Chapter 9 Learnings

**Key difference between integration and end-to-end tests:**

An integration test deploys one module in isolation and verifies it works on its own.
An end-to-end test deploys multiple modules together and verifies they work as a system.

An integration test for the webserver module proves the ALB serves traffic. An end-to-end
test would deploy a VPC module, then a database module, then the webserver module, and
prove the webserver can actually read from the database. The integration test can pass
while the end-to-end test fails — because the modules work individually but fail to
communicate with each other.

**Why unit tests on every PR but E2E tests less frequently:**

Unit tests take seconds and cost nothing. Running them on every commit is free. E2E tests
take 15-30 minutes and deploy real infrastructure that costs money. Running them on every
commit would be slow and expensive. The book recommends nightly or pre-release for E2E —
often enough to catch regressions, not so often that it becomes a cost problem.



## Challenges and Fixes

- **Missing go.sum file** — integration tests failed with `missing go.sum entry`. Go
  requires a `go.sum` file recording cryptographic hashes of all dependencies. Generated
  by running `go mod tidy` locally and committing the result.

- **Integration tests running on PRs** — initially the `if` condition was missing. Fixed
  by adding `if: github.event_name == 'push' && github.ref == 'refs/heads/main'` to the
  integration-tests job so it only runs on merge to main.

- **Unit tests need AWS credentials** — even though `command = plan` does not deploy
  infrastructure, the module fetches from Secrets Manager during plan. AWS credentials
  must be available in the CI environment via GitHub secrets.

