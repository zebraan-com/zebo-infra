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
  
  # Load config with a slight delay to ensure the cluster is fully created
  load_config_file = false
  
  # This will prevent the provider from trying to use the config file
  # which might not be available in the CI/CD environment
  config_path = null
}

# Add explicit dependency on the GKE cluster
resource "null_resource" "k8s_provider_dependency" {
  depends_on = [google_container_cluster.primary]
}
