# applied after the EKS cluster and node group are fully ready
resource "kubernetes_deployment" "nginx" {
  metadata {
    name   = "nginx-deployment"
    labels = { app = "nginx" }
  }

  spec {
    replicas = 2

    selector {
      match_labels = { app = "nginx" }
    }

    template {
      metadata {
        labels = { app = "nginx" }
      }

      spec {
        container {
          image = "nginx:latest"
          name  = "nginx"

          port {
            container_port = 80
          }
        }
      }
    }
  }
}
