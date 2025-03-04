# variables.tf
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "cluster_name" {
  description = "GKE Cluster Name"
  type        = string
  default     = "http3-cluster"
}

variable "domain" {
  description = "Domain name for ingress"
  type        = string
  default     = "example.com"
}

variable "tls_crt_path" {
  description = "Path to TLS certificate"
  type        = string
}

variable "tls_key_path" {
  description = "Path to TLS private key"
  type        = string
}

variable "load_balancer_ip" {
  description = "Static IP for Load Balancer"
  type        = string
  default     = null
}
