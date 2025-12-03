variable "project_id" {}
variable "secrets" {
  type = map(string)
}

# Ensure required API is enabled for this module
resource "google_project_service" "secretmanager" {
  project            = var.project_id
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

# Create secrets from map
resource "google_secret_manager_secret" "secrets" {
  for_each = var.secrets

  secret_id = each.key
  project   = var.project_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "secret_versions" {
  # Create a SecretVersion only for non-empty values
  # This avoids 400 errors (payload is required) when a value is empty
  for_each = { for k, v in var.secrets : k => v if try(length(trimspace(v)) > 0, false) }

  secret      = google_secret_manager_secret.secrets[each.key].id
  secret_data = each.value

  depends_on = [google_project_service.secretmanager]
}

output "created_secrets" {
  value = keys(var.secrets)
}