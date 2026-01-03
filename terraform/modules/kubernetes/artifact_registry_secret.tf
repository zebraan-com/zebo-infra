resource "kubernetes_secret" "artifact_registry_secret" {
  metadata {
    name      = "artifact-registry-secret"
    namespace = var.namespace
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "${var.artifact_registry_host}" = {
          "auth" = base64encode("_json_key:${var.service_account_key}")
        }
      }
    })
  }

  depends_on = [
    # Add any dependencies here, such as the Kubernetes provider being configured
  ]
}

# Patch the default service account to use the image pull secret
resource "kubernetes_service_account" "default" {
  metadata {
    name      = "default"
    namespace = var.namespace
  }

  image_pull_secret {
    name = kubernetes_secret.artifact_registry_secret.metadata[0].name
  }

  # This prevents Terraform from trying to manage the default service account's secrets
  # which are managed by Kubernetes
  automount_service_account_token = false
}

