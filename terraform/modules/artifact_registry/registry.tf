variable "project_id" {}
variable "region" {}
variable "registry_id" {}

# Ensure required API is enabled for this module
resource "google_project_service" "artifactregistry" {
  project             = var.project_id
  service             = "artifactregistry.googleapis.com"
  disable_on_destroy  = false
}

resource "google_artifact_registry_repository" "docker_repo" {
  provider = google
  project  = var.project_id
  location = var.region
  repository_id = var.registry_id
  description   = "Docker repository for Zebo workloads"
  format        = "DOCKER"

  depends_on = [google_project_service.artifactregistry]
}

output "repo_url" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/${var.registry_id}"
}