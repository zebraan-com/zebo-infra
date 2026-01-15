variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "zebraan-gcp-zebo-dev"
}


variable "region" {
  description = "GCP Region"
  type        = string
  default     = "asia-south1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "asia-south1-a"
}

variable "registry_id" {
  description = "Artifact Registry repository id"
  type        = string
  default     = "zebo-registry"
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
  default     = "zebo-gke-cluster"
}

variable "gke_node_pool_sa_email" {
  description = "Email of the GKE node pool service account"
  type        = string
  default     = "zebo-gke-nodes@zebraan-gcp-zebo-dev.iam.gserviceaccount.com"
}

variable "network_name" {
  description = "VPC network name (default uses 'default')"
  type        = string
  default     = "default"
}

variable "subnetwork_name" {
  description = "Subnetwork name (default uses 'default')"
  type        = string
  default     = "default"
}

variable "ip_range_pods" {
  description = "Secondary IP range for pods (CIDR)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "ip_range_services" {
  description = "Secondary IP range for services (CIDR)"
  type        = string
  default     = "10.96.0.0/20"
}

variable "node_machine_type" {
  description = "Machine type for GKE nodes"
  type        = string
  default     = "e2-medium"
}

variable "min_nodes" {
  description = "Minimum number of nodes in the node pool"
  type        = number
  default     = 0
}

variable "max_nodes" {
  description = "Maximum number of nodes in the node pool"
  type        = number
  default     = 1
}

variable "gke_deletion_protection" {
  description = "Protect GKE cluster from deletion"
  type        = bool
  default     = true
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "secrets" {
  description = "Map of secrets to create in Secret Manager. Example: {\"zerodha_api\" = \"REPLACE_ME\" }"
  type        = map(string)
  default     = {}
}

variable "terraform_service_account_email" {
  description = "Email of the service account used by Terraform (e.g., from GitHub Actions). If provided, it will be granted permission to impersonate the GKE node service account."
  type        = string
  default     = ""  # Empty by default, will auto-detect if not provided
}