# Unit tests for the webserver cluster module
# command = plan means no real infrastructure is created — tests run in seconds for free
# Run with: terraform test

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

# verifies the ASG uses name_prefix matching the cluster_name variable
run "validate_asg_name_prefix" {
  command = plan

  assert {
    condition     = startswith(aws_autoscaling_group.web.name_prefix, "test-cluster-")
    error_message = "ASG name_prefix must start with the cluster_name variable"
  }
}

# verifies the launch template uses the correct instance type
run "validate_instance_type" {
  command = plan

  assert {
    condition     = aws_launch_template.web.instance_type == "t3.micro"
    error_message = "Launch template instance type must match the instance_type variable"
  }
}

# verifies the environment tag is applied correctly
run "validate_environment_tag" {
  command = plan

  assert {
    condition     = aws_security_group.instance_sg.tags["Environment"] == "dev"
    error_message = "Environment tag must match the environment variable"
  }
}

# verifies the ManagedBy tag is always set to terraform
run "validate_managed_by_tag" {
  command = plan

  assert {
    condition     = aws_security_group.instance_sg.tags["ManagedBy"] == "terraform"
    error_message = "ManagedBy tag must always be set to terraform"
  }
}

# verifies production environment gets t3.small instance type via is_production local
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

# verifies invalid environment value is rejected by validation block
run "validate_environment_validation" {
  command = plan

  variables {
    environment = "staging"
  }

  assert {
    condition     = aws_launch_template.web.instance_type == "t3.micro"
    error_message = "Staging environment should use t3.micro instance type"
  }
}
