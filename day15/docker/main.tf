terraform {
  required_version = ">= 1.0.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

# pull the nginx image from Docker Hub
resource "docker_image" "nginx" {
  name         = "nginx:latest"
  keep_locally = false
}

# run nginx container — accessible at http://localhost:8080
resource "docker_container" "nginx" {
  image = docker_image.nginx.image_id
  name  = "terraform-nginx"

  ports {
    internal = 80
    external = 8080
  }
}

output "container_name" {
  value       = docker_container.nginx.name
  description = "Name of the running container"
}

output "container_url" {
  value       = "http://localhost:8080"
  description = "URL to access the nginx container"
}
