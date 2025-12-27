# Create a Kubernetes service account in the default namespace
resource "kubernetes_service_account_v1" "default" {
  metadata {
    name      = "default"
    namespace = "default"
    annotations = {
      "iam.gke.io/gcp-service-account" = var.gke_node_pool_sa_email
    }
  }
  
  depends_on = [
    google_container_cluster.primary
  ]
}

# Create a Kubernetes ConfigMap to configure the default service account
resource "kubernetes_config_map_v1" "workload_identity_config" {
  metadata {
    name      = "workload-identity-config"
    namespace = "default"
  }

  data = {
    "cloud" = "gcp"
  }
  
  depends_on = [
    google_container_cluster.primary
  ]
}
