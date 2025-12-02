# Service accounts for GKE node pool and workload identity
# project_id variable is defined in api.tf

resource "google_service_account" "gke_node_pool_sa" {
  account_id   = "gke-node-pool-sa"
  display_name = "GKE Node Pool Service Account"
  project      = var.project_id

  depends_on = [
    google_project_service.enabled["iam.googleapis.com"]
  ]
}

resource "google_service_account" "workload_identity_sa" {
  account_id   = "workload-identity-sa"
  display_name = "Workload Identity Service Account for workloads"
  project      = var.project_id

  depends_on = [
    google_project_service.enabled["iam.googleapis.com"]
  ]
}

# Grant clusterAdmin to the node pool SA (adjust later as needed)
resource "google_project_iam_binding" "node_pool_cluster_admin" {
  project = var.project_id
  role    = "roles/container.clusterAdmin"
  members = [
    "serviceAccount:${google_service_account.gke_node_pool_sa.email}"
  ]

  depends_on = [
    google_project_service.enabled["iam.googleapis.com"],
    google_service_account.gke_node_pool_sa
  ]
}

# Allow artifact registry write for node pool/service account
resource "google_project_iam_member" "artifact_registry_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.gke_node_pool_sa.email}"

  depends_on = [
    google_project_service.enabled["iam.googleapis.com"],
    google_service_account.gke_node_pool_sa
  ]
}

output "gke_node_pool_sa_email" {
  value = google_service_account.gke_node_pool_sa.email
}

output "workload_identity_sa_email" {
  value = google_service_account.workload_identity_sa.email
}