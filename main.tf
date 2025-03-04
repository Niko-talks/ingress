# main.tf
terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "~> 6.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
    
      source = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

provider "google" {
  project = "affable-curve-449914-q4"
  region  = "us-central1"
}

data "google_container_cluster" "stage1" {
  name     = "stage1"
  location = "us-central1"
}

provider "kubernetes" {
  host                   = "https://${data.google_container_cluster.stage1.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.stage1.master_auth[0].cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = "https://${data.google_container_cluster.stage1.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(data.google_container_cluster.stage1.master_auth[0].cluster_ca_certificate)
  }
}

data "google_client_config" "default" {}

data "google_compute_network" "vlan50" {
  name = "vlan50"
}

data "google_compute_subnetwork" "vlan50_subnet" {
  name   = "vlan50"
  region = "us-central1"
}

# Установка NGINX Ingress Controller с HTTP/3
resource "helm_release" "custom_nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.12.0"
  namespace  = "ingress-nginx"
  create_namespace = true
  force_update = true

  values = [templatefile("${path.module}/nginx-values.yaml", {
    network_name = data.google_compute_network.vlan50.name
  })]

  set {
    name  = "controller.service.annotations.cloud\\.google\\.com/network"
    value = data.google_compute_network.vlan50.name
  }

  set {
    name  = "controller.service.annotations.cloud\\.google\\.com/subnet"
    value = data.google_compute_subnetwork.vlan50_subnet.name
  }
  set {
    name  = "controller.image.tag"
    value = "v1.8.1" # Версия с поддержкой HTTP/3
  }
  set {
    name  = "controller.ingressClassResource.name"
    value = "nginx-new"  # Измените имя IngressClass
  }
}

# Создание TLS Secret
resource "kubernetes_secret" "tls_secret" {
  metadata {
    name = "tls-secret"
  }

  data = {
    "tls.crt" = filebase64("tls.crt")
    "tls.key" = filebase64("tls.key")
  }

  type = "kubernetes.io/tls"
}

# Развертывание тестового приложения
resource "kubernetes_deployment" "webapp" {
  metadata {
    name = "webapp"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "webapp"
      }
    }

    template {
      metadata {
        labels = {
          app = "webapp"
        }
      }

      spec {
        container {
          name  = "nginx"
          image = "nginx:latest"
          port {
            container_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "webapp" {
  metadata {
    name = "webapp-service"
  }

  spec {
    selector = {
      app = "webapp"
    }

    port {
      port        = 80
      target_port = 80
    }
  }
}

# Создание Ingress
resource "kubernetes_ingress_v1" "webapp" {
  metadata {
    name = "webapp-ingress"
    annotations = {
      "kubernetes.io/ingress.class"           = "nginx"
      "nginx.ingress.kubernetes.io/http3"     = "true"
      "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
    }
  }

  spec {
    tls {
      hosts       = ["example.com"]
      secret_name = kubernetes_secret.tls_secret.metadata[0].name
    }

    rule {
      host = "example.com"
      http {
        path {
          path = "/"
          backend {
            service {
              name = kubernetes_service.webapp.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}
