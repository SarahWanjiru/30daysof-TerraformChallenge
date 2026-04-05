# Day 15: Working with Multiple Providers — Part 2

## What I Did Today

Completed Chapter 7 — wrote a reusable module that accepts provider configurations from its
caller, deployed Docker containers using the Docker provider, and deployed a full EKS cluster
with a Kubernetes nginx deployment using nothing but Terraform code. Hit three real errors
along the way and documented every fix.

---

## Project Structure

```
day15/
├── modules/multi-region-app/    # reusable module — no provider blocks inside
├── live/multi-region/           # calling config — creates providers, passes them in
├── docker/                      # Docker provider — nginx container locally
└── eks/                         # EKS cluster + Kubernetes deployment
    ├── main.tf                  # VPC, EKS module, Kubernetes provider
    └── kubernetes.tf            # nginx deployment — applied after cluster ready
```

---

## Multi-Provider Module Pattern

### Why modules cannot define their own providers

If a module defined `provider "aws" { region = "eu-west-1" }` internally, every team using
the module would be stuck with `eu-west-1`. Modules are reusable — the caller decides which
region or account to use. The module just declares which providers it expects.

### Module declaration — configuration_aliases

```hcl
# modules/multi-region-app/main.tf
terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 6.0"
      configuration_aliases = [aws.primary, aws.replica]
    }
  }
}

# primary bucket — uses aws.primary provider passed in by the caller
resource "aws_s3_bucket" "primary" {
  provider = aws.primary
  bucket   = "${var.app_name}-primary-day15"
}

# replica bucket — uses aws.replica provider passed in by the caller
resource "aws_s3_bucket" "replica" {
  provider = aws.replica
  bucket   = "${var.app_name}-replica-day15"
}
```

`configuration_aliases = [aws.primary, aws.replica]` tells Terraform which provider aliases
the module expects to receive. Without this declaration, Terraform errors when the caller
tries to pass aliased providers into the module.

### Calling configuration — providers map

```hcl
# live/multi-region/main.tf
provider "aws" {
  alias  = "primary"
  region = "eu-north-1"
}

provider "aws" {
  alias  = "replica"
  region = "eu-west-1"
}

module "multi_region_app" {
  source   = "../../modules/multi-region-app"
  app_name = "sarahcodes"

  providers = {
    aws.primary = aws.primary
    aws.replica = aws.replica
  }
}
```

The `providers` map wires the root module's providers to the module's expected aliases.
`aws.primary = aws.primary` means: the module's `aws.primary` alias gets the root's
`aws.primary` provider (eu-north-1).

**Deployment output:**

```
primary_bucket_region = "eu-north-1"
replica_bucket_region = "eu-west-1"
```

---

## Docker Deployment

```hcl
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

resource "docker_image" "nginx" {
  name         = "nginx:latest"
  keep_locally = false
}

resource "docker_container" "nginx" {
  image = docker_image.nginx.image_id
  name  = "terraform-nginx"

  ports {
    internal = 80
    external = 8080
  }
}
```

**docker ps output confirming container was running:**

```
CONTAINER ID   IMAGE          COMMAND                  CREATED         STATUS         PORTS                  NAMES
e9cf3ba25977   0cf1d6af5ca7   "/docker-entrypoint…"   3 minutes ago   Up 3 minutes   0.0.0.0:8080->80/tcp   terraform-nginx
```

nginx served the welcome page at `http://localhost:8080`. Destroyed after confirmation.

---

## EKS Cluster Configuration

```hcl
# kubernetes provider authenticates using aws eks get-token
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name            = "sarahcodes-eks-vpc"
  cidr            = "10.0.0.0/16"
  azs             = ["eu-north-1a", "eu-north-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]
  enable_nat_gateway = true
  single_nat_gateway = true
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "sarahcodes-eks"
  cluster_version = "1.32"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets

  cluster_endpoint_public_access = true

  eks_managed_node_groups = {
    default = {
      min_size       = 1
      max_size       = 3
      desired_size   = 2
      instance_types = ["t3.small"]
    }
  }
}
```

**How the Kubernetes provider authenticates:**

The `exec` block runs `aws eks get-token --cluster-name sarahcodes-eks` every time Terraform
needs to talk to the cluster. This command calls the AWS STS API and returns a short-lived
token. The Kubernetes provider uses that token to authenticate API calls. No static credentials
are stored anywhere.

---

## Kubernetes Deployment Confirmation

```hcl
resource "kubernetes_deployment" "nginx" {
  metadata {
    name   = "nginx-deployment"
    labels = { app = "nginx" }
  }

  spec {
    replicas = 2
    selector { match_labels = { app = "nginx" } }
    template {
      metadata { labels = { app = "nginx" } }
      spec {
        container {
          image = "nginx:latest"
          name  = "nginx"
          port  { container_port = 80 }
        }
      }
    }
  }
}
```

**kubectl get pods output:**

```
NAME                                READY   STATUS    RESTARTS   AGE
nginx-deployment-6847d94d85-8b89r   1/1     Running   0          4m27s
nginx-deployment-6847d94d85-hdwlh   1/1     Running   0          4m27s
```

2 pods running. Deployed entirely by Terraform. Zero manual console clicks.

---

## Chapter 7 Learnings

**Why modules cannot contain their own provider blocks when aliased:**

A module with an internal provider block locks every caller to that provider's configuration.
There is no way to override it. Modules must be reusable — the caller owns the providers,
the module just uses them.

**What configuration_aliases does:**

It declares which provider aliases the module expects to receive from its caller. Without it,
Terraform does not know the module needs aliased providers and errors when the caller tries
to pass them in via the `providers` map.

**How Terraform knows which provider to use for Kubernetes resources:**

The Kubernetes provider is configured with `host = module.eks.cluster_endpoint`. Terraform
creates an implicit dependency — the Kubernetes provider cannot be initialised until the EKS
module outputs are available. After the cluster is provisioned, the provider uses the `exec`
block to get a token and authenticate all subsequent Kubernetes API calls.

---

## EKS Cost Awareness

Resources created by an EKS cluster:

- EKS control plane — $0.10/hour
- 2x t3.small EC2 nodes — ~$0.023/hour each
- NAT Gateway — ~$0.045/hour
- VPC, subnets, security groups, IAM roles

Approximate cost for 24 hours: ~$5-6

`terraform destroy` is critical after this exercise. The EKS control plane alone costs $2.40
per day even with no workloads running. Leaving it running overnight is an unnecessary expense.

---

## Challenges and Fixes

**Error 1 — Provider version conflict on terraform init:**

```
no available releases match the given constraints >= 4.33.0, >= 5.79.0, >= 5.95.0, ~> 6.0, < 6.0.0
```

The EKS module required `>= 5.95.0` but our `~> 6.0` constraint also implied `< 6.0.0` when
combined with the module's constraints. Fixed by changing to `>= 5.95.0` which satisfies all
constraints and allows 6.x versions.

**Error 2 — Kubernetes version 1.29 not supported in eu-north-1:**

```
InvalidParameterException: Requested AMI for this version 1.29 is not supported
```

AWS had deprecated the 1.29 AMI in eu-north-1. Fixed by upgrading to `cluster_version = "1.32"`.

**Error 3 — Kubernetes deployment Unauthorized:**

```
Error: Failed to create deployment: Unauthorized
```

The IAM user that ran Terraform was not in the EKS cluster's access config. The cluster was
created but the user had no permission to deploy workloads. Fixed by creating an access entry
and associating the AmazonEKSClusterAdminPolicy:

```bash
aws eks create-access-entry \
  --cluster-name sarahcodes-eks \
  --principal-arn arn:aws:iam::629836545449:user/SarahCodes \
  --region eu-north-1

aws eks associate-access-policy \
  --cluster-name sarahcodes-eks \
  --principal-arn arn:aws:iam::629836545449:user/SarahCodes \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster \
  --region eu-north-1
```

**Error 4 — kubectl not installed:**

```
Command 'kubectl' not found
```

Fixed with `sudo snap install kubectl --classic`.

---

## Blog Post

URL: *(paste blog URL here)*

Title: **Deploying Multi-Cloud Infrastructure with Terraform Modules**

---

## Social Media

URL: *(paste post URL here)*

> 🌐 Day 15 of the 30-Day Terraform Challenge — multi-cloud modules, Docker containers, and
> a full EKS cluster all managed by Terraform. Two providers in one configuration, containers
> running on Kubernetes, zero manual console clicks. #30DayTerraformChallenge
> #TerraformChallenge #Terraform #EKS #Kubernetes #Docker #IaC #AWSUserGroupKenya #EveOps
