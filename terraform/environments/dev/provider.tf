# Provider configuration (separate file so users can extend with credentials/backend)
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

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