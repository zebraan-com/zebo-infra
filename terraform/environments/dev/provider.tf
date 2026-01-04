# Provider configuration (separate file so users can extend with credentials/backend)
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Get GKE cluster information
# data "google_container_cluster" "primary" {
#   name     = "gke-cluster" # Using a more generic name that might match your cluster
#   location = var.region
# }

# Configure Kubernetes provider to connect to the GKE cluster
provider "kubernetes" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.provider.access_token
  cluster_ca_certificate = base64decode(
    google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  )
}

data "google_client_config" "default" {}

# Uncomment and configure a remote backend if you want remote state Update the bucket name as ${PROJECT_ID}-terraform-state 
terraform {
  backend "gcs" {
    bucket = "zebo-dev-terraform-state"
    prefix = "terraform/state/zebraan-gcp-zebo-dev"
  }

  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}