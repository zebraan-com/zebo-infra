variable "project_id" {}
variable "region" {}
variable "cluster_name" {}
variable "network_name" {
  description = "Name of the VPC network to use. Set to 'default' to use the default VPC."
  type        = string
  default     = "default"
}
variable "subnetwork_name" {
  description = "Name of the subnetwork to use. Set to 'default' to use the default subnetwork."
  type        = string
  default     = "default"
}
variable "ip_range_pods" {
  description = "Secondary IP range for pods. Required if creating a new subnetwork."
  type        = string
  default     = "10.1.0.0/16"
}
variable "ip_range_services" {
  description = "Secondary IP range for services. Required if creating a new subnetwork."
  type        = string
  default     = "10.2.0.0/20"
}
variable "node_machine_type" {
  description = "Machine type for GKE nodes"
  type        = string
  default     = "e2-small"
}
variable "min_nodes" {
  description = "Minimum number of nodes in the node pool"
  type        = number
  default     = 1
}
variable "max_nodes" {
  description = "Maximum number of nodes in the node pool"
  type        = number
  default     = 1
}

variable "deletion_protection" {
  description = "Protect GKE cluster from deletion"
  type        = bool
  default     = true
}

# Ensure required API is enabled for this module
resource "google_project_service" "container" {
  project            = var.project_id
  service            = "container.googleapis.com"
  disable_on_destroy = false
}

# Only create network resources if not using default
resource "google_compute_network" "gke_network" {
  count = var.network_name == "default" ? 0 : 1
  
  name                    = var.network_name
  project                 = var.project_id
  auto_create_subnetworks = false
}

# Only create subnetwork if not using default
resource "google_compute_subnetwork" "gke_subnet" {
  count = var.subnetwork_name == "default" ? 0 : 1
  
  name          = var.subnetwork_name
  ip_cidr_range = cidrsubnet("10.0.0.0/8", 8, 0)  # Creates a /24 subnet
  region        = var.region
  project       = var.project_id
  network       = var.network_name == "default" ? "default" : google_compute_network.gke_network[0].id
  
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.ip_range_pods
  }
  
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.ip_range_services
  }
}

# GKE Cluster
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region
  project  = var.project_id

  deletion_protection = var.deletion_protection

  remove_default_node_pool = true
  initial_node_count       = 1

  network    = var.network_name
  subnetwork = var.subnetwork_name

  # Enable VPC-native (alias IP)
  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    network_policy_config {
      disabled = false
    }
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Enable network policy for Calico
  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  # Recommended settings for production
  release_channel {
    channel = "REGULAR"
  }

  # Enable private nodes (optional)
  private_cluster_config {
    enable_private_nodes    = false
    enable_private_endpoint = false
  }

  depends_on = [
    google_project_service.container,
    google_compute_network.gke_network,
    google_compute_subnetwork.gke_subnet
  ]
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "primary-pool"
  project    = var.project_id
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = var.min_nodes

  autoscaling {
    min_node_count = var.min_nodes
    max_node_count = var.max_nodes
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type = var.node_machine_type
    disk_size_gb = 100
    disk_type    = "pd-standard"
    
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Enable workload identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = {
      environment = var.cluster_name
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}

output "cluster_name" {
  value = google_container_cluster.primary.name
}

output "cluster_endpoint" {
  value = google_container_cluster.primary.endpoint
}

output "cluster_ca_certificate" {
  value     = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  sensitive = true
}