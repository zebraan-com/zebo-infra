module "artifact_registry_secret" {
  source = "../../modules/kubernetes"

  artifact_registry_host   = "asia-south1-docker.pkg.dev"
  service_account_key_path = "${path.module}/../../service-account-key.json"
  namespace                = "default"

  # The Kubernetes provider configuration will be handled by the module
  # No need for explicit depends_on as the module will handle its own dependencies
}
