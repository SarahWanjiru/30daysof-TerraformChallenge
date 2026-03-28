# Day 7 — State Isolation via File Layouts

## Overview
Each environment lives in its own directory with its own backend configuration pointing to a unique S3 key. This is the recommended approach for production use cases.

## Structure

| Folder | S3 State Key |
|---|---|
| `dev/` | `environments/dev/terraform.tfstate` |
| `staging/` | `environments/staging/terraform.tfstate` |
| `production/` | `environments/production/terraform.tfstate` |

## How to Deploy Each Environment
Each directory is initialised and applied independently:

```bash
cd dev && terraform init && terraform apply
cd staging && terraform init && terraform apply
cd production && terraform init && terraform apply
```

Changes in one directory have zero effect on the others. Each environment has its own state file, its own lock, and its own code.

## Why File Layouts Beat Workspaces for Production
With workspaces, all environments share the same code and it is easy to apply to the wrong environment by forgetting to switch. With file layouts, you must physically be inside the correct directory to affect that environment. The isolation is structural, not just logical.
