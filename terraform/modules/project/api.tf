# Enables GCP services required for this project
resource "google_project_service" "enabled" {
  for_each = toset([
    "compute.googleapis.com",
    "iam.googleapis.com",
    "container.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudbuild.googleapis.com",
    "pubsub.googleapis.com",
    "cloudscheduler.googleapis.com"
  ])

  project = var.project_id
  service = each.key
  # keep service enabled on destroy false to avoid accidental disable
  disable_on_destroy = false
}

# pass through project_id variable for module-like usage
variable "project_id" {
  type = string
}