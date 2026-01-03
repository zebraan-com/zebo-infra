# IAM binding for GKE node pool service account to access Artifact Registry
resource "google_project_iam_member" "gke_artifact_registry_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${var.gke_node_pool_sa_email}"

  depends_on = [
    google_container_cluster.primary
  ]
}

# IAM binding for Workload Identity
resource "google_service_account_iam_member" "workload_identity_user" {
  service_account_id = "projects/${var.project_id}/serviceAccounts/${var.gke_node_pool_sa_email}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[default/default]"

  depends_on = [
    google_container_cluster.primary
  ]
}
