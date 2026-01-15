# Root Terraform Configuration - Main Orchestrator
# Project: Zebo AI Wealth Manager (zebraan-gcp-zebo-dev)

# Enable required GCP APIs (module is the project folder)
module "project_apis" {
  source     = "../../modules/project"
  project_id = var.project_id
}


# Artifact Registry (Docker repo for GKE workloads)
module "artifact_registry" {
  source      = "../../modules/artifact_registry"
  project_id  = var.project_id
  region      = var.region
  registry_id = var.registry_id
}

# Secret Manager (Stores API keys, DB passwords, etc.)
module "secret_manager" {
  source     = "../../modules/secret_manager"
  project_id = var.project_id
  secrets    = var.secrets
}

# Create a dedicated service account for GKE nodes
resource "google_service_account" "gke_node_sa" {
  account_id   = "gke-node-sa"
  display_name = "GKE Node Service Account"
  project      = var.project_id
}

# Grant necessary roles to the GKE node service account
resource "google_project_iam_member" "gke_node_sa_roles" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
  ])

  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.gke_node_sa.email}"
}

# Validate the Terraform service account email format
locals {
  # Check if we have a valid email format
  has_terraform_sa = var.terraform_service_account_email != "" && can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.terraform_service_account_email))
}

# Grant the Terraform service account permission to impersonate the GKE node SA
# This prevents the "user does not have access to service account" error
resource "google_service_account_iam_member" "terraform_can_use_gke_node_sa" {
  count = local.has_terraform_sa ? 1 : 0

  service_account_id = google_service_account.gke_node_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${var.terraform_service_account_email}"

  depends_on = [google_service_account.gke_node_sa]
}

# GKE Cluster Deployment
module "gke_cluster" {
  source = "../../modules/gke"

  project_id   = var.project_id
  region       = var.region
  cluster_name = "${var.environment}-gke-cluster"

  # Service account for node pool
  gke_node_pool_sa_email = google_service_account.gke_node_sa.email

  # Use custom VPC/subnet so the module can create secondary ranges
  network_name    = "zebo-gke-net"
  subnetwork_name = "zebo-gke-subnet"

  # Secondary IP ranges (required for VPC-native clusters)
  ip_range_pods     = "10.1.0.0/16"
  ip_range_services = "10.2.0.0/20"

  # Node pool configuration
  node_machine_type = var.node_machine_type
  min_nodes         = var.min_nodes
  max_nodes         = var.max_nodes

  # Control deletion protection from env
  deletion_protection = var.gke_deletion_protection
}

# Outputs
output "gke_cluster_name" {
  value = module.gke_cluster.cluster_name
}

output "gcloud_get_credentials" {
  value = "gcloud container clusters get-credentials ${module.gke_cluster.cluster_name} --region ${var.region} --project ${var.project_id}"
}