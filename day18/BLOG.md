TITLE (paste into Medium title field):
Automating Terraform Testing: From Unit Tests to End-to-End Validation

SUBTITLE (paste into Medium subtitle field):
Manual testing does not scale. Day 18 of my Terraform challenge — I implemented all three layers of automated testing and built a CI/CD pipeline that runs them automatically. Here is everything, including the error I hit.

---

BODY (paste everything below into Medium):

---

Introduction

On Day 17 I ran manual tests against my infrastructure. Ten tests. Documented every result.

It took about an hour.

That is fine for one engineer testing one module once. But what happens when the module changes? Someone has to run all those tests again. And again. And again.

Manual testing does not scale.

Day 18 is about automating those tests so they run on every commit, catch regressions before they reach production, and give the whole team confidence to move fast.

I implemented three layers of testing and built a CI/CD pipeline that runs them automatically. Here is everything — including the error I hit.


Prerequisites

- AWS account with IAM user configured
- Terraform 1.6+ installed
- Go installed (for Terratest)
- GitHub account with Actions enabled
- Days 8-17 of this series — we test the webserver cluster module built over those days


The Three Layers

Before writing any code, understand what each layer does and when to use it.

Layer 1 — Unit Tests (terraform test)
No real infrastructure. Runs in seconds. Free.
Tests your logic — conditionals, variables, tags.

Layer 2 — Integration Tests (Terratest)
Deploys real infrastructure. Takes 5-15 minutes. Costs a little.
Tests that the infrastructure actually works — HTTP responses, health checks.

Layer 3 — End-to-End Tests (Terratest)
Deploys the full stack. Takes 15-30 minutes. Costs more.
Tests that all modules work together as a system.

The strategy: unit tests on every PR, integration tests on every merge to main, E2E tests nightly.


1. Unit Tests with terraform test

Terraform 1.6+ ships with a native testing framework. You write .tftest.hcl files alongside your module and run terraform test. No Go required. No real AWS resources created.

Here is the test file I wrote for the webserver cluster module:

variables {
  cluster_name   = "test-cluster"
  instance_type  = "t3.micro"
  environment    = "dev"
  project_name   = "terratest"
  team_name      = "sarahcodes"
  db_secret_name = "day13/db/credentials"
}

run "validate_instance_type" {
  command = plan

  assert {
    condition     = aws_launch_template.web.instance_type == "t3.micro"
    error_message = "Launch template instance type must match the instance_type variable"
  }
}

📸 Screenshot here — your .tftest.hcl file open in VS Code
Caption: Unit test file alongside the module — .tftest.hcl lives in the same folder as main.tf

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

run "validate_managed_by_tag" {
  command = plan

  assert {
    condition     = aws_security_group.instance_sg.tags["ManagedBy"] == "terraform"
    error_message = "ManagedBy tag must always be set to terraform"
  }
}

command = plan — runs terraform plan only. No apply. No AWS resources. No cost.

The production instance type test is the most valuable one. It proves the is_production conditional logic from Day 11 works correctly — without deploying anything.


2. Integration Tests with Terratest

Integration tests deploy real infrastructure, make HTTP requests against it, and destroy it. Written in Go.

func TestWebserverClusterIntegration(t *testing.T) {
    t.Parallel()

    uniqueID    := random.UniqueId()
    clusterName := fmt.Sprintf("test-cluster-%s", uniqueID)

    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir: "../modules/services/webserver-cluster",
        Vars: map[string]interface{}{
            "cluster_name":  clusterName,
            "instance_type": "t3.micro",
            "environment":   "dev",
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
}

The most important line is defer terraform.Destroy.

defer in Go runs at the end of the function no matter what happens. Even if an assertion fails. Even if the test panics. Without defer, a failed test would exit immediately and leave real EC2 instances, ALBs, and security groups running forever — costing money.

random.UniqueId() generates a short random string like "a3f9" so the cluster name is unique. If two engineers run the test at the same time, they get different names and no conflicts.

📸 Screenshot here — your webserver_cluster_test.go file open in VS Code
Caption: Integration test in Go — defer terraform.Destroy on line 3 of the test body guarantees cleanup


3. End-to-End Tests

End-to-end tests deploy the complete stack and verify all modules work together as a system.

The key difference from integration tests: an integration test deploys one module in isolation. An end-to-end test deploys multiple modules and proves they communicate correctly.

An integration test for the webserver module can pass while an end-to-end test fails — because the webserver works on its own but fails to connect to the database.

func TestFullStackEndToEnd(t *testing.T) {
    t.Parallel()

    uniqueID := random.UniqueId()

    // deploy VPC first
    vpcOptions := &terraform.Options{
        TerraformDir: "../modules/networking/vpc",
        Vars: map[string]interface{}{
            "vpc_name": fmt.Sprintf("test-vpc-%s", uniqueID),
        },
    }
    defer terraform.Destroy(t, vpcOptions)
    terraform.InitAndApply(t, vpcOptions)

    vpcID     := terraform.Output(t, vpcOptions, "vpc_id")
    subnetIDs := terraform.OutputList(t, vpcOptions, "private_subnet_ids")

    // deploy app using VPC outputs
    appOptions := &terraform.Options{
        TerraformDir: "../modules/services/webserver-cluster",
        Vars: map[string]interface{}{
            "cluster_name": fmt.Sprintf("test-app-%s", uniqueID),
            "vpc_id":       vpcID,
            "subnet_ids":   subnetIDs,
            "environment":  "dev",
        },
    }
    defer terraform.Destroy(t, appOptions)
    terraform.InitAndApply(t, appOptions)

    albDnsName := terraform.Output(t, appOptions, "alb_dns_name")
    http_helper.HttpGetWithRetry(t, fmt.Sprintf("http://%s", albDnsName), nil, 200, "Hello", 30, 10*time.Second)
}

Notice two defer terraform.Destroy calls — one for the VPC, one for the app. Both must be destroyed after the test. The order matters: app is destroyed first (it depends on the VPC), then the VPC.

I did not run this test today — it requires a VPC module that is not part of this challenge. But writing it and understanding the pattern is the learning objective.


4. The CI/CD Pipeline

unit-tests — runs on every PR and every push to main
validate-and-plan — runs after unit tests pass
integration-tests — runs only on push to main (after a PR is merged)

name: Terraform Tests

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.11.0"
      - run: terraform init -backend=false
        working-directory: day18/modules/services/webserver-cluster
      - run: terraform test
        working-directory: day18/modules/services/webserver-cluster

  integration-tests:
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    needs: unit-tests
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v4
        with:
          go-version: "1.21"
      - run: go test -v -timeout 30m ./...
        working-directory: day18/test

The if condition on integration-tests is the key line. It only runs when the event is a push AND the branch is main. That only happens when a PR is merged. Not on every PR.

Why? If 5 engineers each open a PR at the same time, running integration tests on all 5 would deploy 5 sets of real AWS infrastructure simultaneously. Expensive and slow. Unit tests on PRs give fast feedback. Integration tests on main give confidence after merge.

📸 Screenshot here — your terraform-tests.yml file open in VS Code
Caption: The CI/CD pipeline — three jobs, unit tests on every PR, integration tests on merge to main only


5. The Branch Strategy

I set up a develop branch for daily work:

- Push code to develop
- Open PR from develop → main
- Unit tests run automatically on the PR
- Merge the PR
- Integration tests run automatically on main

📸 Screenshot here — PR page showing unit tests passing and integration tests skipped
Caption: Unit tests pass on the PR — integration tests correctly skipped, waiting for merge

📸 Screenshot here — Actions tab showing unit test job with terraform test output
Caption: terraform test running in CI — all assertions passing in 32 seconds


6. The Error — Missing go.sum

After merging the PR, integration tests ran and immediately failed:

Error: webserver_cluster_test.go:8:2: missing go.sum entry for module providing
package github.com/gruntwork-io/terratest/modules/http-helper

What happened — Go requires a go.sum file that records cryptographic hashes of all dependencies. It is generated by running go mod tidy locally. I committed go.mod but forgot go.sum.

Fix:

cd day18/test
go mod tidy
git add go.sum
git commit -m "fix: add go.sum for Terratest dependencies"
git push origin develop

Then open another PR and merge.

📸 Screenshot here — the missing go.sum error in GitHub Actions
Caption: Integration test failure — go.sum not committed, Go cannot verify dependencies


Test Layer Comparison

Test Type  |  Tool           |  Real Infra  |  Time      |  Cost   |  What It Catches
-----------|-----------------|--------------|------------|---------|------------------
Unit       |  terraform test |  No          |  Seconds   |  Free   |  Logic, conditionals, tags
Integration|  Terratest      |  Yes         |  5-15 min  |  Low    |  HTTP, health checks, networking
End-to-End |  Terratest      |  Yes         |  15-30 min |  Medium |  Cross-module communication


Key Lessons Learned

- Unit tests with terraform test are free and run in seconds — no excuse not to have them
- command = plan means no real infrastructure is created — tests are assertions against the plan
- defer terraform.Destroy is not optional — it is what prevents orphaned resources when tests fail
- random.UniqueId() prevents name conflicts when tests run in parallel
- go.sum must be committed alongside go.mod — go mod tidy generates it
- Integration tests on every PR is expensive — run them on merge to main only
- The is_production conditional is the most important thing to unit test — it drives instance type, cluster size, and monitoring


Final Thoughts

The gap between manual testing and automated testing is the gap between hoping your infrastructure works and knowing it does.

Unit tests catch logic errors in seconds. Integration tests catch real infrastructure failures. The CI/CD pipeline catches regressions before they reach production.

I am currently doing the 30-Day Terraform Challenge while building Cloud and DevOps skills in public. Open to opportunities — using this time to build real-world skills by actually doing and breaking things.

If you are also learning Terraform or DevOps, let's connect and grow together.

#30DayTerraformChallenge #TerraformChallenge #Terraform #Testing #DevOps #CICD #AWSUserGroupKenya #EveOps #WomenInTech #BuildInPublic #CloudComputing #AWS #Andela
