variable "namespace" {
  description = "The Kubernetes namespace to create resources in"
  type        = string
  default     = "default"
}

variable "artifact_registry_host" {
  description = "The hostname of the artifact registry"
  type        = string
}

variable "service_account_key" {
  description = "The content of the service account key JSON file"
  type        = string
  sensitive   = true
}
