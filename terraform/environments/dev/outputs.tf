# GKE Cluster Outputs
output "cluster_name" {
  description = "The name of the GKE cluster"
  value       = module.gke_cluster.cluster_name
}

output "cluster_endpoint" {
  description = "The endpoint for the GKE cluster"
  value       = module.gke_cluster.cluster_endpoint
}

output "cluster_ca_certificate" {
  description = "The cluster CA certificate"
  value       = module.gke_cluster.cluster_ca_certificate
  sensitive   = true
}

output "project_id" {
  value = var.project_id
}

output "artifact_registry_repo_url" {
  description = "Full repo URL (region-docker.pkg.dev/project/repo)"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${var.registry_id}"
}