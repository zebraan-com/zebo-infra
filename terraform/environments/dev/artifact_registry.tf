module "artifact_registry_secret" {
  source = "../../modules/kubernetes"

  artifact_registry_host = "asia-south1-docker.pkg.dev"
  service_account_key_path = "${path.module}/../../service-account-key.json"
  namespace              = "default"

  # Ensure the Kubernetes provider is properly configured before creating this resource
  depends_on = [
    # Add any dependencies like your GKE cluster here
    google_container_cluster.primary,
  ]
}
