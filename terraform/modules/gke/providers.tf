# Configure the Kubernetes provider with the GKE cluster
provider "kubernetes" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
}

# Data source to get the current GCP project
data "google_client_config" "default" {}

# Configure the Kubernetes provider for the GKE cluster
provider "kubernetes" {
  alias = "gke"
  
  host                   = "https://${google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
  
  # Explicitly disable the use of kubeconfig file
  # as we're providing all configuration directly
  config_path = ""
}

# Add explicit dependency on the GKE cluster
resource "null_resource" "k8s_provider_dependency" {
  depends_on = [google_container_cluster.primary]
}
