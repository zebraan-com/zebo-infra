# # Configure Kubernetes service account to use Workload Identity
# resource "kubernetes_service_account_v1" "default" {
#   metadata {
#     name      = "default"
#     namespace = "default"
#     annotations = {
#       "iam.gke.io/gcp-service-account" = var.gke_node_pool_sa_email
#     }
#   }
# }
