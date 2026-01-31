variable "project_id" {
  description = "The project ID to deploy to"
  type        = string
}

variable "region" {
  description = "The region to deploy to"
  type        = string
}

variable "cluster_name" {
  description = "The name of the GKE cluster"
  type        = string
}

variable "gke_node_pool_sa_email" {
  description = "Email of the GKE node pool service account"
  type        = string
}

variable "network_name" {
  description = "Name of the VPC network to use. Set to 'default' to use the default VPC."
  type        = string
  default     = "default"
}

variable "subnetwork_name" {
  description = "Name of the subnetwork to use. Set to 'default' to use the default subnetwork."
  type        = string
  default     = "default"
}

variable "ip_range_pods" {
  description = "Secondary IP range for pods. Required if creating a new subnetwork."
  type        = string
  default     = "10.1.0.0/16"
}

variable "ip_range_services" {
  description = "Secondary IP range for services. Required if creating a new subnetwork."
  type        = string
  default     = "10.2.0.0/20"
}

variable "node_machine_type" {
  description = "Machine type for GKE nodes"
  type        = string
  default     = "e2-medium"
}

variable "min_nodes" {
  description = "Minimum number of nodes in the node pool"
  type        = number
  default     = 1
}

variable "max_nodes" {
  description = "Maximum number of nodes in the node pool"
  type        = number
  default     = 1
}

variable "deletion_protection" {
  description = "Protect GKE cluster from deletion"
  type        = bool
  default     = true
}

variable "use_spot_instances" {
  description = "Whether to use spot instances for the node pool"
  type        = bool
  default     = false
}
